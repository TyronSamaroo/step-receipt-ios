import SwiftUI

enum WeatherCardStyle {
    static func gradientColors(for weather: DayWeatherSnapshot) -> [Color] {
        let symbol = weather.displayConditionSymbolName
        if symbol.contains("sun") || symbol.contains("clear") {
            return [Color.stepSurface, Color.stepEnergy.opacity(0.22), Color.stepWarning.opacity(0.12)]
        }
        if symbol.contains("rain") || symbol.contains("drizzle") || symbol.contains("snow") {
            return [Color.stepSurface, Color.stepDistance.opacity(0.24), Color.stepAccent.opacity(0.12)]
        }
        if symbol.contains("cloud") {
            return [Color.stepSurface, Color.stepMuted.opacity(0.16), Color.stepDistance.opacity(0.14)]
        }
        return [Color.stepSurface, Color.stepDistance.opacity(0.16), Color.stepAccent.opacity(0.12)]
    }
}
