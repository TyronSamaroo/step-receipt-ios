import Foundation
import Testing
#if canImport(StepReceiptCore)
@testable import StepReceiptCore
#endif

struct ActivityFormattingTests {
    private let calendar: Calendar

    init() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        self.calendar = calendar
    }

    @Test
    func testFormattedHourlyRowPartsUsesMilesAndCalories() throws {
        let parts = ActivityFormatting.formattedHourlyRowParts(
            steps: 2_175,
            distanceMeters: 1_609.344,
            activeEnergyKilocalories: 87.4,
            unit: .miles
        )

        #expect(parts.stepsText == "2,175")
        #expect(parts.distanceText == "1.00 mi")
        #expect(parts.caloriesText == "87 kcal")
    }

    @Test
    func testFormattedHourlyRowPartsUsesKilometers() throws {
        let parts = ActivityFormatting.formattedHourlyRowParts(
            steps: 850,
            distanceMeters: 1_000,
            activeEnergyKilocalories: 42.6,
            unit: .kilometers
        )

        #expect(parts.stepsText == "850")
        #expect(parts.distanceText == "1.00 km")
        #expect(parts.caloriesText == "43 kcal")
    }

    @Test
    func testFormattedActiveWindowLabelUsesShortHourLabels() throws {
        let start = calendar.date(from: DateComponents(year: 2026, month: 6, day: 17, hour: 9))!
        let end = calendar.date(from: DateComponents(year: 2026, month: 6, day: 17, hour: 19))!

        let label = ActivityFormatting.formattedActiveWindowLabel(
            start: start,
            end: end,
            calendar: calendar
        )

        #expect(label == "Active 9a–7p")
    }
}
