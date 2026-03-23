/**
 * Natural language QSO parser.
 * Port of HamStationKit/Sources/AI/NaturalLanguageLogger.swift
 * Parses freeform text like "Worked JA1ABC on 20m FT8, -10 both ways"
 * into structured QSO fields.
 */

export interface ParsedQSO {
  callsign?: string;
  band?: string;
  mode?: string;
  rstSent?: string;
  rstReceived?: string;
  frequency?: number; // Hz
  confidence: number; // 0-1
}

const BAND_NAMES: [string, string][] = [
  ['ONE SIXTY', '160m'], ['ONE HUNDRED SIXTY', '160m'], ['160 METER', '160m'], ['160M', '160m'],
  ['EIGHTY', '80m'], ['80 METER', '80m'], ['80M', '80m'],
  ['FORTY', '40m'], ['40 METER', '40m'], ['40M', '40m'],
  ['THIRTY', '30m'], ['30 METER', '30m'], ['30M', '30m'],
  ['TWENTY', '20m'], ['20 METER', '20m'], ['20M', '20m'],
  ['SEVENTEEN', '17m'], ['17 METER', '17m'], ['17M', '17m'],
  ['FIFTEEN', '15m'], ['15 METER', '15m'], ['15M', '15m'],
  ['TWELVE', '12m'], ['12 METER', '12m'], ['12M', '12m'],
  ['TEN METER', '10m'], ['10 METER', '10m'], ['10M', '10m'],
  ['SIX METER', '6m'], ['6 METER', '6m'], ['6M', '6m'],
  ['TWO METER', '2m'], ['2 METER', '2m'], ['2M', '2m'],
];

const BAND_NUMBERS: Record<string, string> = {
  '160': '160m', '80': '80m', '60': '60m', '40': '40m', '30': '30m',
  '20': '20m', '17': '17m', '15': '15m', '12': '12m', '10': '10m',
  '6': '6m', '2': '2m',
};

const MODE_KEYWORDS: [string, string][] = [
  ['FT8', 'FT8'], ['FT4', 'FT4'], ['JS8', 'JS8'], ['JT65', 'JT65'], ['JT9', 'JT9'],
  ['WSPR', 'WSPR'], ['PSK31', 'PSK31'], ['PSK63', 'PSK63'], ['RTTY', 'RTTY'],
  ['OLIVIA', 'OLIVIA'], ['SSTV', 'SSTV'], ['DSTAR', 'DSTAR'], ['DMR', 'DMR'],
  ['C4FM', 'C4FM'], ['SSB', 'SSB'], ['USB', 'USB'], ['LSB', 'LSB'],
  ['AM', 'AM'], ['FM', 'FM'], ['CW', 'CW'], ['PHONE', 'SSB'], ['DIGITAL', 'FT8'],
];

/**
 * Parse natural language text into structured QSO fields.
 */
export function parseNaturalLanguage(input: string): ParsedQSO {
  if (!input.trim()) return { confidence: 0 };

  const upper = input.toUpperCase();
  let fieldsFound = 0;

  const callsign = extractCallsign(upper);
  if (callsign) fieldsFound++;

  const band = extractBand(upper);
  if (band) fieldsFound++;

  const mode = extractMode(upper);
  if (mode) fieldsFound++;

  const [rstSent, rstReceived] = extractRST(upper);
  if (rstSent) fieldsFound++;
  if (rstReceived) fieldsFound++;

  const confidence = Math.min(fieldsFound / 5, 1);

  return { callsign, band, mode, rstSent, rstReceived, confidence };
}

function extractCallsign(input: string): string | undefined {
  const match = input.match(/\b([A-Z]{1,2}\d[A-Z0-9]?\d?[A-Z]{1,4})\b/);
  if (match && match[1].length > 3) return match[1];
  return undefined;
}

function extractBand(input: string): string | undefined {
  for (const [pattern, band] of BAND_NAMES) {
    if (input.includes(pattern)) return band;
  }
  // "ON <number>" pattern
  const onMatch = input.match(/\bON\s+(\d+)\b/);
  if (onMatch && BAND_NUMBERS[onMatch[1]]) return BAND_NUMBERS[onMatch[1]];
  return undefined;
}

function extractMode(input: string): string | undefined {
  for (const [keyword, mode] of MODE_KEYWORDS) {
    const regex = new RegExp(`\\b${keyword}\\b`);
    if (regex.test(input)) return mode;
  }
  return undefined;
}

function extractRST(input: string): [string | undefined, string | undefined] {
  // "both ways" pattern
  if (/BOTH WAYS|BOTH DIRECTIONS|SAME BOTH/.test(input)) {
    const rst = extractSingleRST(input);
    if (rst) return [rst, rst];
  }

  // Digital report: "minus X" or "-X"
  const digitalMatch = input.match(/MINUS\s*(\d+)/);
  if (digitalMatch) {
    const rst = `-${digitalMatch[1].padStart(2, '0')}`;
    return [rst, rst]; // Simplified: assume same
  }

  // Standard RST: 2 or 3 digits
  const rstMatches = input.match(/\b(\d[\-\s]?\d(?:[\-\s]?\d)?)\b/g);
  if (rstMatches && rstMatches.length >= 2) {
    return [normalizeRST(rstMatches[0]), normalizeRST(rstMatches[1])];
  }
  if (rstMatches && rstMatches.length === 1) {
    return [normalizeRST(rstMatches[0]), undefined];
  }

  return [undefined, undefined];
}

function extractSingleRST(input: string): string | undefined {
  const match = input.match(/\b(\d[\-\s]?\d(?:[\-\s]?\d)?)\b/);
  if (match) return normalizeRST(match[1]);
  const digital = input.match(/MINUS\s*(\d+)/);
  if (digital) return `-${digital[1].padStart(2, '0')}`;
  return undefined;
}

function normalizeRST(raw: string): string {
  return raw.replace(/[\-\s]/g, '');
}
