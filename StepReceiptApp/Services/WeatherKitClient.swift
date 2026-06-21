import CoreLocation
import Foundation
import WeatherKit

protocol WeatherKitProviding: Sendable {
    func fetchDayWeather(for date: Date, at location: CLLocation, calendar: Calendar) async throws -> DayWeatherSnapshot
    func fetchWeatherDetail(for date: Date, at location: CLLocation, calendar: Calendar) async throws -> DayWeatherDetail
    func fetchWorkoutWeather(at location: CLLocation, around startDate: Date) async throws -> DayWeatherSnapshot
}

enum WeatherKitClientError: LocalizedError, Sendable {
    case unavailable
    case noHourlyData

    var errorDescription: String? {
        switch self {
        case .unavailable:
            "WeatherKit is unavailable."
        case .noHourlyData:
            "No hourly weather data for this time."
        }
    }
}

actor LiveWeatherKitClient: WeatherKitProviding {
    private let service: WeatherService
    private var cache: [String: CachedWeather] = [:]

    init(service: WeatherService = .shared) {
        self.service = service
    }

    func fetchDayWeather(for date: Date, at location: CLLocation, calendar: Calendar) async throws -> DayWeatherSnapshot {
        let detail = try await fetchWeatherDetail(for: date, at: location, calendar: calendar)
        return detail.snapshot
    }

    func fetchWeatherDetail(for date: Date, at location: CLLocation, calendar: Calendar) async throws -> DayWeatherDetail {
        let dayStart = calendar.startOfDay(for: date)
        let isToday = calendar.isDateInToday(date)
        let cacheKey = DayWeatherSnapshot.cacheKey(
            for: dayStart,
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            calendar: calendar
        )

        if let cached = cachedDetail(for: cacheKey, isToday: isToday) {
            return cached
        }

        let detail: DayWeatherDetail
        if isToday {
            detail = try await fetchTodayDetail(at: location, calendar: calendar)
        } else {
            detail = try await fetchHistoricalDetail(for: dayStart, at: location, calendar: calendar)
        }

        let ttl: TimeInterval = isToday ? 30 * 60 : 24 * 60 * 60
        cache[cacheKey] = CachedWeather(detail: detail, fetchedAt: Date(), ttl: ttl)
        return detail
    }

    func fetchWorkoutWeather(at location: CLLocation, around startDate: Date) async throws -> DayWeatherSnapshot {
        let windowStart = startDate.addingTimeInterval(-30 * 60)
        let windowEnd = startDate.addingTimeInterval(30 * 60)
        let cacheKey = "workout-\(Int(startDate.timeIntervalSince1970))-\(DayWeatherSnapshot.cacheKey(for: startDate, latitude: location.coordinate.latitude, longitude: location.coordinate.longitude))"

        if let cached = cache[cacheKey], Date().timeIntervalSince(cached.fetchedAt) < 24 * 60 * 60 {
            return cached.detail.snapshot
        }

        let forecast: Forecast<HourWeather> = try await service.weather(
            for: location,
            including: .hourly(startDate: windowStart, endDate: windowEnd)
        )
        let hours = Array(forecast)
        guard let hour = closestHour(to: startDate, in: hours) else {
            throw WeatherKitClientError.noHourlyData
        }

        let snapshot = snapshot(from: hour, daily: nil)
        let detail = DayWeatherDetail(
            date: Calendar.current.startOfDay(for: startDate),
            snapshot: snapshot,
            hourly: [hourSnapshot(from: hour)]
        )
        cache[cacheKey] = CachedWeather(detail: detail, fetchedAt: Date(), ttl: 24 * 60 * 60)
        return snapshot
    }

    private func fetchTodayDetail(at location: CLLocation, calendar: Calendar) async throws -> DayWeatherDetail {
        let now = Date()
        let dayStart = calendar.startOfDay(for: now)
        let hourlyEnd = calendar.date(byAdding: .hour, value: 24, to: now) ?? now.addingTimeInterval(86_400)

        let (current, daily, hourly) = try await service.weather(
            for: location,
            including: .current,
            .daily,
            .hourly(startDate: now, endDate: hourlyEnd)
        )

        let todayDaily = dailyForecast(for: dayStart, in: Array(daily), calendar: calendar)
        let snapshot = snapshot(from: current, daily: todayDaily)
        let hourlySnapshots = Array(hourly).map { hourSnapshot(from: $0) }

        return DayWeatherDetail(date: dayStart, snapshot: snapshot, hourly: hourlySnapshots)
    }

    private func fetchHistoricalDetail(for dayStart: Date, at location: CLLocation, calendar: Calendar) async throws -> DayWeatherDetail {
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart.addingTimeInterval(86_400)

        let (daily, hourly) = try await service.weather(
            for: location,
            including: .daily,
            .hourly(startDate: dayStart, endDate: dayEnd)
        )

        let hours = Array(hourly)
        guard !hours.isEmpty else {
            throw WeatherKitClientError.noHourlyData
        }

        let noon = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: dayStart) ?? dayStart.addingTimeInterval(43_200)
        guard let representativeHour = closestHour(to: noon, in: hours) else {
            throw WeatherKitClientError.noHourlyData
        }

        let dayDaily = dailyForecast(for: dayStart, in: Array(daily), calendar: calendar)
        let highLow = highLow(from: hours, daily: dayDaily)
        let snapshot = snapshot(from: representativeHour, daily: dayDaily, highLow: highLow)
        let hourlySnapshots = hours.map { hourSnapshot(from: $0) }

        return DayWeatherDetail(date: dayStart, snapshot: snapshot, hourly: hourlySnapshots)
    }

    private func dailyForecast(for dayStart: Date, in days: [DayWeather], calendar: Calendar) -> DayWeather? {
        days.first { calendar.isDate($0.date, inSameDayAs: dayStart) }
    }

    private struct HighLow {
        let highCelsius: Double
        let lowCelsius: Double
    }

    private func highLow(from hours: [HourWeather], daily: DayWeather?) -> HighLow? {
        if let daily {
            return HighLow(
                highCelsius: celsiusValue(from: daily.highTemperature),
                lowCelsius: celsiusValue(from: daily.lowTemperature)
            )
        }

        let temps = hours.map { celsiusValue(from: $0.temperature) }
        guard let high = temps.max(), let low = temps.min() else { return nil }
        return HighLow(highCelsius: high, lowCelsius: low)
    }

    private func snapshot(from current: CurrentWeather, daily: DayWeather?) -> DayWeatherSnapshot {
        DayWeatherSnapshot(
            temperatureCelsius: celsiusValue(from: current.temperature),
            humidityPercent: current.humidity * 100,
            apparentTemperatureCelsius: celsiusValue(from: current.apparentTemperature),
            conditionSymbolName: current.symbolName,
            conditionDescription: current.condition.description,
            windSpeedMetersPerSecond: current.wind.speed.converted(to: .metersPerSecond).value,
            windDirectionDegrees: current.wind.direction.converted(to: .degrees).value,
            uvIndex: Double(current.uvIndex.value),
            dewPointCelsius: celsiusValue(from: current.dewPoint),
            visibilityMeters: current.visibility.converted(to: .meters).value,
            precipitationChancePercent: nil,
            highTemperatureCelsius: daily.map { celsiusValue(from: $0.highTemperature) },
            lowTemperatureCelsius: daily.map { celsiusValue(from: $0.lowTemperature) },
            cloudCoverPercent: current.cloudCover * 100,
            isDaylight: current.isDaylight,
            source: .weatherKit
        )
    }

    private func snapshot(from hour: HourWeather, daily: DayWeather?, highLow: HighLow? = nil) -> DayWeatherSnapshot {
        let resolvedHighLow = highLow ?? daily.map {
            HighLow(
                highCelsius: celsiusValue(from: $0.highTemperature),
                lowCelsius: celsiusValue(from: $0.lowTemperature)
            )
        }

        return DayWeatherSnapshot(
            temperatureCelsius: celsiusValue(from: hour.temperature),
            humidityPercent: hour.humidity * 100,
            apparentTemperatureCelsius: celsiusValue(from: hour.apparentTemperature),
            conditionSymbolName: hour.symbolName,
            conditionDescription: hour.condition.description,
            windSpeedMetersPerSecond: hour.wind.speed.converted(to: .metersPerSecond).value,
            windDirectionDegrees: hour.wind.direction.converted(to: .degrees).value,
            uvIndex: daily.map { Double($0.uvIndex.value) },
            dewPointCelsius: celsiusValue(from: hour.dewPoint),
            visibilityMeters: hour.visibility.converted(to: .meters).value,
            precipitationChancePercent: hour.precipitationChance * 100,
            highTemperatureCelsius: resolvedHighLow?.highCelsius,
            lowTemperatureCelsius: resolvedHighLow?.lowCelsius,
            cloudCoverPercent: hour.cloudCover * 100,
            isDaylight: hour.isDaylight,
            source: .weatherKit
        )
    }

    private func hourSnapshot(from hour: HourWeather) -> HourWeatherSnapshot {
        HourWeatherSnapshot(
            date: hour.date,
            temperatureCelsius: celsiusValue(from: hour.temperature),
            conditionSymbolName: hour.symbolName,
            conditionDescription: hour.condition.description,
            precipitationChancePercent: hour.precipitationChance > 0 ? hour.precipitationChance * 100 : nil
        )
    }

    private func celsiusValue(from measurement: Measurement<UnitTemperature>) -> Double {
        measurement.converted(to: .celsius).value
    }

    private func closestHour(to date: Date, in hours: [HourWeather]) -> HourWeather? {
        hours.min { lhs, rhs in
            abs(lhs.date.timeIntervalSince(date)) < abs(rhs.date.timeIntervalSince(date))
        }
    }

    private func cachedDetail(for key: String, isToday: Bool) -> DayWeatherDetail? {
        guard let cached = cache[key] else { return nil }
        let age = Date().timeIntervalSince(cached.fetchedAt)
        if age > cached.ttl {
            cache.removeValue(forKey: key)
            return nil
        }
        if isToday, age > 30 * 60 {
            cache.removeValue(forKey: key)
            return nil
        }
        return cached.detail
    }
}

private struct CachedWeather: Sendable {
    let detail: DayWeatherDetail
    let fetchedAt: Date
    let ttl: TimeInterval
}

struct DisabledWeatherKitClient: WeatherKitProviding, Sendable {
    func fetchDayWeather(for date: Date, at location: CLLocation, calendar: Calendar) async throws -> DayWeatherSnapshot {
        throw WeatherKitClientError.unavailable
    }

    func fetchWeatherDetail(for date: Date, at location: CLLocation, calendar: Calendar) async throws -> DayWeatherDetail {
        throw WeatherKitClientError.unavailable
    }

    func fetchWorkoutWeather(at location: CLLocation, around startDate: Date) async throws -> DayWeatherSnapshot {
        throw WeatherKitClientError.unavailable
    }
}
