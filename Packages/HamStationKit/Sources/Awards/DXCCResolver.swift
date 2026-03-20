// DXCCResolver.swift
// HamStationKit — Resolves callsigns to DXCC entities by prefix matching.

import Foundation

/// Resolves a callsign to its DXCC entity by prefix matching.
///
/// DXCC prefix matching rules:
/// - Most callsigns map by their prefix: W1AW -> "W" prefix -> USA (entity 291)
/// - Some have longer prefixes: VP2M -> Montserrat, VP2E -> Anguilla
/// - Maritime mobile (/MM) has no DXCC entity
/// - Aeronautical mobile (/AM) has no DXCC entity
/// - Portable suffixes like W1AW/VP9 -> use the VP9 prefix (Bermuda)
/// - A callsign like OH0/W1AW -> use OH0 prefix (Aland Islands)
public struct DXCCResolver: Sendable {

    /// Prefix -> DXCC entity ID lookup table.
    private let prefixTable: [String: Int]

    // MARK: - Initialization

    /// Build a resolver from a list of DXCC entities.
    /// Merges entity prefixes with the built-in default table.
    public init(entities: [DXCCEntity] = []) {
        var table = Self.defaultPrefixes
        for entity in entities {
            // Each entity may have a comma-separated prefix list
            let prefixes = entity.prefix
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespaces).uppercased() }
            for prefix in prefixes {
                table[prefix] = entity.id
            }
        }
        self.prefixTable = table
    }

    /// Build a resolver from a custom prefix table (useful for testing).
    public init(prefixTable: [String: Int]) {
        self.prefixTable = prefixTable
    }

    // MARK: - Resolution

    /// Resolves a callsign to its DXCC entity ID.
    ///
    /// Returns `nil` for maritime mobile (/MM), aeronautical mobile (/AM),
    /// or unrecognized prefixes.
    public func resolve(callsign: String) -> Int? {
        let call = callsign.uppercased().trimmingCharacters(in: .whitespaces)
        guard !call.isEmpty else { return nil }

        // 1. Check for /MM (maritime mobile) or /AM (aeronautical mobile)
        if call.hasSuffix("/MM") || call.hasSuffix("/AM") {
            return nil
        }

        // 2. Check for portable prefix: PREFIX/CALLSIGN (e.g., OH0/W1AW)
        //    The prefix portion is before the slash and is shorter or equal to the call portion.
        //    If the part before "/" looks like a prefix (no digits at end, or short), use it.
        if let slashIndex = call.firstIndex(of: "/") {
            let before = String(call[call.startIndex..<slashIndex])
            let after = String(call[call.index(after: slashIndex)...])

            // Skip /P, /M, /QRP and other single-char suffixes that aren't prefixes
            let shortSuffixes: Set<String> = ["P", "M", "QRP", "A", "B"]

            if !after.isEmpty && !shortSuffixes.contains(after) && after != "MM" && after != "AM" {
                // If 'after' looks like a callsign (has digits) and 'before' looks like a prefix,
                // then it's PREFIX/CALL format
                let beforeHasDigit = before.contains(where: \.isNumber)
                let afterHasDigit = after.contains(where: \.isNumber)

                if !beforeHasDigit && afterHasDigit {
                    // before is prefix, after is callsign (e.g., OH0 has digit but is prefix pattern)
                    // Actually OH0 has a digit. Let's use a simpler heuristic:
                    // If 'before' is shorter than 'after', treat 'before' as the prefix
                    if let resolved = longestPrefixMatch(before) {
                        return resolved
                    }
                } else if beforeHasDigit && !afterHasDigit {
                    // before is callsign, after is prefix suffix (e.g., W1AW/VP9)
                    if let resolved = longestPrefixMatch(after) {
                        return resolved
                    }
                } else if beforeHasDigit && afterHasDigit {
                    // Both have digits — shorter one is likely the prefix
                    if before.count <= after.count {
                        if let resolved = longestPrefixMatch(before) {
                            return resolved
                        }
                    } else {
                        if let resolved = longestPrefixMatch(after) {
                            return resolved
                        }
                    }
                }
            }

            // If we have a slash but didn't resolve via prefix/suffix,
            // try the part that looks most like a full callsign
            let basePart = before.count >= after.count ? before : after
            if basePart.contains(where: \.isNumber) {
                return longestPrefixMatch(basePart)
            }
        }

        // 3. No slash — standard callsign, try longest prefix match
        return longestPrefixMatch(call)
    }

    // MARK: - Private

    /// Try longest-prefix match: start with full string, remove trailing chars until a match.
    private func longestPrefixMatch(_ call: String) -> Int? {
        var candidate = call
        while !candidate.isEmpty {
            if let entityId = prefixTable[candidate] {
                return entityId
            }
            candidate = String(candidate.dropLast())
        }
        return nil
    }

    // MARK: - Default Prefix Table

    /// Built-in prefix table covering the ~100 most commonly contacted DXCC entities.
    /// This allows the resolver to work before the full DXCC database is loaded.
    public static let defaultPrefixes: [String: Int] = [
        // United States (291)
        "W": 291, "K": 291, "N": 291, "AA": 291, "AB": 291, "AC": 291,
        "AD": 291, "AE": 291, "AF": 291, "AG": 291, "AH": 291, "AI": 291,
        "AJ": 291, "AK": 291, "AL": 291, "KA": 291, "KB": 291, "KC": 291,
        "KD": 291, "KE": 291, "KF": 291, "KG": 291, "KH": 291, "KI": 291,
        "KJ": 291, "KK": 291, "KL": 291, "KM": 291, "KN": 291, "KO": 291,
        "KP": 291, "KQ": 291, "KR": 291, "KS": 291, "KT": 291, "KU": 291,
        "KV": 291, "KW": 291, "KX": 291, "KY": 291, "KZ": 291,
        "NA": 291, "NB": 291, "NC": 291, "ND": 291, "NE": 291, "NF": 291,
        "NG": 291, "NH": 291, "NI": 291, "NJ": 291, "NK": 291, "NL": 291,
        "NM": 291, "NN": 291, "NO": 291, "NP": 291, "NQ": 291, "NR": 291,
        "NS": 291, "NT": 291, "NU": 291, "NV": 291, "NW": 291, "NX": 291,
        "NY": 291, "NZ": 291,
        "WA": 291, "WB": 291, "WC": 291, "WD": 291, "WE": 291, "WF": 291,
        "WG": 291, "WH": 291, "WI": 291, "WJ": 291, "WK": 291, "WL": 291,
        "WM": 291, "WN": 291, "WO": 291, "WP": 291, "WQ": 291, "WR": 291,
        "WS": 291, "WT": 291, "WU": 291, "WV": 291, "WW": 291, "WX": 291,
        "WY": 291, "WZ": 291,

        // Canada (1)
        "VE": 1, "VA": 1, "VY": 1, "VO": 1, "CY": 1, "CZ": 1,
        "CF": 1, "CG": 1, "CI": 1, "CJ": 1, "CK": 1,

        // England (223)
        "G": 223, "M": 223, "2E": 223, "2D": 223, "2M": 223,

        // Scotland (279)
        "GM": 279, "MM": 279, "2M0": 279,

        // Wales (294)
        "GW": 294, "MW": 294,

        // Northern Ireland (265)
        "GI": 265, "MI": 265,

        // Japan (339)
        "JA": 339, "JB": 339, "JC": 339, "JD": 339, "JE": 339, "JF": 339,
        "JG": 339, "JH": 339, "JI": 339, "JJ": 339, "JK": 339, "JL": 339,
        "JM": 339, "JN": 339, "JO": 339, "JP": 339, "JQ": 339, "JR": 339,
        "JS": 339, "7J": 339, "7K": 339, "7L": 339, "7M": 339, "7N": 339,

        // Germany (230)
        "DA": 230, "DB": 230, "DC": 230, "DD": 230, "DE": 230, "DF": 230,
        "DG": 230, "DH": 230, "DI": 230, "DJ": 230, "DK": 230, "DL": 230,
        "DM": 230, "DN": 230, "DO": 230, "DP": 230, "DQ": 230, "DR": 230,

        // France (227)
        "F": 227,

        // Italy (248)
        "I": 248, "IK": 248, "IZ": 248, "IW": 248, "IU": 248,

        // Spain (281)
        "EA": 281, "EB": 281, "EC": 281, "ED": 281, "EE": 281, "EF": 281,
        "EG": 281, "EH": 281,

        // Portugal (272)
        "CT": 272, "CS": 272,

        // Netherlands (263)
        "PA": 263, "PB": 263, "PC": 263, "PD": 263, "PE": 263, "PF": 263,
        "PG": 263, "PH": 263, "PI": 263,

        // Belgium (209)
        "ON": 209, "OO": 209, "OP": 209, "OQ": 209, "OR": 209, "OS": 209, "OT": 209,

        // Switzerland (287)
        "HB": 287, "HE": 287,

        // Austria (206)
        "OE": 206,

        // Sweden (284)
        "SA": 284, "SB": 284, "SC": 284, "SD": 284, "SE": 284, "SF": 284,
        "SG": 284, "SH": 284, "SI": 284, "SJ": 284, "SK": 284, "SL": 284, "SM": 284,

        // Norway (266)
        "LA": 266, "LB": 266, "LC": 266, "LD": 266, "LE": 266, "LF": 266,
        "LG": 266, "LH": 266, "LI": 266, "LJ": 266, "LK": 266, "LL": 266,
        "LM": 266, "LN": 266,

        // Denmark (222)
        "OU": 222, "OV": 222, "OW": 222, "OX": 222, "OY": 222, "OZ": 222,

        // Finland (224)
        "OF": 224, "OG": 224, "OH": 224, "OI": 224,

        // Aland Islands (5)
        "OH0": 5,

        // Russia (54)
        "R": 54, "RA": 54, "RB": 54, "RC": 54, "RD": 54, "RE": 54, "RF": 54,
        "RG": 54, "RJ": 54, "RK": 54, "RL": 54, "RM": 54, "RN": 54, "RO": 54,
        "RQ": 54, "RT": 54, "RU": 54, "RV": 54, "RW": 54, "RX": 54, "RY": 54, "RZ": 54,
        "UA": 54, "UB": 54, "UC": 54, "UD": 54, "UE": 54, "UF": 54, "UG": 54,
        "UH": 54, "UI": 54,

        // Ukraine (288)
        "UR": 288, "US": 288, "UT": 288, "UU": 288, "UV": 288, "UW": 288,
        "UX": 288, "UY": 288, "UZ": 288,

        // Poland (269)
        "SP": 269, "SQ": 269, "SR": 269, "SN": 269, "SO": 269, "3Z": 269,

        // Czech Republic (503)
        "OK": 503, "OL": 503,

        // Hungary (239)
        "HA": 239, "HG": 239,

        // Romania (275)
        "YO": 275, "YP": 275, "YQ": 275, "YR": 275,

        // Bulgaria (212)
        "LZ": 212,

        // Greece (236)
        "SV": 236, "SW": 236, "SX": 236, "SY": 236, "SZ": 236,

        // Turkey (390)
        "TA": 390, "TB": 390, "TC": 390, "YM": 390,

        // Australia (150)
        "VK": 150, "AX": 150,

        // New Zealand (170)
        "ZL": 170, "ZM": 170,

        // Brazil (108)
        "PP": 108, "PQ": 108, "PR": 108, "PS": 108, "PT": 108, "PU": 108,
        "PV": 108, "PW": 108, "PX": 108, "PY": 108, "ZV": 108, "ZW": 108,
        "ZX": 108, "ZY": 108, "ZZ": 108,

        // Argentina (100)
        "AY": 100, "AZ": 100, "L": 100, "LO": 100, "LP": 100, "LQ": 100,
        "LR": 100, "LS": 100, "LT": 100, "LU": 100, "LV": 100, "LW": 100,

        // Mexico (50)
        "XA": 50, "XB": 50, "XC": 50, "XD": 50, "XE": 50, "XF": 50,
        "4A": 50, "4B": 50, "4C": 50,

        // South Africa (462)
        "ZR": 462, "ZS": 462, "ZT": 462, "ZU": 462,

        // India (324)
        "AT": 324, "AU": 324, "AV": 324, "AW": 324, "VU": 324,

        // China (318)
        "BA": 318, "BD": 318, "BG": 318, "BH": 318, "BI": 318, "BJ": 318,
        "BL": 318, "BM": 318, "BN": 318, "BO": 318, "BP": 318, "BQ": 318,
        "BR": 318, "BS": 318, "BT": 318, "BU": 318, "BV": 318, "BW": 318,
        "BX": 318, "BY": 318, "BZ": 318,

        // South Korea (137)
        "DS": 137, "DT": 137, "HL": 137, "6K": 137, "6L": 137, "6M": 137, "6N": 137,

        // Thailand (387)
        "HS": 387, "E2": 387,

        // Indonesia (327)
        "YB": 327, "YC": 327, "YD": 327, "YE": 327, "YF": 327, "YG": 327, "YH": 327,

        // Philippines (375)
        "DU": 375, "DV": 375, "DW": 375, "DX": 375, "DY": 375, "DZ": 375, "4D": 375,
        "4E": 375, "4F": 375, "4G": 375, "4H": 375, "4I": 375,

        // Israel (336)
        "4X": 336, "4Z": 336,

        // Hawaii (110)
        "KH6": 110, "WH6": 110, "NH6": 110, "AH6": 110,

        // Alaska (6)
        "KL7": 6, "WL7": 6, "NL7": 6, "AL7": 6,

        // Puerto Rico (202)
        "KP3": 202, "KP4": 202, "WP3": 202, "WP4": 202, "NP3": 202, "NP4": 202,

        // US Virgin Islands (285)
        "KP2": 285, "WP2": 285, "NP2": 285,

        // Bermuda (64)
        "VP9": 64,

        // Montserrat (96)
        "VP2M": 96,

        // Anguilla (12)
        "VP2E": 12,

        // British Virgin Islands (65)
        "VP2V": 65,

        // Cayman Islands (69)
        "ZF": 69,

        // Bahamas (60)
        "C6": 60,

        // Jamaica (82)
        "6Y": 82,

        // Barbados (62)
        "8P": 62,

        // Trinidad & Tobago (90)
        "9Y": 90, "9Z": 90,

        // Cuba (70)
        "CL": 70, "CM": 70, "CO": 70, "T4": 70,

        // Dominican Republic (72)
        "HI": 72,

        // Haiti (78)
        "HH": 78,

        // Curacao (517)
        "PJ2": 517,

        // Aruba (91)
        "P4": 91,

        // Ireland (245)
        "EI": 245, "EJ": 245,

        // Iceland (242)
        "TF": 242,

        // Luxembourg (254)
        "LX": 254,

        // Croatia (497)
        "9A": 497,

        // Slovenia (499)
        "S5": 499,

        // Serbia (296)
        "YU": 296, "YT": 296,

        // Malta (257)
        "9H": 257,

        // Cyprus (215)
        "5B": 215, "C4": 215, "H2": 215, "P3": 215,
    ]
}
