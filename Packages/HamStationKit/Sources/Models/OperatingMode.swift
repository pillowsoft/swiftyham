import Foundation

/// Amateur radio operating modes.
public enum OperatingMode: String, CaseIterable, Codable, Sendable {
    case ssb = "SSB"
    case lsb = "LSB"
    case usb = "USB"
    case am = "AM"
    case fm = "FM"
    case cw = "CW"
    case rtty = "RTTY"
    case psk31 = "PSK31"
    case psk63 = "PSK63"
    case ft8 = "FT8"
    case ft4 = "FT4"
    case js8 = "JS8"
    case wspr = "WSPR"
    case jt65 = "JT65"
    case jt9 = "JT9"
    case sstv = "SSTV"
    case fax = "FAX"
    case olivia = "OLIVIA"
    case contestia = "CONTESTIA"
    case thor = "THOR"
    case dstar = "DSTAR"
    case dmr = "DMR"
    case c4fm = "C4FM"
    case p25 = "P25"
    case sat = "SAT"

    /// Whether this mode is a digital mode.
    public var isDigital: Bool {
        switch self {
        case .ssb, .lsb, .usb, .am, .fm:
            return false
        case .cw, .rtty, .psk31, .psk63, .ft8, .ft4, .js8, .wspr,
             .jt65, .jt9, .sstv, .fax, .olivia, .contestia, .thor,
             .dstar, .dmr, .c4fm, .p25, .sat:
            return true
        }
    }

    /// Default RST report for this mode.
    /// CW and digital modes use 599; phone modes use 59.
    public var defaultRST: String {
        switch self {
        case .ssb, .lsb, .usb, .am, .fm:
            return "59"
        case .cw, .rtty, .psk31, .psk63, .ft8, .ft4, .js8, .wspr,
             .jt65, .jt9, .sstv, .fax, .olivia, .contestia, .thor,
             .dstar, .dmr, .c4fm, .p25, .sat:
            return "599"
        }
    }
}
