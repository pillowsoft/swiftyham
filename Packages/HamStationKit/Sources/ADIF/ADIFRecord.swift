// ADIFRecord.swift
// HamStationKit — ADIF 3.1 Parser & Exporter
//
// A collection of ADIF fields representing one QSO or the file header.

import Foundation

/// Represents one ADIF record — either a QSO (terminated by `<EOR>`) or the
/// file header (terminated by `<EOH>`).
///
/// Fields are stored in a dictionary keyed by uppercase field name. When
/// duplicate field names occur in the same record the last value wins.
public struct ADIFRecord: Sendable, Equatable {

    /// Fields keyed by uppercase name.
    public private(set) var fields: [String: ADIFField]

    /// Creates an empty record.
    public init() {
        self.fields = [:]
    }

    /// Creates a record from an array of fields.
    /// If duplicate names exist the last field wins.
    public init(fields: [ADIFField]) {
        var dict: [String: ADIFField] = [:]
        dict.reserveCapacity(fields.count)
        for field in fields {
            dict[field.name] = field
        }
        self.fields = dict
    }

    /// Creates a record from a dictionary of fields.
    public init(fields: [String: ADIFField]) {
        self.fields = fields
    }

    // MARK: - Subscript

    /// Access a field value by name (case-insensitive). Returns `nil` if the
    /// field is not present.
    public subscript(fieldName: String) -> String? {
        fields[fieldName.uppercased()]?.value
    }

    // MARK: - Query

    /// Returns `true` if the record contains a field with the given name
    /// (case-insensitive).
    public func hasField(_ name: String) -> Bool {
        fields[name.uppercased()] != nil
    }

    /// All field names present in this record, sorted alphabetically.
    public var allFieldNames: [String] {
        fields.keys.sorted()
    }

    /// The full `ADIFField` for a given name, or `nil`.
    public func field(named name: String) -> ADIFField? {
        fields[name.uppercased()]
    }

    // MARK: - Mutation

    /// Sets (or replaces) a field in the record.
    public mutating func setField(_ field: ADIFField) {
        fields[field.name] = field
    }

    /// Sets a simple string field (no type indicator).
    public mutating func setField(name: String, value: String) {
        let field = ADIFField(name: name, value: value)
        fields[field.name] = field
    }

    /// Removes a field by name (case-insensitive).
    @discardableResult
    public mutating func removeField(named name: String) -> ADIFField? {
        fields.removeValue(forKey: name.uppercased())
    }

    /// Whether this record contains no fields.
    public var isEmpty: Bool {
        fields.isEmpty
    }

    /// Number of fields in this record.
    public var fieldCount: Int {
        fields.count
    }
}

extension ADIFRecord: CustomStringConvertible {
    public var description: String {
        let fieldStrings = allFieldNames.compactMap { fields[$0]?.description }
        return fieldStrings.joined(separator: " ") + " <EOR>"
    }
}
