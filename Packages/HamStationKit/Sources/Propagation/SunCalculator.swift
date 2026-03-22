// SunCalculator.swift
// HamStationKit — Sunrise/sunset and grey line calculation for propagation assessment.
// Uses the NOAA Solar Calculator algorithm (no external dependencies).

import Foundation

/// Calculates sunrise, sunset, and twilight times for any location on Earth.
///
/// Based on the NOAA Solar Calculator equations which provide accuracy within
/// ~1 minute for locations between 72°N and 72°S latitude. Used for:
/// - Grey line overlay on the propagation map
/// - Sunrise/sunset display for operator's QTH and target locations
/// - Band opening predictions (e.g., 160m grey line propagation)
public struct SunCalculator: Sendable {

    /// Solar event times for a given location and date.
    public struct SolarTimes: Sendable, Equatable {
        /// Sunrise time in UTC.
        public var sunrise: Date?
        /// Sunset time in UTC.
        public var sunset: Date?
        /// Civil twilight start (sun 6° below horizon).
        public var civilDawn: Date?
        /// Civil twilight end (sun 6° below horizon).
        public var civilDusk: Date?
        /// Whether the sun is currently above the horizon.
        public var isDaytime: Bool
        /// Whether the location is in perpetual daylight (polar summer).
        public var isPolarDay: Bool
        /// Whether the location is in perpetual darkness (polar winter).
        public var isPolarNight: Bool
    }

    // MARK: - Public API

    /// Calculate solar times for a given location and date.
    ///
    /// - Parameters:
    ///   - latitude: Latitude in degrees (-90 to 90).
    ///   - longitude: Longitude in degrees (-180 to 180).
    ///   - date: The date to calculate for (defaults to now).
    /// - Returns: Solar event times for the location.
    public static func solarTimes(
        latitude: Double,
        longitude: Double,
        date: Date = Date()
    ) -> SolarTimes {
        let jd = julianDay(from: date)
        let jc = julianCentury(from: jd)

        let solarNoon = solarNoonUTC(julianCentury: jc, longitude: longitude)
        let hourAngle = sunriseHourAngle(latitude: latitude, julianCentury: jc, zenith: 90.833)
        let civilHA = sunriseHourAngle(latitude: latitude, julianCentury: jc, zenith: 96.0)

        let calendar = Calendar(identifier: .gregorian)
        let startOfDay = calendar.startOfDay(for: date)

        if hourAngle.isNaN {
            // Polar day or polar night
            let declination = sunDeclination(julianCentury: jc)
            let isPolarDay = (latitude > 0 && declination > 0) || (latitude < 0 && declination < 0)
            return SolarTimes(
                isDaytime: isPolarDay,
                isPolarDay: isPolarDay,
                isPolarNight: !isPolarDay
            )
        }

        let sunriseMinutes = solarNoon - hourAngle * 4 // 4 minutes per degree
        let sunsetMinutes = solarNoon + hourAngle * 4

        let sunrise = startOfDay.addingTimeInterval(sunriseMinutes * 60)
        let sunset = startOfDay.addingTimeInterval(sunsetMinutes * 60)

        var civilDawn: Date?
        var civilDusk: Date?
        if !civilHA.isNaN {
            let civilDawnMinutes = solarNoon - civilHA * 4
            let civilDuskMinutes = solarNoon + civilHA * 4
            civilDawn = startOfDay.addingTimeInterval(civilDawnMinutes * 60)
            civilDusk = startOfDay.addingTimeInterval(civilDuskMinutes * 60)
        }

        let isDaytime = date >= sunrise && date <= sunset

        return SolarTimes(
            sunrise: sunrise,
            sunset: sunset,
            civilDawn: civilDawn,
            civilDusk: civilDusk,
            isDaytime: isDaytime,
            isPolarDay: false,
            isPolarNight: false
        )
    }

    /// Calculate the grey line boundary as an array of (latitude, longitude) points.
    ///
    /// The grey line is the terminator — the boundary between day and night on Earth.
    /// Returns points along the terminator that can be plotted as a MapKit overlay.
    ///
    /// - Parameter date: The date/time to calculate for (defaults to now).
    /// - Returns: Array of (latitude, longitude) coordinate pairs tracing the terminator.
    public static func greyLinePath(date: Date = Date()) -> [(latitude: Double, longitude: Double)] {
        let jd = julianDay(from: date)
        let jc = julianCentury(from: jd)
        let declination = sunDeclination(julianCentury: jc)
        let decRad = declination * .pi / 180.0

        // Equation of time to find the sun's current longitude
        let eot = equationOfTime(julianCentury: jc) // minutes
        let calendar = Calendar(identifier: .gregorian)
        let components = calendar.dateComponents(in: TimeZone(identifier: "UTC")!, from: date)
        let minutesSinceMidnight = Double(components.hour ?? 0) * 60.0 + Double(components.minute ?? 0) + Double(components.second ?? 0) / 60.0
        let sunLongitude = -(minutesSinceMidnight + eot - 720.0) / 4.0

        // Trace the terminator at 2° longitude intervals
        var points: [(latitude: Double, longitude: Double)] = []
        for i in stride(from: -180.0, through: 180.0, by: 2.0) {
            let lonRad = (i - sunLongitude) * .pi / 180.0
            // At the terminator, the solar elevation is 0 (actually -0.833° for atmospheric refraction)
            // lat = atan(-cos(lon_offset) / tan(declination))
            let latRad: Double
            if abs(decRad) < 0.001 {
                // Near equinox — terminator runs N-S
                latRad = 0
            } else {
                latRad = atan(-cos(lonRad) / tan(decRad))
            }
            let lat = latRad * 180.0 / .pi
            points.append((latitude: lat, longitude: i))
        }

        return points
    }

    // MARK: - NOAA Solar Calculation Internals

    /// Julian Day Number from a Date.
    static func julianDay(from date: Date) -> Double {
        // Unix epoch (1970-01-01) = JD 2440587.5
        return date.timeIntervalSince1970 / 86400.0 + 2440587.5
    }

    /// Julian Century from Julian Day.
    static func julianCentury(from jd: Double) -> Double {
        (jd - 2451545.0) / 36525.0
    }

    /// Sun's geometric mean longitude (degrees).
    private static func sunGeomMeanLong(julianCentury t: Double) -> Double {
        var l0 = 280.46646 + t * (36000.76983 + 0.0003032 * t)
        l0 = l0.truncatingRemainder(dividingBy: 360.0)
        if l0 < 0 { l0 += 360.0 }
        return l0
    }

    /// Sun's geometric mean anomaly (degrees).
    private static func sunGeomMeanAnomaly(julianCentury t: Double) -> Double {
        357.52911 + t * (35999.05029 - 0.0001537 * t)
    }

    /// Earth's orbit eccentricity.
    private static func earthOrbitEccentricity(julianCentury t: Double) -> Double {
        0.016708634 - t * (0.000042037 + 0.0000001267 * t)
    }

    /// Sun's equation of center (degrees).
    private static func sunEquationOfCenter(julianCentury t: Double) -> Double {
        let m = sunGeomMeanAnomaly(julianCentury: t)
        let mrad = m * .pi / 180.0
        return sin(mrad) * (1.914602 - t * (0.004817 + 0.000014 * t))
             + sin(2 * mrad) * (0.019993 - 0.000101 * t)
             + sin(3 * mrad) * 0.000289
    }

    /// Sun's true longitude (degrees).
    private static func sunTrueLong(julianCentury t: Double) -> Double {
        sunGeomMeanLong(julianCentury: t) + sunEquationOfCenter(julianCentury: t)
    }

    /// Sun's apparent longitude (degrees).
    private static func sunApparentLong(julianCentury t: Double) -> Double {
        let trueLong = sunTrueLong(julianCentury: t)
        let omega = 125.04 - 1934.136 * t
        return trueLong - 0.00569 - 0.00478 * sin(omega * .pi / 180.0)
    }

    /// Mean obliquity of the ecliptic (degrees).
    private static func meanObliquity(julianCentury t: Double) -> Double {
        23.0 + (26.0 + (21.448 - t * (46.815 + t * (0.00059 - t * 0.001813))) / 60.0) / 60.0
    }

    /// Corrected obliquity (degrees).
    private static func obliquityCorrection(julianCentury t: Double) -> Double {
        let omega = 125.04 - 1934.136 * t
        return meanObliquity(julianCentury: t) + 0.00256 * cos(omega * .pi / 180.0)
    }

    /// Sun's declination (degrees).
    static func sunDeclination(julianCentury t: Double) -> Double {
        let e = obliquityCorrection(julianCentury: t)
        let lambda = sunApparentLong(julianCentury: t)
        return asin(sin(e * .pi / 180.0) * sin(lambda * .pi / 180.0)) * 180.0 / .pi
    }

    /// Equation of time (minutes).
    static func equationOfTime(julianCentury t: Double) -> Double {
        let e = earthOrbitEccentricity(julianCentury: t)
        let l0 = sunGeomMeanLong(julianCentury: t) * .pi / 180.0
        let m = sunGeomMeanAnomaly(julianCentury: t) * .pi / 180.0
        let y = tan(obliquityCorrection(julianCentury: t) * .pi / 360.0)
        let ySq = y * y

        let eot = ySq * sin(2 * l0)
                - 2 * e * sin(m)
                + 4 * e * ySq * sin(m) * cos(2 * l0)
                - 0.5 * ySq * ySq * sin(4 * l0)
                - 1.25 * e * e * sin(2 * m)

        return eot * 180.0 / .pi * 4.0 // Convert radians to minutes
    }

    /// Hour angle for sunrise/sunset at a given zenith (degrees).
    /// Returns NaN for polar day/night.
    private static func sunriseHourAngle(latitude: Double, julianCentury t: Double, zenith: Double) -> Double {
        let latRad = latitude * .pi / 180.0
        let decl = sunDeclination(julianCentury: t) * .pi / 180.0
        let zenRad = zenith * .pi / 180.0

        let cosHA = (cos(zenRad) / (cos(latRad) * cos(decl))) - tan(latRad) * tan(decl)

        if cosHA > 1.0 { return .nan } // Polar night
        if cosHA < -1.0 { return .nan } // Polar day

        return acos(cosHA) * 180.0 / .pi
    }

    /// Solar noon in minutes from midnight UTC.
    private static func solarNoonUTC(julianCentury t: Double, longitude: Double) -> Double {
        let eot = equationOfTime(julianCentury: t)
        return 720.0 - 4.0 * longitude - eot
    }
}
