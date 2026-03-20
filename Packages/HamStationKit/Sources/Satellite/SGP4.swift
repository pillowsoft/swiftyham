// SGP4.swift
// HamStationKit — Simplified General Perturbations model #4 for satellite orbit prediction.
//
// Reference: "Revisiting Spacetrack Report #3" by Vallado, Crawford, Hujsak, Kelso.
// Uses WGS84 constants and J2 perturbation for LEO satellite prediction.

import Foundation

// MARK: - SGP4

/// SGP4 orbital propagator for predicting satellite positions from TLE data.
public struct SGP4: Sendable {

    // MARK: - WGS84 Constants

    /// Earth equatorial radius in km.
    static let earthRadiusKm: Double = 6378.137
    /// Earth gravitational parameter (mu) in km^3/min^2.
    static let mu: Double = 398600.4418 / (60.0 * 60.0)  // convert km^3/s^2 to km^3/min^2
    /// J2 perturbation coefficient.
    static let j2: Double = 1.08262998905e-3
    /// Speed of light in km/s.
    static let speedOfLightKmPerSec: Double = 299792.458
    /// Minutes per day.
    static let minutesPerDay: Double = 1440.0
    /// Two pi.
    static let twoPi: Double = 2.0 * .pi
    /// Degrees to radians conversion factor.
    static let deg2rad: Double = .pi / 180.0
    /// Radians to degrees conversion factor.
    static let rad2deg: Double = 180.0 / .pi
    /// Earth's rotation rate in rad/min.
    static let earthRotationRate: Double = 7.2921151467e-5 * 60.0  // rad/min
    /// Flattening factor for WGS84.
    static let flattening: Double = 1.0 / 298.257223563

    // MARK: - Position Types

    /// Earth-Centered Inertial position and velocity.
    struct ECIPosition: Sendable {
        var x: Double  // km
        var y: Double  // km
        var z: Double  // km
        var vx: Double // km/min
        var vy: Double // km/min
        var vz: Double // km/min
    }

    /// A satellite position in geographic coordinates.
    public struct SatellitePosition: Sendable, Equatable {
        /// Latitude in degrees (-90 to 90).
        public var latitude: Double
        /// Longitude in degrees (-180 to 180).
        public var longitude: Double
        /// Altitude above sea level in km.
        public var altitude: Double
        /// Velocity magnitude in km/s.
        public var velocity: Double
    }

    /// A predicted satellite pass over an observer location.
    public struct SatellitePass: Sendable, Identifiable, Equatable {
        public let id: UUID
        /// Name of the satellite.
        public var satelliteName: String
        /// Acquisition of signal time.
        public var aos: Date
        /// Loss of signal time.
        public var los: Date
        /// Maximum elevation during the pass in degrees.
        public var maxElevation: Double
        /// Time of maximum elevation.
        public var maxElevationTime: Date
        /// Azimuth at AOS in degrees.
        public var aosAzimuth: Double
        /// Azimuth at LOS in degrees.
        public var losAzimuth: Double
    }

    // MARK: - Propagation

    /// Predict satellite position at a given date using SGP4 propagation.
    ///
    /// - Parameters:
    ///   - tle: The satellite's Two-Line Element set.
    ///   - date: The date/time to compute the position for.
    /// - Returns: The satellite's geographic position, or nil if computation fails.
    public static func propagate(tle: TLE, date: Date) -> SatellitePosition? {
        // Minutes since TLE epoch
        let tsince = date.timeIntervalSince(tle.epoch) / 60.0

        guard let eci = propagateECI(tle: tle, tsince: tsince) else { return nil }
        return eciToGeodetic(eci: eci, date: date)
    }

    /// Core SGP4 propagation returning ECI coordinates.
    ///
    /// Implements the simplified SGP4 algorithm with secular and periodic perturbations.
    static func propagateECI(tle: TLE, tsince: Double) -> ECIPosition? {
        // Convert orbital elements to radians
        let incl = tle.inclination * deg2rad
        let raan0 = tle.raan * deg2rad
        let ecc0 = tle.eccentricity
        let argp0 = tle.argOfPerigee * deg2rad
        let ma0 = tle.meanAnomaly * deg2rad
        let n0 = tle.meanMotion * twoPi / minutesPerDay  // rad/min
        let bstar = tle.bstar

        let a1 = pow(mu / (n0 * n0), 1.0 / 3.0)
        let cosIncl = cos(incl)
        let cosIncl2 = cosIncl * cosIncl
        let k2 = 0.5 * j2 * earthRadiusKm * earthRadiusKm

        // Brouwer mean motion corrections
        let d1 = 1.5 * k2 * (3.0 * cosIncl2 - 1.0) / (a1 * a1 * pow(1.0 - ecc0 * ecc0, 1.5))
        let a0 = a1 * (1.0 - d1 / 3.0 - d1 * d1 - 134.0 / 81.0 * d1 * d1 * d1)
        let d0 = 1.5 * k2 * (3.0 * cosIncl2 - 1.0) / (a0 * a0 * pow(1.0 - ecc0 * ecc0, 1.5))
        let noPrime = n0 / (1.0 + d0)
        let aoPrime = a0 / (1.0 - d0)
        let perigee = (aoPrime * (1.0 - ecc0) - earthRadiusKm)

        // Check for valid perigee
        guard perigee > -earthRadiusKm else { return nil }

        let s = perigee < 156.0 ? aoPrime * (1.0 - ecc0) - earthRadiusKm + 78.0 : 78.0 + earthRadiusKm
        let qoms2t: Double = {
            let qo = 120.0 + earthRadiusKm
            let s_val = s
            let q = (qo - s_val) / earthRadiusKm
            return q * q * q * q
        }()

        let xi = 1.0 / (aoPrime - s / earthRadiusKm * earthRadiusKm)
        let beta0sq = 1.0 - ecc0 * ecc0
        let beta0 = sqrt(beta0sq)
        let eta = aoPrime * ecc0 * xi

        // Secular perturbation coefficients
        let c2 = qoms2t * pow(xi, 4.0) * noPrime * pow(1.0 - eta * eta, -3.5) *
            (aoPrime * (1.0 + 1.5 * eta * eta + 4.0 * ecc0 * eta + ecc0 * eta * eta * eta) +
             0.75 * k2 * xi / (1.0 - eta * eta) *
             (-(0.5 - 1.5 * cosIncl2) + k2 * xi * (3.0 - 12.0 * cosIncl2 + 9.0 * cosIncl2 * cosIncl2) / (1.0 - eta * eta)))

        let c1 = bstar * c2
        let sinIncl = sin(incl)
        let a30 = -j2 * earthRadiusKm / 2.0  // simplified J3 effect

        let c3 = (ecc0 > 1.0e-4) ?
            qoms2t * pow(xi, 5.0) * a30 * noPrime * sinIncl / (k2 * ecc0) : 0.0

        let c4 = 2.0 * noPrime * qoms2t * pow(xi, 4.0) * aoPrime * beta0sq *
            pow(1.0 - eta * eta, -3.5) *
            ((2.0 * eta * (1.0 + ecc0 * eta) + 0.5 * ecc0 + 0.5 * eta * eta * eta) -
             2.0 * k2 * xi / (aoPrime * (1.0 - eta * eta)) *
             (3.0 * (1.0 - 3.0 * cosIncl2) * (1.0 + 1.5 * eta * eta - 2.0 * ecc0 * eta - 0.5 * ecc0 * eta * eta * eta) +
              0.75 * (1.0 - cosIncl2) * (2.0 * eta * eta - ecc0 * eta - ecc0 * eta * eta * eta) * cos(2.0 * argp0)))

        let c5 = 2.0 * qoms2t * pow(xi, 4.0) * aoPrime * beta0sq *
            pow(1.0 - eta * eta, -3.5) * (1.0 + 2.75 * (eta * eta + ecc0 * eta) + ecc0 * eta * eta * eta)

        // Secular rates
        let raanDot = -noPrime * k2 * cosIncl / (aoPrime * aoPrime * beta0sq) * 2.0
        let argpDot = noPrime * k2 * (2.0 - 2.5 * sinIncl * sinIncl) / (aoPrime * aoPrime * beta0sq)

        // Update for time
        let mdf = ma0 + noPrime * tsince
        let argpdf = argp0 + argpDot * tsince
        let raandf = raan0 + raanDot * tsince - 1.5 * k2 * cosIncl / (aoPrime * aoPrime * beta0sq) * c1 * tsince * tsince

        let mp = mdf
        let argp = argpdf
        let raan = raandf

        // Secular drag and gravitational effects
        let e = ecc0 - bstar * c4 * tsince
        let a = aoPrime * pow(1.0 - c1 * tsince, 2.0)
        let n = noPrime + 1.5 * c1 * tsince

        guard e < 1.0, e > 0.0, a > 0.0 else { return nil }

        // Solve Kepler's equation
        var u = fmod(mp + argp, twoPi)
        if u < 0 { u += twoPi }

        let eccentricAnomaly = solveKepler(meanAnomaly: fmod(mp, twoPi), eccentricity: e)

        // True anomaly
        let sinE = sin(eccentricAnomaly)
        let cosE = cos(eccentricAnomaly)
        let sinTrueAnomaly = sqrt(1.0 - e * e) * sinE / (1.0 - e * cosE)
        let cosTrueAnomaly = (cosE - e) / (1.0 - e * cosE)
        let trueAnomaly = atan2(sinTrueAnomaly, cosTrueAnomaly)

        // Distance and velocity in orbital plane
        let r = a * (1.0 - e * cosE)
        let rdot = sqrt(mu) * e * sinE / (r * sqrt(a))
        let rfdot = sqrt(mu) * sqrt(1.0 - e * e) / (r)

        // Argument of latitude
        let argLat = trueAnomaly + argp

        // Short-period perturbations
        let sin2u = sin(2.0 * argLat)
        let cos2u = cos(2.0 * argLat)

        let rk = r + 0.5 * k2 * sinIncl * sinIncl * cos2u / (aoPrime * beta0sq)
        let uk = argLat - 0.25 * k2 * (7.0 * cosIncl2 - 1.0) * sin2u / (aoPrime * aoPrime * beta0sq)
        let raank = raan + 1.5 * k2 * cosIncl * sin2u / (aoPrime * aoPrime * beta0sq)
        let ik = incl + 1.5 * k2 * sinIncl * cosIncl * cos2u / (aoPrime * aoPrime * beta0sq)

        // Orientation vectors
        let sinUk = sin(uk)
        let cosUk = cos(uk)
        let sinRaan = sin(raank)
        let cosRaan = cos(raank)
        let sinIk = sin(ik)
        let cosIk = cos(ik)

        let mx = -sinRaan * cosIk
        let my = cosRaan * cosIk

        let ux = mx * sinUk + cosRaan * cosUk
        let uy = my * sinUk + sinRaan * cosUk
        let uz = sinIk * sinUk

        let vx = mx * cosUk - cosRaan * sinUk
        let vy = my * cosUk - sinRaan * sinUk
        let vz = sinIk * cosUk

        // Position and velocity in ECI
        let x = rk * ux
        let y = rk * uy
        let z = rk * uz

        let xdot = rdot * ux + rfdot * vx
        let ydot = rdot * uy + rfdot * vy
        let zdot = rdot * uz + rfdot * vz

        return ECIPosition(x: x, y: y, z: z, vx: xdot, vy: ydot, vz: zdot)
    }

    // MARK: - Kepler Solver

    /// Solve Kepler's equation M = E - e*sin(E) for eccentric anomaly E.
    static func solveKepler(meanAnomaly: Double, eccentricity: Double, tolerance: Double = 1.0e-12) -> Double {
        var ma = meanAnomaly
        // Normalize to [0, 2pi)
        ma = fmod(ma, twoPi)
        if ma < 0 { ma += twoPi }

        // Initial guess
        var E = ma + eccentricity * sin(ma) * (1.0 + eccentricity * cos(ma))

        // Newton-Raphson iteration
        for _ in 0..<50 {
            let dE = (E - eccentricity * sin(E) - ma) / (1.0 - eccentricity * cos(E))
            E -= dE
            if abs(dE) < tolerance { break }
        }

        return E
    }

    // MARK: - Coordinate Conversion

    /// Convert ECI position to geodetic (lat/lon/alt).
    static func eciToGeodetic(eci: ECIPosition, date: Date) -> SatellitePosition {
        // Greenwich Mean Sidereal Time
        let gmst = greenwichSiderealTime(date: date)

        let r = sqrt(eci.x * eci.x + eci.y * eci.y + eci.z * eci.z)

        // Longitude
        var longitude = atan2(eci.y, eci.x) - gmst
        longitude = fmod(longitude, twoPi)
        if longitude > .pi { longitude -= twoPi }
        if longitude < -.pi { longitude += twoPi }

        // Latitude (iterative for oblate earth)
        let rxy = sqrt(eci.x * eci.x + eci.y * eci.y)
        var latitude = atan2(eci.z, rxy)

        let e2 = flattening * (2.0 - flattening)
        for _ in 0..<10 {
            let sinLat = sin(latitude)
            let N = earthRadiusKm / sqrt(1.0 - e2 * sinLat * sinLat)
            latitude = atan2(eci.z + e2 * N * sinLat, rxy)
        }

        // Altitude
        let sinLat = sin(latitude)
        let N = earthRadiusKm / sqrt(1.0 - e2 * sinLat * sinLat)
        let cosLat = cos(latitude)
        let altitude: Double
        if abs(cosLat) > 1e-10 {
            altitude = rxy / cosLat - N
        } else {
            altitude = abs(eci.z) - N * (1.0 - e2)
        }

        // Velocity magnitude in km/s (convert from km/min)
        let velocity = sqrt(eci.vx * eci.vx + eci.vy * eci.vy + eci.vz * eci.vz) / 60.0

        // Velocity to km/s
        return SatellitePosition(
            latitude: latitude * rad2deg,
            longitude: longitude * rad2deg,
            altitude: altitude,
            velocity: velocity
        )
    }

    /// Compute Greenwich Mean Sidereal Time in radians.
    static func greenwichSiderealTime(date: Date) -> Double {
        // Julian date
        let jd = julianDate(from: date)
        let T = (jd - 2451545.0) / 36525.0

        // GMST in seconds of time
        var gmst = 67310.54841 + (876600.0 * 3600.0 + 8640184.812866) * T +
                   0.093104 * T * T - 6.2e-6 * T * T * T

        // Convert to radians
        gmst = fmod(gmst * twoPi / 86400.0, twoPi)
        if gmst < 0 { gmst += twoPi }

        return gmst
    }

    /// Convert a `Date` to Julian date.
    static func julianDate(from date: Date) -> Double {
        // J2000.0 epoch = 2000-01-01T12:00:00 UTC = JD 2451545.0
        let j2000Ref = Date(timeIntervalSinceReferenceDate: -31557600.0) // 2000-01-01T12:00:00 UTC approx
        // More precise: 2000-01-01 12:00:00 UTC
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        var components = DateComponents()
        components.year = 2000
        components.month = 1
        components.day = 1
        components.hour = 12
        components.minute = 0
        components.second = 0
        let j2000Date = calendar.date(from: components)!

        let daysSinceJ2000 = date.timeIntervalSince(j2000Date) / 86400.0
        return 2451545.0 + daysSinceJ2000
    }

    // MARK: - Pass Prediction

    /// Predict visible passes over an observer location.
    ///
    /// - Parameters:
    ///   - tle: The satellite's TLE data.
    ///   - observer: Observer's latitude (deg), longitude (deg), altitude (km).
    ///   - startDate: Start of the prediction window.
    ///   - days: Number of days to predict.
    ///   - minElevation: Minimum peak elevation to include (degrees above horizon).
    /// - Returns: Array of predicted passes sorted by AOS time.
    public static func predictPasses(
        tle: TLE,
        observer: (latitude: Double, longitude: Double, altitude: Double),
        startDate: Date,
        days: Int = 7,
        minElevation: Double = 5
    ) -> [SatellitePass] {
        var passes: [SatellitePass] = []
        let endDate = startDate.addingTimeInterval(Double(days) * 86400.0)
        let stepSeconds: TimeInterval = 60.0  // 1-minute steps for initial scan
        let fineStepSeconds: TimeInterval = 5.0  // 5-second steps for refinement

        var currentDate = startDate
        var inPass = false
        var passAOS: Date = startDate
        var passAOSAz: Double = 0
        var maxElev: Double = 0
        var maxElevTime: Date = startDate

        while currentDate < endDate {
            guard let position = propagate(tle: tle, date: currentDate) else {
                currentDate = currentDate.addingTimeInterval(stepSeconds)
                continue
            }

            let angles = lookAngles(satellitePosition: position, observer: observer)

            if angles.elevation > 0 {
                if !inPass {
                    // Start of pass — refine AOS
                    inPass = true
                    // Step back and find the precise AOS
                    var refineDate = currentDate.addingTimeInterval(-stepSeconds)
                    var foundAOS = currentDate
                    while refineDate < currentDate {
                        if let refPos = propagate(tle: tle, date: refineDate) {
                            let refAngles = lookAngles(satellitePosition: refPos, observer: observer)
                            if refAngles.elevation > 0 {
                                foundAOS = refineDate
                                break
                            }
                        }
                        refineDate = refineDate.addingTimeInterval(fineStepSeconds)
                    }
                    passAOS = foundAOS
                    if let aosPos = propagate(tle: tle, date: passAOS) {
                        let aosAngles = lookAngles(satellitePosition: aosPos, observer: observer)
                        passAOSAz = aosAngles.azimuth
                    }
                    maxElev = angles.elevation
                    maxElevTime = currentDate
                }

                if angles.elevation > maxElev {
                    maxElev = angles.elevation
                    maxElevTime = currentDate
                }
            } else if inPass {
                // End of pass — refine LOS
                inPass = false
                var refineDate = currentDate.addingTimeInterval(-stepSeconds)
                var foundLOS = currentDate
                while refineDate < currentDate {
                    if let refPos = propagate(tle: tle, date: refineDate) {
                        let refAngles = lookAngles(satellitePosition: refPos, observer: observer)
                        if refAngles.elevation <= 0 {
                            foundLOS = refineDate
                            break
                        }
                    }
                    refineDate = refineDate.addingTimeInterval(fineStepSeconds)
                }

                let losAz: Double
                if let losPos = propagate(tle: tle, date: foundLOS) {
                    let losAngles = lookAngles(satellitePosition: losPos, observer: observer)
                    losAz = losAngles.azimuth
                } else {
                    losAz = 0
                }

                if maxElev >= minElevation {
                    let pass = SatellitePass(
                        id: UUID(),
                        satelliteName: tle.name,
                        aos: passAOS,
                        los: foundLOS,
                        maxElevation: maxElev,
                        maxElevationTime: maxElevTime,
                        aosAzimuth: passAOSAz,
                        losAzimuth: losAz
                    )
                    passes.append(pass)
                }

                maxElev = 0
            }

            currentDate = currentDate.addingTimeInterval(stepSeconds)
        }

        return passes.sorted { $0.aos < $1.aos }
    }

    // MARK: - Doppler Shift

    /// Calculate Doppler-corrected frequency.
    ///
    /// - Parameters:
    ///   - nominalFrequencyHz: The satellite's nominal operating frequency in Hz.
    ///   - rangeRateKmPerSec: Rate of change of range to satellite in km/s (positive = receding).
    /// - Returns: Doppler-corrected frequency in Hz.
    public static func dopplerShift(
        nominalFrequencyHz: Double,
        rangeRateKmPerSec: Double
    ) -> Double {
        // f_corrected = f_nominal * (1 - rangeRate / c)
        return nominalFrequencyHz * (1.0 - rangeRateKmPerSec / speedOfLightKmPerSec)
    }

    // MARK: - Look Angles

    /// Calculate azimuth, elevation, and range from observer to satellite.
    ///
    /// - Parameters:
    ///   - satellitePosition: The satellite's geographic position.
    ///   - observer: Observer's latitude (deg), longitude (deg), altitude (km).
    /// - Returns: Azimuth (degrees, 0-360), elevation (degrees), and range (km).
    public static func lookAngles(
        satellitePosition: SatellitePosition,
        observer: (latitude: Double, longitude: Double, altitude: Double)
    ) -> (azimuth: Double, elevation: Double, range: Double) {
        let satLat = satellitePosition.latitude * deg2rad
        let satLon = satellitePosition.longitude * deg2rad
        let obsLat = observer.latitude * deg2rad
        let obsLon = observer.longitude * deg2rad

        let satR = earthRadiusKm + satellitePosition.altitude
        let obsR = earthRadiusKm + observer.altitude

        // Convert both to ECEF
        let satX = satR * cos(satLat) * cos(satLon)
        let satY = satR * cos(satLat) * sin(satLon)
        let satZ = satR * sin(satLat)

        let obsX = obsR * cos(obsLat) * cos(obsLon)
        let obsY = obsR * cos(obsLat) * sin(obsLon)
        let obsZ = obsR * sin(obsLat)

        // Range vector
        let rx = satX - obsX
        let ry = satY - obsY
        let rz = satZ - obsZ
        let rangeKm = sqrt(rx * rx + ry * ry + rz * rz)

        // Rotate range vector to topocentric (South-East-Up)
        let sinLat = sin(obsLat)
        let cosLat = cos(obsLat)
        let sinLon = sin(obsLon)
        let cosLon = cos(obsLon)

        let south = sinLat * cosLon * rx + sinLat * sinLon * ry - cosLat * rz
        let east = -sinLon * rx + cosLon * ry
        let up = cosLat * cosLon * rx + cosLat * sinLon * ry + sinLat * rz

        // Elevation
        let elevation = atan2(up, sqrt(south * south + east * east)) * rad2deg

        // Azimuth (from north, clockwise)
        var azimuth = atan2(east, -south) * rad2deg
        if azimuth < 0 { azimuth += 360.0 }

        return (azimuth: azimuth, elevation: elevation, range: rangeKm)
    }
}
