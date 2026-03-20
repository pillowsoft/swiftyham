// ADIFParser.swift
// HamStationKit — ADIF 3.1 Parser & Exporter
//
// Streaming ADIF 3.1 parser with strict and lenient modes.

import Foundation

/// Streaming parser for ADIF (Amateur Data Interchange Format) 3.1 files.
///
/// Supports two modes:
/// - **lenient** (default): Skip malformed fields/records with warnings, continue parsing.
/// - **strict**: Stop on first malformed field and report an error.
///
/// The parser handles all common ADIF variations: optional headers, mixed line
/// endings (CR, LF, CRLF), preamble text, APP_ custom fields, and type indicators.
public enum ADIFParser: Sendable {

    // MARK: - Types

    /// Controls how the parser handles malformed data.
    public enum Mode: Sendable {
        /// Skip malformed fields with a warning and continue.
        case lenient
        /// Stop parsing on the first malformed field.
        case strict
    }

    /// The complete result of parsing an ADIF string or file.
    public struct ParseResult: Sendable {
        /// The file header record (fields before `<EOH>`), if present.
        public var header: ADIFRecord?
        /// All QSO records parsed (one per `<EOR>`).
        public var records: [ADIFRecord]
        /// Non-fatal issues encountered during parsing.
        public var warnings: [ParseWarning]
        /// Fatal issues encountered during parsing (in strict mode).
        public var errors: [ParseError]

        public init(
            header: ADIFRecord? = nil,
            records: [ADIFRecord] = [],
            warnings: [ParseWarning] = [],
            errors: [ParseError] = []
        ) {
            self.header = header
            self.records = records
            self.warnings = warnings
            self.errors = errors
        }
    }

    /// A non-fatal parsing issue.
    public struct ParseWarning: Sendable, Equatable, CustomStringConvertible {
        /// Approximate line number where the warning occurred, if known.
        public var line: Int?
        /// Human-readable description of the issue.
        public var message: String

        public init(line: Int? = nil, message: String) {
            self.line = line
            self.message = message
        }

        public var description: String {
            if let line {
                return "Line \(line): \(message)"
            }
            return message
        }
    }

    /// A fatal parsing issue.
    public struct ParseError: Error, Sendable, Equatable, CustomStringConvertible {
        /// Approximate line number where the error occurred, if known.
        public var line: Int?
        /// Human-readable description of the issue.
        public var message: String

        public init(line: Int? = nil, message: String) {
            self.line = line
            self.message = message
        }

        public var description: String {
            if let line {
                return "Line \(line): \(message)"
            }
            return message
        }
    }

    // MARK: - Public API

    /// Parses an ADIF string into a complete result.
    ///
    /// - Parameters:
    ///   - string: The ADIF content to parse.
    ///   - mode: Parsing mode (default: `.lenient`).
    /// - Returns: A `ParseResult` with header, records, warnings, and errors.
    public static func parse(string: String, mode: Mode = .lenient) -> ParseResult {
        var state = ParserState(mode: mode)
        state.parse(string)
        return state.result
    }

    /// Parses an ADIF file at the given URL.
    ///
    /// - Parameters:
    ///   - url: File URL to read.
    ///   - mode: Parsing mode (default: `.lenient`).
    /// - Returns: A `ParseResult` with header, records, warnings, and errors.
    /// - Throws: If the file cannot be read.
    public static func parse(url: URL, mode: Mode = .lenient) throws -> ParseResult {
        let data = try Data(contentsOf: url)
        guard let string = String(data: data, encoding: .utf8)
                ?? String(data: data, encoding: .ascii)
                ?? String(data: data, encoding: .isoLatin1) else {
            return ParseResult(errors: [ParseError(message: "Unable to decode file as text")])
        }
        return parse(string: string, mode: mode)
    }

    /// Returns an `AsyncThrowingStream` that yields one `ADIFRecord` at a time.
    ///
    /// The header (if present) is yielded first as a record whose field
    /// `ADIF_VER` is typically set. Subsequent records are QSOs.
    ///
    /// - Parameters:
    ///   - url: File URL to stream from.
    ///   - mode: Parsing mode (default: `.lenient`).
    /// - Returns: An async stream of records.
    public static func parseStream(
        url: URL,
        mode: Mode = .lenient
    ) -> AsyncThrowingStream<ADIFRecord, Error> {
        AsyncThrowingStream { continuation in
            do {
                let data = try Data(contentsOf: url)
                guard let string = String(data: data, encoding: .utf8)
                        ?? String(data: data, encoding: .ascii)
                        ?? String(data: data, encoding: .isoLatin1) else {
                    continuation.finish(throwing: ParseError(message: "Unable to decode file as text"))
                    return
                }

                var state = StreamingParserState(mode: mode, continuation: continuation)
                state.parse(string)
                continuation.finish()
            } catch {
                continuation.finish(throwing: error)
            }
        }
    }
}

// MARK: - Internal Parser State Machine

/// Core parser logic shared between batch and streaming modes.
private struct ParserState {
    let mode: ADIFParser.Mode
    var result = ADIFParser.ParseResult()

    // Current parsing context
    private var currentFields: [ADIFField] = []
    private var inHeader = true // Start assuming we might have a header
    private var foundFirstTag = false
    private var lineNumber = 1

    init(mode: ADIFParser.Mode) {
        self.mode = mode
    }

    mutating func parse(_ input: String) {
        let scanner = ADIFScanner(input)
        var idx = scanner.startIndex

        while idx < scanner.endIndex {
            // Skip to next '<'
            let skipped = scanner.skipToNextTag(from: idx)
            lineNumber += skipped.newlines
            idx = skipped.position

            guard idx < scanner.endIndex else { break }

            // We're at '<' — try to parse a tag
            let tagResult = scanner.parseTag(from: idx, lineNumber: lineNumber)

            switch tagResult {
            case .endOfHeader(let advance, let newlines):
                lineNumber += newlines
                idx = advance
                // Finalize header
                if !currentFields.isEmpty {
                    result.header = ADIFRecord(fields: currentFields)
                }
                currentFields = []
                inHeader = false
                foundFirstTag = true

            case .endOfRecord(let advance, let newlines):
                lineNumber += newlines
                idx = advance
                // Finalize record
                if !currentFields.isEmpty {
                    result.records.append(ADIFRecord(fields: currentFields))
                }
                // Empty records (no fields) are silently skipped
                currentFields = []
                inHeader = false
                foundFirstTag = true

            case .field(let field, let advance, let newlines):
                lineNumber += newlines
                idx = advance
                foundFirstTag = true
                currentFields.append(field)

            case .warning(let message, let advance, let newlines):
                lineNumber += newlines
                idx = advance
                result.warnings.append(ADIFParser.ParseWarning(line: lineNumber, message: message))
                if mode == .strict {
                    result.errors.append(ADIFParser.ParseError(line: lineNumber, message: message))
                    return
                }

            case .error(let message, let advance, let newlines):
                lineNumber += newlines
                idx = advance
                result.errors.append(ADIFParser.ParseError(line: lineNumber, message: message))
                if mode == .strict {
                    return
                }
                // In lenient mode, treat as warning and continue
                result.warnings.append(ADIFParser.ParseWarning(line: lineNumber, message: message))
            }
        }

        // If we never saw <EOH> and we have fields, they're header-less records
        // Actually: if we never saw <EOH>, there is no header.
        // Any remaining fields form a partial record (no <EOR>) — emit warning.
        if !currentFields.isEmpty {
            if inHeader && !result.records.isEmpty {
                // Shouldn't happen but be safe
                result.warnings.append(ADIFParser.ParseWarning(
                    line: lineNumber,
                    message: "Trailing fields after last <EOR> were ignored"
                ))
            } else if inHeader {
                // We never saw <EOH> — these fields might be a record without proper termination
                // In lenient mode, try to save them as a record
                result.warnings.append(ADIFParser.ParseWarning(
                    line: lineNumber,
                    message: "Record at end of file has no <EOR> terminator"
                ))
                if currentFields.contains(where: { $0.name == "CALL" }) {
                    result.records.append(ADIFRecord(fields: currentFields))
                }
            }
        }
    }
}

/// Streaming variant that yields records through a continuation.
private struct StreamingParserState {
    let mode: ADIFParser.Mode
    let continuation: AsyncThrowingStream<ADIFRecord, Error>.Continuation

    private var currentFields: [ADIFField] = []
    private var inHeader = true
    private var lineNumber = 1

    init(mode: ADIFParser.Mode, continuation: AsyncThrowingStream<ADIFRecord, Error>.Continuation) {
        self.mode = mode
        self.continuation = continuation
    }

    mutating func parse(_ input: String) {
        let scanner = ADIFScanner(input)
        var idx = scanner.startIndex

        while idx < scanner.endIndex {
            let skipped = scanner.skipToNextTag(from: idx)
            lineNumber += skipped.newlines
            idx = skipped.position

            guard idx < scanner.endIndex else { break }

            let tagResult = scanner.parseTag(from: idx, lineNumber: lineNumber)

            switch tagResult {
            case .endOfHeader(let advance, let newlines):
                lineNumber += newlines
                idx = advance
                if !currentFields.isEmpty {
                    continuation.yield(ADIFRecord(fields: currentFields))
                }
                currentFields = []
                inHeader = false

            case .endOfRecord(let advance, let newlines):
                lineNumber += newlines
                idx = advance
                if !currentFields.isEmpty {
                    continuation.yield(ADIFRecord(fields: currentFields))
                }
                currentFields = []
                inHeader = false

            case .field(let field, let advance, let newlines):
                lineNumber += newlines
                idx = advance
                currentFields.append(field)

            case .warning(_, let advance, let newlines):
                lineNumber += newlines
                idx = advance
                if mode == .strict {
                    continuation.finish(throwing: ADIFParser.ParseError(
                        line: lineNumber,
                        message: "Strict mode: parse error"
                    ))
                    return
                }

            case .error(let message, let advance, let newlines):
                lineNumber += newlines
                idx = advance
                if mode == .strict {
                    continuation.finish(throwing: ADIFParser.ParseError(
                        line: lineNumber,
                        message: message
                    ))
                    return
                }
            }
        }
    }
}

// MARK: - Low-level Scanner

/// A zero-copy scanner over the ADIF string.
private struct ADIFScanner {
    let source: String
    let startIndex: String.Index
    let endIndex: String.Index

    init(_ source: String) {
        self.source = source
        self.startIndex = source.startIndex
        self.endIndex = source.endIndex
    }

    /// Result of attempting to parse a single tag starting at `<`.
    enum TagResult {
        case endOfHeader(advance: String.Index, newlines: Int)
        case endOfRecord(advance: String.Index, newlines: Int)
        case field(ADIFField, advance: String.Index, newlines: Int)
        case warning(String, advance: String.Index, newlines: Int)
        case error(String, advance: String.Index, newlines: Int)
    }

    /// Advances from `position` to the next `<`, counting newlines along the way.
    func skipToNextTag(from position: String.Index) -> (position: String.Index, newlines: Int) {
        var idx = position
        var newlines = 0
        while idx < endIndex {
            let ch = source[idx]
            if ch == "<" {
                return (idx, newlines)
            }
            if ch == "\n" {
                newlines += 1
            } else if ch == "\r" {
                newlines += 1
                let next = source.index(after: idx)
                if next < endIndex && source[next] == "\n" {
                    // CRLF — count as one newline, skip the LF
                    idx = next
                }
            }
            idx = source.index(after: idx)
        }
        return (endIndex, newlines)
    }

    /// Parses a tag starting at `<` at the given position.
    ///
    /// ADIF tags have the form:
    /// - `<EOH>` — end of header
    /// - `<EOR>` — end of record
    /// - `<NAME:LENGTH>` — field with data
    /// - `<NAME:LENGTH:TYPE>` — field with data and type indicator
    func parseTag(from position: String.Index, lineNumber: Int) -> TagResult {
        precondition(source[position] == "<")

        // Find closing '>'
        var idx = source.index(after: position)
        var newlines = 0
        var closingIdx: String.Index?

        while idx < endIndex {
            let ch = source[idx]
            if ch == ">" {
                closingIdx = idx
                break
            }
            if ch == "\n" { newlines += 1 }
            else if ch == "\r" {
                newlines += 1
                let next = source.index(after: idx)
                if next < endIndex && source[next] == "\n" {
                    idx = next
                }
            }
            // Detect nested '<' — malformed
            if ch == "<" {
                return .warning(
                    "Unexpected '<' inside tag starting near line \(lineNumber)",
                    advance: idx, // restart at this new '<'
                    newlines: newlines
                )
            }
            idx = source.index(after: idx)
        }

        guard let closeIdx = closingIdx else {
            // No closing '>' found — unclosed tag
            return .warning(
                "Unclosed tag starting near line \(lineNumber)",
                advance: endIndex,
                newlines: newlines
            )
        }

        let afterClose = source.index(after: closeIdx)
        let tagContent = String(source[source.index(after: position)..<closeIdx])

        // Check for EOH / EOR (case-insensitive)
        let tagUpper = tagContent.uppercased().trimmingCharacters(in: .whitespaces)
        if tagUpper == "EOH" {
            return .endOfHeader(advance: afterClose, newlines: newlines)
        }
        if tagUpper == "EOR" {
            return .endOfRecord(advance: afterClose, newlines: newlines)
        }

        // Parse field tag: NAME:LENGTH or NAME:LENGTH:TYPE
        let parts = tagContent.split(separator: ":", maxSplits: 3)

        guard !parts.isEmpty else {
            return .warning(
                "Empty tag at line \(lineNumber)",
                advance: afterClose,
                newlines: newlines
            )
        }

        let fieldName = String(parts[0]).trimmingCharacters(in: .whitespaces).uppercased()

        // Validate field name is not empty
        guard !fieldName.isEmpty else {
            return .warning(
                "Empty field name at line \(lineNumber)",
                advance: afterClose,
                newlines: newlines
            )
        }

        // Must have a length part
        guard parts.count >= 2 else {
            return .warning(
                "Field '\(fieldName)' has no length specifier at line \(lineNumber)",
                advance: afterClose,
                newlines: newlines
            )
        }

        let lengthStr = String(parts[1]).trimmingCharacters(in: .whitespaces)
        guard let length = Int(lengthStr) else {
            return .warning(
                "Field '\(fieldName)' has non-numeric length '\(lengthStr)' at line \(lineNumber)",
                advance: afterClose,
                newlines: newlines
            )
        }

        guard length >= 0 else {
            return .warning(
                "Field '\(fieldName)' has negative length \(length) at line \(lineNumber)",
                advance: afterClose,
                newlines: newlines
            )
        }

        // Optional type indicator
        let typeIndicator: String?
        if parts.count >= 3 {
            typeIndicator = String(parts[2]).trimmingCharacters(in: .whitespaces)
        } else {
            typeIndicator = nil
        }

        // Extract the data portion (length characters after '>')
        var dataNewlines = 0
        if length == 0 {
            let field = ADIFField(name: fieldName, value: "", typeIndicator: typeIndicator)
            return .field(field, advance: afterClose, newlines: newlines)
        }

        // Read `length` characters of data
        var dataEnd = afterClose
        var charsRead = 0
        while dataEnd < endIndex && charsRead < length {
            let ch = source[dataEnd]
            if ch == "\n" {
                dataNewlines += 1
            } else if ch == "\r" {
                dataNewlines += 1
                // Don't double-count CRLF for data reading but do count the char
            }
            dataEnd = source.index(after: dataEnd)
            charsRead += 1
        }

        let dataValue: String
        if charsRead < length {
            // Data shorter than declared length
            dataValue = String(source[afterClose..<dataEnd])
        } else {
            dataValue = String(source[afterClose..<dataEnd])
        }

        let field = ADIFField(name: fieldName, value: dataValue, typeIndicator: typeIndicator)
        return .field(field, advance: dataEnd, newlines: newlines + dataNewlines)
    }
}
