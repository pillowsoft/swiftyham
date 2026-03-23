/**
 * Callsign lookup via HamDB API (free, no key required).
 * Falls back gracefully on network errors.
 */

export interface CallsignLookupResult {
  callsign: string;
  name?: string;
  qth?: string;
  grid?: string;
  country?: string;
  state?: string;
  county?: string;
  class?: string;
  status: 'found' | 'not_found' | 'error';
}

const HAMDB_URL = 'https://api.hamdb.org/v1';

/**
 * Look up a callsign via HamDB.
 * CORS note: HamDB supports CORS for JSON responses.
 */
export async function lookupCallsign(callsign: string): Promise<CallsignLookupResult> {
  const clean = callsign.trim().toUpperCase();
  if (!clean || clean.length < 3) {
    return { callsign: clean, status: 'not_found' };
  }

  try {
    const resp = await fetch(`${HAMDB_URL}/${clean}/json/hamstationpro`, {
      signal: AbortSignal.timeout(5000),
    });

    if (!resp.ok) {
      return { callsign: clean, status: 'error' };
    }

    const data = await resp.json();
    const record = data?.hamdb?.callsign;

    if (!record || record.call === 'NOT_FOUND') {
      return { callsign: clean, status: 'not_found' };
    }

    return {
      callsign: record.call || clean,
      name: formatName(record.fname, record.mi, record.name),
      qth: formatQTH(record.addr2, record.state),
      grid: record.grid || undefined,
      country: record.country || undefined,
      state: record.state || undefined,
      county: record.county || undefined,
      class: record.class || undefined,
      status: 'found',
    };
  } catch {
    return { callsign: clean, status: 'error' };
  }
}

function formatName(fname?: string, mi?: string, lname?: string): string | undefined {
  const parts = [fname, mi, lname].filter(Boolean);
  if (parts.length === 0) return undefined;
  return parts.join(' ').trim();
}

function formatQTH(city?: string, state?: string): string | undefined {
  const parts = [city, state].filter(Boolean);
  if (parts.length === 0) return undefined;
  return parts.join(', ').trim();
}
