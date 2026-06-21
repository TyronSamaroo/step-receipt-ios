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

        #expect(snapshot.formattedTemperatureFahrenheit == "70°")
        #expect(snapshot.formattedTemperatureFahrenheitWithUnit == "70° F")
        #expect(snapshot.formattedApparentTemperatureFahrenheit == "73°")
        #expect(snapshot.formattedHumidity == "62%")
    }

    @Test
    func celsiusToFahrenheitConversion() {
        #expect(DayWeatherSnapshot.celsiusToFahrenheit(0) == 32)
        #expect(DayWeatherSnapshot.celsiusToFahrenheit(100) == 212)
    }

    @Test
    func windAndCompassFormatting() {
        let snapshot = DayWeatherSnapshot(
            temperatureCelsius: 20,
            humidityPercent: 50,
            windSpeedMetersPerSecond: 4.47,
            windDirectionDegrees: 45,
            source: .weatherKit
        )

        #expect(snapshot.formattedWindSpeedMPH == "10 mph")
        #expect(snapshot.formattedWind == "NE 10 mph")
        #expect(DayWeatherSnapshot.compassDirection(for: 0) == "N")
        #expect(DayWeatherSnapshot.compassDirection(for: 90) == "E")
    }

    @Test
    func highLowFormatting() {
        let snapshot = DayWeatherSnapshot(
            temperatureCelsius: 22,
            humidityPercent: 40,
            highTemperatureCelsius: 28,
            lowTemperatureCelsius: 16,
            source: .weatherKit
        )

        #expect(snapshot.formattedHighLowFahrenheit == "H 82° · L 61°")
    }

    @Test
    func displayFallbacksWhenOptionalFieldsMissing() {
        let snapshot = DayWeatherSnapshot(
            temperatureCelsius: 25.5,
            humidityPercent: 47,
            source: .healthKitWorkout
        )

        #expect(snapshot.displayConditionSymbolName == "cloud.sun.fill")
        #expect(snapshot.displayConditionDescription == "From workout")
        #expect(snapshot.displayApparentTemperatureFahrenheit == "—")
        #expect(snapshot.displayWind == "—")
        #expect(snapshot.displayUVIndex == "—")
        #expect(snapshot.hasSecondaryWeatherStats == false)
    }

    @Test
    func secondaryStatsFlagWhenOptionalFieldsPresent() {
        let snapshot = DayWeatherSnapshot(
            temperatureCelsius: 22,
            humidityPercent: 40,
            dewPointCelsius: 12,
            visibilityMeters: 10_000,
            precipitationChancePercent: 20,
            source: .weatherKit
        )

        #expect(snapshot.hasSecondaryWeatherStats == true)
        #expect(snapshot.displayDewPointFahrenheit == "54°")
        #expect(snapshot.displayPrecipitationChance == "20%")
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
