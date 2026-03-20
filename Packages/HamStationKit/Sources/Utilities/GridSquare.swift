// GridSquare.swift
// HamStationKit — Maidenhead grid square utilities.

import Foundation

/// Maidenhead grid square calculation utilities.
///
/// The Maidenhead Locator System divides the Earth into grid squares
/// for amateur radio position reporting.
public struct GridSquare: Sendable {

    // MARK: - Validation

    /// Returns whether the given string is a valid Maidenhead grid square.
    ///
    /// Valid formats:
    /// - 4 characters: 2 uppercase letters (A-R) + 2 digits (e.g., "FN31")
    /// - 6 characters: 4-char + 2 lowercase letters a-x (e.g., "FN31pr")
    public static func isValid(_ grid: String) -> Bool {
        let count = grid.count
        guard count == 4 || count == 6 else { return false }

        let chars = Array(grid)

        // First two characters: A-R (uppercase)
        let field1 = chars[0]
        let field2 = chars[1]
        guard field1.isUppercase, field2.isUppercase,
              field1 >= "A", field1 <= "R",
              field2 >= "A", field2 <= "R" else {
            return false
        }

        // Next two characters: 0-9
        guard chars[2].isNumber, chars[3].isNumber else {
            return false
        }

        // Optional subsquare: a-x lowercase
        if count == 6 {
            let sub1 = chars[4]
            let sub2 = chars[5]
            guard sub1.isLowercase, sub2.isLowercase,
                  sub1 >= "a", sub1 <= "x",
                  sub2 >= "a", sub2 <= "x" else {
                return false
            }
        }

        return true
    }

    // MARK: - Grid to Coordinates

    /// Returns the center coordinates of the given grid square.
    ///
    /// - Parameter grid: A 4 or 6 character Maidenhead grid square.
    /// - Returns: Latitude and longitude in degrees, or nil if the grid is invalid.
    public static func coordinates(from grid: String) -> (latitude: Double, longitude: Double)? {
        guard isValid(grid) else { return nil }
        let chars = Array(grid)

        // Field: each letter = 20° longitude, 10° latitude
        let lonField = Double(chars[0].asciiValue! - Character("A").asciiValue!)
        let latField = Double(chars[1].asciiValue! - Character("A").asciiValue!)

        // Square: each digit = 2° longitude, 1° latitude
        let lonSquare = Double(chars[2].wholeNumberValue!)
        let latSquare = Double(chars[3].wholeNumberValue!)

        var longitude = lonField * 20.0 + lonSquare * 2.0 - 180.0
        var latitude = latField * 10.0 + latSquare * 1.0 - 90.0

        if grid.count == 6 {
            // Subsquare: each letter = 5' longitude (5/60°), 2.5' latitude (2.5/60°)
            let lonSub = Double(chars[4].asciiValue! - Character("a").asciiValue!)
            let latSub = Double(chars[5].asciiValue! - Character("a").asciiValue!)
            longitude += lonSub * (2.0 / 24.0) + (1.0 / 24.0)  // center of subsquare
            latitude += latSub * (1.0 / 24.0) + (0.5 / 24.0)
        } else {
            // Center of the square
            longitude += 1.0
            latitude += 0.5
        }

        return (latitude: latitude, longitude: longitude)
    }

    // MARK: - Coordinates to Grid

    /// Returns a 6-character Maidenhead grid square for the given coordinates.
    ///
    /// - Parameters:
    ///   - latitude: Latitude in degrees (-90 to 90).
    ///   - longitude: Longitude in degrees (-180 to 180).
    /// - Returns: A 6-character grid square string.
    public static func grid(from latitude: Double, longitude: Double) -> String {
        let adjustedLon = longitude + 180.0
        let adjustedLat = latitude + 90.0

        // Field
        let lonField = Int(adjustedLon / 20.0)
        let latField = Int(adjustedLat / 10.0)

        // Square
        let lonSquare = Int((adjustedLon - Double(lonField) * 20.0) / 2.0)
        let latSquare = Int(adjustedLat - Double(latField) * 10.0)

        // Subsquare
        let lonRemainder = adjustedLon - Double(lonField) * 20.0 - Double(lonSquare) * 2.0
        let latRemainder = adjustedLat - Double(latField) * 10.0 - Double(latSquare) * 1.0

        let lonSub = Int(lonRemainder / (2.0 / 24.0))
        let latSub = Int(latRemainder / (1.0 / 24.0))

        let field1 = Character(UnicodeScalar(65 + min(max(lonField, 0), 17))!)
        let field2 = Character(UnicodeScalar(65 + min(max(latField, 0), 17))!)
        let square1 = Character(UnicodeScalar(48 + min(max(lonSquare, 0), 9))!)
        let square2 = Character(UnicodeScalar(48 + min(max(latSquare, 0), 9))!)
        let sub1 = Character(UnicodeScalar(97 + min(max(lonSub, 0), 23))!)
        let sub2 = Character(UnicodeScalar(97 + min(max(latSub, 0), 23))!)

        return String([field1, field2, square1, square2, sub1, sub2])
    }

    // MARK: - Distance

    /// Great circle distance between two grid squares in kilometers.
    ///
    /// Uses the Haversine formula.
    /// - Returns: Distance in km, or nil if either grid is invalid.
    public static func distance(from grid1: String, to grid2: String) -> Double? {
        guard let coord1 = coordinates(from: grid1),
              let coord2 = coordinates(from: grid2) else {
            return nil
        }
        return haversineDistance(
            lat1: coord1.latitude, lon1: coord1.longitude,
            lat2: coord2.latitude, lon2: coord2.longitude
        )
    }

    /// Initial bearing from one grid square to another in degrees (0-360).
    ///
    /// - Returns: Bearing in degrees, or nil if either grid is invalid.
    public static func bearing(from grid1: String, to grid2: String) -> Double? {
        guard let coord1 = coordinates(from: grid1),
              let coord2 = coordinates(from: grid2) else {
            return nil
        }
        return initialBearing(
            lat1: coord1.latitude, lon1: coord1.longitude,
            lat2: coord2.latitude, lon2: coord2.longitude
        )
    }

    // MARK: - Private Helpers

    private static let earthRadiusKm = 6371.0

    /// Haversine formula for great circle distance.
    private static func haversineDistance(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> Double {
        let dLat = (lat2 - lat1).degreesToRadians
        let dLon = (lon2 - lon1).degreesToRadians
        let lat1Rad = lat1.degreesToRadians
        let lat2Rad = lat2.degreesToRadians

        let a = sin(dLat / 2) * sin(dLat / 2) +
                cos(lat1Rad) * cos(lat2Rad) * sin(dLon / 2) * sin(dLon / 2)
        let c = 2 * atan2(sqrt(a), sqrt(1 - a))

        return earthRadiusKm * c
    }

    /// Initial bearing using the forward azimuth formula.
    private static func initialBearing(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> Double {
        let lat1Rad = lat1.degreesToRadians
        let lat2Rad = lat2.degreesToRadians
        let dLon = (lon2 - lon1).degreesToRadians

        let y = sin(dLon) * cos(lat2Rad)
        let x = cos(lat1Rad) * sin(lat2Rad) - sin(lat1Rad) * cos(lat2Rad) * cos(dLon)

        let bearing = atan2(y, x).radiansToDegrees
        return (bearing + 360).truncatingRemainder(dividingBy: 360)
    }
}

// MARK: - Angle Conversion Helpers

private extension Double {
    var degreesToRadians: Double { self * .pi / 180.0 }
    var radiansToDegrees: Double { self * 180.0 / .pi }
}
