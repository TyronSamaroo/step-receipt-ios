import Foundation
import Testing
#if canImport(StepReceiptCore)
@testable import StepReceiptCore
#endif

struct DayWeatherSnapshotTests {
    @Test
    func formattedTemperatureFahrenheitRoundsCorrectly() {
        let snapshot = DayWeatherSnapshot(
            temperatureCelsius: 21,
            humidityPercent: 62,
            apparentTemperatureCelsius: 23,
            source: .weatherKit
        )

        #expect(snapshot.formattedTemperatureFahrenheit == "70 F")
        #expect(snapshot.formattedApparentTemperatureFahrenheit == "73 F")
        #expect(snapshot.formattedHumidity == "62%")
    }

    @Test
    func celsiusToFahrenheitConversion() {
        #expect(DayWeatherSnapshot.celsiusToFahrenheit(0) == 32)
        #expect(DayWeatherSnapshot.celsiusToFahrenheit(100) == 212)
    }

    @Test
    func cacheKeyBucketsCoordinates() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let date = calendar.date(from: DateComponents(year: 2026, month: 6, day: 21, hour: 12))!

        let keyA = DayWeatherSnapshot.cacheKey(for: date, latitude: 37.7749, longitude: -122.4194, calendar: calendar)
        let keyB = DayWeatherSnapshot.cacheKey(for: date, latitude: 37.7751, longitude: -122.4196, calendar: calendar)
        let keyC = DayWeatherSnapshot.cacheKey(for: date, latitude: 37.78, longitude: -122.42, calendar: calendar)

        #expect(keyA == keyB)
        #expect(keyA != keyC)
    }
}
