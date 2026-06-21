import Charts
import SwiftUI

struct WeatherDetailSheet: View {
    @EnvironmentObject private var repository: ActivityRepository
    @Environment(\.dismiss) private var dismiss

    let date: Date

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if repository.isLoadingWeatherDetail {
                        ProgressView("Loading forecast…")
                            .frame(maxWidth: .infinity, minHeight: 220)
                    } else if let detail = repository.dayWeatherDetail {
                        weatherSummarySection(detail.snapshot)
                        if let highLow = detail.snapshot.formattedHighLowFahrenheit {
                            highLowSection(highLow)
                        }
                        statsGrid(detail.snapshot)
                        if !detail.hourly.isEmpty {
                            hourlySection(detail.hourly)
                        }
                        if detail.snapshot.source == .weatherKit {
                            WeatherAttributionView()
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.top, 8)
                        }
                    } else if let snapshot = repository.dayWeather {
                        weatherSummarySection(snapshot)
                        statsGrid(snapshot)
                        limitedDetailNotice(for: snapshot)
                        if snapshot.source == .weatherKit {
                            WeatherAttributionView()
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.top, 8)
                        }
                    } else {
                        ContentUnavailableView(
                            "Weather Unavailable",
                            systemImage: "cloud.slash",
                            description: Text("No weather data for this day.")
                        )
                        .frame(maxWidth: .infinity, minHeight: 220)
                    }
                }
                .padding(16)
            }
            .background(Color.stepBackground)
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                await repository.loadWeatherDetail(for: date)
            }
            .accessibilityIdentifier("today-weather-detail")
        }
    }

    private var navigationTitle: String {
        Calendar.current.isDateInToday(date) ? "Weather Today" : "Weather"
    }

    private func weatherSummarySection(_ weather: DayWeatherSnapshot) -> some View {
        HStack(alignment: .center, spacing: 16) {
            Image(systemName: weather.displayConditionSymbolName)
                .font(.system(size: 52))
                .symbolRenderingMode(.multicolor)
                .frame(width: 58, height: 58)

            VStack(alignment: .leading, spacing: 4) {
                Text(weather.formattedTemperatureFahrenheit)
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.stepInk)
                    .monospacedDigit()

                Text(weather.displayConditionDescription)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(Color.stepMuted)

                if weather.formattedApparentTemperatureFahrenheit != nil {
                    Text("Feels like \(weather.displayApparentTemperatureFahrenheit)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.stepMuted)
                }

                if let highLow = weather.formattedHighLowFahrenheit {
                    Text(highLow)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.stepDistance)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: WeatherCardStyle.gradientColors(for: weather),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.stepDistance.opacity(0.16), lineWidth: 1)
        )
    }

    private func highLowSection(_ highLow: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "thermometer.medium")
                .foregroundStyle(Color.stepEnergy)
            Text(highLow)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Color.stepInk)
        }
        .metricCard()
    }

    private func statsGrid(_ weather: DayWeatherSnapshot) -> some View {
        let stats = detailStats(for: weather)
        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            ForEach(stats, id: \.title) { stat in
                detailStat(stat.title, stat.value, stat.icon, stat.color)
            }
        }
    }

    private func detailStats(for weather: DayWeatherSnapshot) -> [(title: String, value: String, icon: String, color: Color)] {
        var stats: [(title: String, value: String, icon: String, color: Color)] = [
            ("Feels like", weather.displayApparentTemperatureFahrenheit, "thermometer.medium", Color.stepEnergy),
            ("Humidity", weather.formattedHumidity, "humidity", Color.stepDistance),
            ("Wind", weather.displayWind, "wind", Color.stepAccent),
            ("UV Index", weather.displayUVIndex, "sun.max", Color.stepWarning)
        ]

        if let dew = weather.formattedDewPointFahrenheit {
            stats.append(("Dew point", dew, "drop", Color.stepDistance))
        }
        if let visibility = weather.formattedVisibilityMiles {
            stats.append(("Visibility", visibility, "eye", Color.stepMuted))
        }
        if let precip = weather.formattedPrecipitationChance {
            stats.append(("Precip.", precip, "cloud.rain", Color.stepDistance))
        }
        if let cloudCover = weather.cloudCoverPercent {
            stats.append(("Cloud cover", "\(Int(cloudCover.rounded()))%", "cloud", Color.stepMuted))
        }

        return stats
    }

    private func detailStat(_ title: String, _ value: String, _ icon: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.caption.weight(.bold))
                .foregroundStyle(color)
                .frame(width: 28, height: 28)
                .background(color.opacity(0.14))
                .clipShape(Circle())

            Text(value)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Color.stepInk)
                .lineLimit(2)
                .minimumScaleFactor(0.75)
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Color.stepMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.stepSurface)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func hourlySection(_ hourly: [HourWeatherSnapshot]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Hourly Forecast", systemImage: "clock")
                .font(.headline)
                .foregroundStyle(Color.stepInk)

            Chart(hourly) { hour in
                LineMark(
                    x: .value("Hour", hour.date, unit: .hour),
                    y: .value("Temp", DayWeatherSnapshot.celsiusToFahrenheit(hour.temperatureCelsius))
                )
                .foregroundStyle(Color.stepDistance.gradient)
                .interpolationMethod(.catmullRom)

                PointMark(
                    x: .value("Hour", hour.date, unit: .hour),
                    y: .value("Temp", DayWeatherSnapshot.celsiusToFahrenheit(hour.temperatureCelsius))
                )
                .foregroundStyle(Color.stepDistance)
                .symbolSize(24)
            }
            .chartYAxis {
                AxisMarks(position: .leading) { value in
                    AxisGridLine()
                        .foregroundStyle(Color.stepAxisGrid)
                    AxisValueLabel {
                        if let temp = value.as(Double.self) {
                            Text("\(Int(temp.rounded()))°")
                                .font(.caption2)
                                .foregroundStyle(Color.stepAxis)
                        }
                    }
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .hour, count: 3)) { value in
                    AxisGridLine()
                        .foregroundStyle(Color.stepAxisGrid)
                    AxisValueLabel(format: .dateTime.hour())
                        .font(.caption2)
                        .foregroundStyle(Color.stepAxis)
                }
            }
            .frame(height: 160)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(hourly) { hour in
                        VStack(spacing: 6) {
                            Text(hour.date, format: .dateTime.hour())
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(Color.stepMuted)
                            if let symbol = hour.conditionSymbolName {
                                Image(systemName: symbol)
                                    .font(.title3)
                                    .symbolRenderingMode(.multicolor)
                            }
                            Text(hour.formattedTemperatureFahrenheit)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(Color.stepInk)
                                .monospacedDigit()
                            if let precip = hour.formattedPrecipitationChance {
                                Text(precip)
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(Color.stepDistance)
                            }
                        }
                        .frame(width: 56)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 6)
                        .background(Color.stepSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                }
            }
        }
        .metricCard()
    }

    @ViewBuilder
    private func limitedDetailNotice(for snapshot: DayWeatherSnapshot) -> some View {
        if snapshot.source == .healthKitWorkout {
            Text("Limited weather from workout metadata. Connect WeatherKit for full forecast.")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.stepMuted)
                .metricCard()
        }
    }
}
