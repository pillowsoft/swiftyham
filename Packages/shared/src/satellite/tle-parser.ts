/**
 * TLE (Two-Line Element) parser for satellite orbital data.
 * Port of HamStationKit/Sources/Satellite/TLEParser.swift
 */

export interface TLE {
  id: number;
  name: string;
  inclination: number;    // degrees
  raan: number;           // Right Ascension of Ascending Node (degrees)
  eccentricity: number;   // 0-1
  argOfPerigee: number;   // degrees
  meanAnomaly: number;    // degrees
  meanMotion: number;     // revolutions per day
  epochYear: number;      // 4-digit year
  epochDay: number;       // fractional day of year
  bstar: number;          // drag term
  epoch: Date;            // computed from epochYear + epochDay
}

/**
 * Parse TLE text (3-line format: name, line1, line2).
 */
export function parseTLE(text: string): TLE[] {
  const lines = text.split('\n').map(l => l.trim()).filter(l => l.length > 0);
  const results: TLE[] = [];

  let i = 0;
  while (i < lines.length) {
    // Find a line starting with "1 " (line 1 of TLE)
    if (lines[i].startsWith('1 ') && i + 1 < lines.length && lines[i + 1].startsWith('2 ')) {
      // Line before this is the name (if it doesn't start with 1 or 2)
      const name = (i > 0 && !lines[i - 1].startsWith('1 ') && !lines[i - 1].startsWith('2 '))
        ? lines[i - 1] : 'Unknown';

      const tle = parseTLELines(name, lines[i], lines[i + 1]);
      if (tle) results.push(tle);
      i += 2;
    } else {
      i++;
    }
  }

  return results;
}

function parseTLELines(name: string, line1: string, line2: string): TLE | null {
  if (line1.length < 69 || line2.length < 69) return null;

  try {
    const catalogNumber = parseInt(line1.substring(2, 7).trim());
    const epochYr = parseInt(line1.substring(18, 20).trim());
    const epochDy = parseFloat(line1.substring(20, 32).trim());
    const bstarStr = line1.substring(53, 61).trim();

    const inclination = parseFloat(line2.substring(8, 16).trim());
    const raan = parseFloat(line2.substring(17, 25).trim());
    const eccStr = '0.' + line2.substring(26, 33).trim();
    const eccentricity = parseFloat(eccStr);
    const argPerigee = parseFloat(line2.substring(34, 42).trim());
    const meanAnomaly = parseFloat(line2.substring(43, 51).trim());
    const meanMotion = parseFloat(line2.substring(52, 63).trim());

    const fullYear = epochYr < 57 ? 2000 + epochYr : 1900 + epochYr;
    const bstar = parseExponential(bstarStr);

    // Compute epoch Date
    const jan1 = new Date(Date.UTC(fullYear, 0, 1));
    const epoch = new Date(jan1.getTime() + (epochDy - 1) * 86400000);

    return {
      id: catalogNumber,
      name: name.trim(),
      inclination, raan, eccentricity, argOfPerigee, meanAnomaly, meanMotion,
      epochYear: fullYear, epochDay: epochDy, bstar, epoch,
    };
  } catch {
    return null;
  }
}

/** Parse BSTAR-format exponential notation: "+12345-6" → 0.12345e-6 */
function parseExponential(s: string): number {
  if (!s || s.trim().length === 0) return 0;
  let cleaned = s.trim().replace(/\s+/g, '');

  // Handle format like "+12345-6" → "0.12345e-6"
  const match = cleaned.match(/^([+-]?)(\d+)([+-]\d+)$/);
  if (match) {
    const sign = match[1] === '-' ? -1 : 1;
    const mantissa = parseFloat('0.' + match[2]);
    const exponent = parseInt(match[3]);
    return sign * mantissa * Math.pow(10, exponent);
  }

  // Try direct parse
  return parseFloat(cleaned) || 0;
}

/** Well-known satellite TLEs for demo. */
export const DEMO_TLES = `ISS (ZARYA)
1 25544U 98067A   24079.50000000  .00016717  00000-0  10270-3 0  9003
2 25544  51.6400 247.4627 0006703  30.5360 325.0288 15.49815700  1234
SO-50
1 27607U 02058C   24079.00000000  .00000158  00000-0  84210-4 0  9001
2 27607  64.5567 135.2478 0025000 213.5000 146.5000 14.75500000  1234
AO-91
1 43017U 17073E   24079.00000000  .00000820  00000-0  43510-4 0  9001
2 43017  97.5000 115.0000 0013000  45.0000 315.0000 15.22000000  1234`;
