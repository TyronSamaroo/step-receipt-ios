#!/usr/bin/env ruby
# frozen_string_literal: true

require "csv"
require "json"
require "net/http"
require "set"
require "uri"

ROOT = File.expand_path("..", __dir__)
LINEAR_DIR = File.join(ROOT, "Docs", "Linear", "StrideSlip")
REGISTRY_CSV = File.join(LINEAR_DIR, "StrideSlipFeatureRegistry.linear.csv")
VALIDATION_CSV = File.join(LINEAR_DIR, "StrideSlipValidationBacklog.linear.csv")

TEAM_KEY = ENV.fetch("LINEAR_TEAM_KEY", "TYR")
PROJECT_NAME = ENV.fetch("LINEAR_PROJECT_NAME", "StrideSlip iOS")
API_URL = URI("https://api.linear.app/graphql")

apply = ARGV.include?("--apply")
registry_only = ARGV.include?("--registry-only")
validation_only = ARGV.include?("--validation-only")

if registry_only && validation_only
  abort "[FAIL] Use only one of --registry-only or --validation-only."
end

files = if registry_only
  [REGISTRY_CSV]
elsif validation_only
  [VALIDATION_CSV]
else
  [REGISTRY_CSV, VALIDATION_CSV]
end

rows = files.flat_map do |file|
  unless File.file?(file)
    abort "[FAIL] Missing import file: #{file}"
  end

  CSV.read(file, headers: true).map { |row| row.to_h.merge("_source_file" => file) }
end

puts "StrideSlip Linear import"
puts "  Team:     #{TEAM_KEY}"
puts "  Project:  #{PROJECT_NAME}"
puts "  Apply:    #{apply ? "yes" : "no, dry-run"}"
puts "  Rows:     #{rows.length}"
puts

required_columns = %w[Title Description Status Labels Project Team]
missing_columns = required_columns - rows.first.keys
abort "[FAIL] Missing columns: #{missing_columns.join(", ")}" unless missing_columns.empty?

bad_project_rows = rows.reject do |row|
  row["Project"] == PROJECT_NAME &&
    row["Team"] == TEAM_KEY &&
    row["Labels"].to_s.split(",").map(&:strip).include?("project-strideslip-ios")
end
abort "[FAIL] #{bad_project_rows.length} rows are not scoped to #{PROJECT_NAME}/#{TEAM_KEY}." unless bad_project_rows.empty?

status_counts = rows.each_with_object(Hash.new(0)) { |row, counts| counts[row["Status"]] += 1 }
puts "Status counts: #{status_counts.sort.map { |status, count| "#{status}=#{count}" }.join(", ")}"

unless apply
  puts
  puts "[DRY RUN] No Linear changes made."
  puts "Run with LINEAR_API_KEY set and --apply to create/update the Linear project issues."
  exit 0
end

api_key = ENV["LINEAR_API_KEY"].to_s.strip
abort "[FAIL] Set LINEAR_API_KEY before using --apply." if api_key.empty?

def graphql(api_key, query, variables = {})
  request = Net::HTTP::Post.new(API_URL)
  request["Content-Type"] = "application/json"
  request["Authorization"] = api_key
  request.body = JSON.generate(query: query, variables: variables)

  response = Net::HTTP.start(API_URL.hostname, API_URL.port, use_ssl: true) do |http|
    http.request(request)
  end

  unless response.is_a?(Net::HTTPSuccess)
    abort "[FAIL] Linear HTTP #{response.code}: #{response.body}"
  end

  payload = JSON.parse(response.body)
  if payload["errors"]&.any?
    abort "[FAIL] Linear GraphQL error: #{JSON.pretty_generate(payload["errors"])}"
  end

  payload.fetch("data")
end

bootstrap_query = <<~GRAPHQL
  query Bootstrap {
    teams(first: 100) {
      nodes { id key name }
    }
    workflowStates(first: 250) {
      nodes { id name type team { id } }
    }
    issueLabels(first: 250) {
      nodes { id name team { id } }
    }
    projects(first: 250) {
      nodes { id name teams { nodes { id } } }
    }
    issues(first: 250) {
      nodes { id title team { id } project { id name } }
    }
  }
GRAPHQL

data = graphql(api_key, bootstrap_query)
team = data.dig("teams", "nodes").find { |node| node["key"] == TEAM_KEY }
abort "[FAIL] Linear team #{TEAM_KEY.inspect} not found." unless team

team_id = team.fetch("id")
states = data.dig("workflowStates", "nodes").select { |state| state.dig("team", "id") == team_id }
todo_state = states.find { |state| state["name"].casecmp("Todo").zero? } ||
  states.find { |state| state["type"] == "unstarted" }
done_state = states.find { |state| state["name"].casecmp("Done").zero? } ||
  states.find { |state| state["type"] == "completed" }
abort "[FAIL] Could not find Todo and Done workflow states for #{TEAM_KEY}." unless todo_state && done_state

projects = data.dig("projects", "nodes").select do |project|
  project.dig("teams", "nodes").any? { |node| node["id"] == team_id }
end
project = projects.find { |candidate| candidate["name"].casecmp(PROJECT_NAME).zero? }

unless project
  create_project_mutation = <<~GRAPHQL
    mutation CreateProject($input: ProjectCreateInput!) {
      projectCreate(input: $input) {
        success
        project { id name url }
      }
    }
  GRAPHQL
  result = graphql(api_key, create_project_mutation, {
    "input" => {
      "name" => PROJECT_NAME,
      "teamIds" => [team_id]
    }
  })
  project = result.dig("projectCreate", "project")
  puts "[CREATE] Project #{project["name"]}: #{project["url"]}"
end

project_id = project.fetch("id")

labels_by_name = data.dig("issueLabels", "nodes")
  .select { |label| label.dig("team", "id") == team_id || label["team"].nil? }
  .each_with_object({}) { |label, labels| labels[label["name"]] = label["id"] }

needed_labels = rows.flat_map { |row| row["Labels"].to_s.split(",").map(&:strip) }.reject(&:empty?).uniq
create_label_mutation = <<~GRAPHQL
  mutation CreateIssueLabel($input: IssueLabelCreateInput!) {
    issueLabelCreate(input: $input) {
      success
      issueLabel { id name }
    }
  }
GRAPHQL

needed_labels.each do |label_name|
  next if labels_by_name.key?(label_name)

  result = graphql(api_key, create_label_mutation, {
    "input" => {
      "name" => label_name,
      "teamId" => team_id
    }
  })
  label = result.dig("issueLabelCreate", "issueLabel")
  labels_by_name[label.fetch("name")] = label.fetch("id")
  puts "[CREATE] Label #{label["name"]}"
end

existing_titles = data.dig("issues", "nodes")
  .select { |issue| issue.dig("team", "id") == team_id && issue.dig("project", "id") == project_id }
  .map { |issue| issue["title"] }
  .to_set

create_issue_mutation = <<~GRAPHQL
  mutation CreateIssue($input: IssueCreateInput!) {
    issueCreate(input: $input) {
      success
      issue { id identifier title url }
    }
  }
GRAPHQL

created = 0
skipped = 0

rows.each do |row|
  title = row.fetch("Title")
  if existing_titles.include?(title)
    skipped += 1
    puts "[SKIP] #{title}"
    next
  end

  state_id = row["Status"] == "Done" ? done_state.fetch("id") : todo_state.fetch("id")
  label_ids = row["Labels"].to_s.split(",").map(&:strip).reject(&:empty?).map { |label| labels_by_name[label] }.compact
  input = {
    "teamId" => team_id,
    "projectId" => project_id,
    "stateId" => state_id,
    "title" => title,
    "description" => row.fetch("Description"),
    "labelIds" => label_ids
  }

  priority = row["Priority"].to_s.strip.downcase
  input["priority"] = case priority
  when "urgent" then 1
  when "high" then 2
  when "medium", "normal" then 3
  when "low" then 4
  else 0
  end

  result = graphql(api_key, create_issue_mutation, { "input" => input })
  issue = result.dig("issueCreate", "issue")
  created += 1
  existing_titles.add(title)
  puts "[CREATE] #{issue["identifier"]} #{issue["title"]} #{issue["url"]}"

  sleep 0.1
end

puts
puts "[PASS] Linear import complete. Created #{created}; skipped #{skipped} existing issues."
