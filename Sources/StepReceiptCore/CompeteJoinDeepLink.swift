import Foundation

public enum CompeteJoinDeepLink {
    public static let scheme = "stepreceipt"

    /// Parses `stepreceipt://compete/join?code=SR...` and path variants.
    public static func inviteCode(from url: URL) -> String? {
        guard url.scheme?.caseInsensitiveCompare(scheme) == .orderedSame else { return nil }
        guard url.host?.caseInsensitiveCompare("compete") == .orderedSame else { return nil }

        let pathComponent = url.path
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            .lowercased()
        guard pathComponent.isEmpty || pathComponent == "join" else { return nil }

        guard
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
            let rawCode = components.queryItems?
                .first(where: { $0.name.caseInsensitiveCompare("code") == .orderedSame })?
                .value
        else {
            return nil
        }

        let normalized = SharedCompetitionSettings.normalizedInviteCode(rawCode)
        return normalized.isEmpty ? nil : normalized
    }

    public static func joinURL(for inviteCode: String) -> URL? {
        let normalized = SharedCompetitionSettings.normalizedInviteCode(inviteCode)
        guard !normalized.isEmpty else { return nil }

        var components = URLComponents()
        components.scheme = scheme
        components.host = "compete"
        components.path = "/join"
        components.queryItems = [URLQueryItem(name: "code", value: normalized)]
        return components.url
    }
}

public struct CompeteJoinRequest: Equatable, Identifiable, Sendable {
    public enum Source: String, Equatable, Sendable {
        case deepLink
        case cloudKitShare
    }

    public let id: UUID
    public let inviteCode: String
    public let source: Source
    public let ownerDisplayName: String?

    public init(
        id: UUID = UUID(),
        inviteCode: String,
        source: Source,
        ownerDisplayName: String? = nil
    ) {
        self.id = id
        self.inviteCode = SharedCompetitionSettings.normalizedInviteCode(inviteCode)
        self.source = source
        self.ownerDisplayName = ownerDisplayName
    }

    public var codeHint: String {
        String(inviteCode.suffix(4))
    }

    public func requiresReplaceConfirmation(currentInviteCode: String, boardEnabled: Bool) -> Bool {
        guard boardEnabled else { return false }
        let current = SharedCompetitionSettings.normalizedInviteCode(currentInviteCode)
        return !current.isEmpty && current != inviteCode
    }
}
