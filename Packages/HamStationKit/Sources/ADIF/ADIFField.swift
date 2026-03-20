// ADIFField.swift
// HamStationKit — ADIF 3.1 Parser & Exporter
//
// A single parsed ADIF field with name, value, and optional type indicator.

import Foundation

/// Represents a single ADIF field such as `<CALL:4:S>W1AW`.
///
/// - `name` is always stored UPPERCASE (ADIF field names are case-insensitive).
/// - `value` is the raw string content extracted using the declared length.
/// - `typeIndicator` is the optional ADIF data-type character (e.g. "S", "D", "N", "B", "L", "E", "T", "M").
public struct ADIFField: Sendable, Equatable, Hashable {

    /// The uppercase field name (e.g. "CALL", "BAND", "APP_HAMRD_QSO_ID").
    public let name: String

    /// The field's string value, extracted according to the declared length.
    public let value: String

    /// Optional ADIF type indicator (e.g. "S" for string, "D" for date, "N" for number).
    public let typeIndicator: String?

    /// Creates an ADIF field.
    ///
    /// - Parameters:
    ///   - name: Field name (will be uppercased).
    ///   - value: The field value string.
    ///   - typeIndicator: Optional ADIF type indicator character.
    public init(name: String, value: String, typeIndicator: String? = nil) {
        self.name = name.uppercased()
        self.value = value
        self.typeIndicator = typeIndicator
    }
}

extension ADIFField: CustomStringConvertible {
    public var description: String {
        if let type = typeIndicator {
            return "<\(name):\(value.count):\(type)>\(value)"
        }
        return "<\(name):\(value.count)>\(value)"
    }
}
