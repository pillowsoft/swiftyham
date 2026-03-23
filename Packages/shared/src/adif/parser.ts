/**
 * ADIF 3.1 Parser — TypeScript port of HamStationKit/Sources/ADIF/ADIFParser.swift
 * Streaming parser with strict and lenient modes.
 */

export interface ADIFField {
  name: string;
  value: string;
  type?: string;
}

export interface ADIFRecord {
  fields: Map<string, ADIFField>;
  /** Get field value by name (case-insensitive). */
  get(name: string): string | undefined;
  /** Check if field exists. */
  has(name: string): boolean;
}

export function createRecord(fields: ADIFField[]): ADIFRecord {
  const map = new Map<string, ADIFField>();
  for (const f of fields) {
    map.set(f.name.toUpperCase(), f);
  }
  return {
    fields: map,
    get(name: string) { return map.get(name.toUpperCase())?.value; },
    has(name: string) { return map.has(name.toUpperCase()); },
  };
}

export type ParseMode = 'lenient' | 'strict';

export interface ParseWarning {
  line?: number;
  message: string;
}

export interface ParseError {
  line?: number;
  message: string;
}

export interface ParseResult {
  header?: ADIFRecord;
  records: ADIFRecord[];
  warnings: ParseWarning[];
  errors: ParseError[];
}

/**
 * Parse an ADIF string into a complete result.
 */
export function parseADIF(input: string, mode: ParseMode = 'lenient'): ParseResult {
  const result: ParseResult = { records: [], warnings: [], errors: [] };
  let currentFields: ADIFField[] = [];
  let inHeader = true;
  let lineNumber = 1;
  let pos = 0;

  while (pos < input.length) {
    // Skip to next '<'
    while (pos < input.length && input[pos] !== '<') {
      if (input[pos] === '\n') lineNumber++;
      pos++;
    }
    if (pos >= input.length) break;

    // We're at '<' — find the closing '>'
    const tagStart = pos;
    pos++; // skip '<'
    const closePos = input.indexOf('>', pos);
    if (closePos === -1) {
      // Unterminated tag
      if (mode === 'strict') {
        result.errors.push({ line: lineNumber, message: 'Unterminated tag' });
        break;
      }
      result.warnings.push({ line: lineNumber, message: 'Unterminated tag at end of file' });
      break;
    }

    const tagContent = input.substring(pos, closePos);
    pos = closePos + 1;

    // Count newlines in tag
    for (const ch of tagContent) {
      if (ch === '\n') lineNumber++;
    }

    // Check for EOH (end of header)
    if (tagContent.toUpperCase() === 'EOH') {
      if (currentFields.length > 0) {
        result.header = createRecord(currentFields);
      }
      currentFields = [];
      inHeader = false;
      continue;
    }

    // Check for EOR (end of record)
    if (tagContent.toUpperCase() === 'EOR') {
      if (currentFields.length > 0) {
        result.records.push(createRecord(currentFields));
      }
      currentFields = [];
      inHeader = false;
      continue;
    }

    // Parse field tag: NAME:LENGTH or NAME:LENGTH:TYPE
    const parts = tagContent.split(':');
    if (parts.length < 2) {
      if (mode === 'strict') {
        result.errors.push({ line: lineNumber, message: `Malformed tag: <${tagContent}>` });
        break;
      }
      result.warnings.push({ line: lineNumber, message: `Skipping malformed tag: <${tagContent}>` });
      continue;
    }

    const fieldName = parts[0].trim().toUpperCase();
    const fieldLength = parseInt(parts[1].trim(), 10);
    const fieldType = parts[2]?.trim();

    if (isNaN(fieldLength) || fieldLength < 0) {
      if (mode === 'strict') {
        result.errors.push({ line: lineNumber, message: `Invalid field length in <${tagContent}>` });
        break;
      }
      result.warnings.push({ line: lineNumber, message: `Skipping tag with invalid length: <${tagContent}>` });
      continue;
    }

    // Extract field value (next fieldLength characters)
    if (pos + fieldLength > input.length) {
      if (mode === 'strict') {
        result.errors.push({ line: lineNumber, message: `Field ${fieldName} extends past end of file` });
        break;
      }
      // In lenient mode, take what we can
      const value = input.substring(pos);
      currentFields.push({ name: fieldName, value, type: fieldType });
      pos = input.length;
      continue;
    }

    const value = input.substring(pos, pos + fieldLength);
    pos += fieldLength;

    // Count newlines in value
    for (const ch of value) {
      if (ch === '\n') lineNumber++;
    }

    currentFields.push({ name: fieldName, value, type: fieldType });
  }

  // Handle trailing fields without EOR
  if (currentFields.length > 0 && !inHeader) {
    result.warnings.push({ message: 'File ended without final <EOR> — saving last record' });
    result.records.push(createRecord(currentFields));
  }

  return result;
}

/**
 * Export records to ADIF format.
 */
export function exportADIF(records: ADIFRecord[], options?: {
  includeHeader?: boolean;
  programId?: string;
  programVersion?: string;
}): string {
  const lines: string[] = [];
  const opts = { includeHeader: true, programId: 'HamStation Pro Web', programVersion: '0.1.0', ...options };

  if (opts.includeHeader) {
    lines.push(`Generated by ${opts.programId} v${opts.programVersion}`);
    lines.push(`<ADIF_VER:5>3.1.4`);
    lines.push(`<PROGRAMID:${opts.programId.length}>${opts.programId}`);
    lines.push(`<PROGRAMVERSION:${opts.programVersion.length}>${opts.programVersion}`);
    lines.push('<EOH>');
    lines.push('');
  }

  for (const record of records) {
    const fieldStrings: string[] = [];
    for (const [, field] of record.fields) {
      const tag = field.type
        ? `<${field.name}:${field.value.length}:${field.type}>`
        : `<${field.name}:${field.value.length}>`;
      fieldStrings.push(`${tag}${field.value}`);
    }
    fieldStrings.push('<EOR>');
    lines.push(fieldStrings.join(' '));
  }

  return lines.join('\r\n') + '\r\n';
}
