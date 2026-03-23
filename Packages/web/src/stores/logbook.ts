import { proxy } from 'valtio';
import type { QSO, QSOFilter, BandId } from '@hamstation/shared';
import type { OperatingMode } from '@hamstation/shared';
import { v4 as uuid } from 'uuid';

export const logbookStore = proxy({
  qsos: [] as QSO[],
  totalCount: 0,
  isLoading: false,

  // Filters
  filter: {
    callsignContains: '',
    band: undefined as BandId | undefined,
    mode: undefined as OperatingMode | undefined,
    sortBy: 'datetimeOn' as const,
    ascending: false,
    limit: 100,
    offset: 0,
  } satisfies QSOFilter,
});

/** Create a new QSO with defaults. */
export function createQSO(fields: Partial<QSO> & { callsign: string; myCallsign: string }): QSO {
  const now = new Date().toISOString();
  return {
    id: uuid(),
    band: '20m',
    frequencyHz: 14_074_000,
    mode: 'FT8',
    datetimeOn: now,
    rstSent: '-10',
    rstReceived: '-10',
    createdAt: now,
    updatedAt: now,
    ...fields,
  };
}

// Demo data for initial development
export function loadDemoData() {
  const now = Date.now();
  const demoQSOs: QSO[] = [
    createQSO({ callsign: 'JA1ABC', myCallsign: 'W1AW', band: '20m', mode: 'FT8', frequencyHz: 14_074_000, rstSent: '-10', rstReceived: '-12', name: 'Taro', datetimeOn: new Date(now - 300_000).toISOString() }),
    createQSO({ callsign: 'DL1ABC', myCallsign: 'W1AW', band: '20m', mode: 'FT8', frequencyHz: 14_074_000, rstSent: '-08', rstReceived: '-15', name: 'Hans', datetimeOn: new Date(now - 600_000).toISOString() }),
    createQSO({ callsign: 'VK2RZA', myCallsign: 'W1AW', band: '15m', mode: 'SSB', frequencyHz: 21_250_000, rstSent: '59', rstReceived: '57', name: 'Ray', datetimeOn: new Date(now - 1_200_000).toISOString() }),
    createQSO({ callsign: 'W1AW', myCallsign: 'W1AW', band: '40m', mode: 'CW', frequencyHz: 7_040_000, rstSent: '599', rstReceived: '599', name: 'ARRL HQ', datetimeOn: new Date(now - 2_400_000).toISOString() }),
    createQSO({ callsign: 'ZL3AB', myCallsign: 'W1AW', band: '10m', mode: 'FT8', frequencyHz: 28_074_000, rstSent: '-05', rstReceived: '-18', name: 'Mike', datetimeOn: new Date(now - 3_600_000).toISOString() }),
    createQSO({ callsign: 'PY2ABC', myCallsign: 'W1AW', band: '20m', mode: 'SSB', frequencyHz: 14_200_000, rstSent: '59', rstReceived: '55', name: 'Carlos', datetimeOn: new Date(now - 4_800_000).toISOString() }),
    createQSO({ callsign: 'UA3ABC', myCallsign: 'W1AW', band: '15m', mode: 'CW', frequencyHz: 21_030_000, rstSent: '579', rstReceived: '559', name: 'Ivan', datetimeOn: new Date(now - 6_000_000).toISOString() }),
    createQSO({ callsign: '9A2ABC', myCallsign: 'W1AW', band: '17m', mode: 'FT8', frequencyHz: 18_100_000, rstSent: '-14', rstReceived: '-20', name: 'Ante', datetimeOn: new Date(now - 7_200_000).toISOString() }),
    createQSO({ callsign: 'VU2ABC', myCallsign: 'W1AW', band: '20m', mode: 'FT4', frequencyHz: 14_080_000, rstSent: '-03', rstReceived: '-10', name: 'Raj', datetimeOn: new Date(now - 8_400_000).toISOString() }),
    createQSO({ callsign: 'G4ABC', myCallsign: 'W1AW', band: '20m', mode: 'SSB', frequencyHz: 14_195_000, rstSent: '59', rstReceived: '59', name: 'John', datetimeOn: new Date(now - 9_600_000).toISOString() }),
  ];
  logbookStore.qsos = demoQSOs;
  logbookStore.totalCount = demoQSOs.length;
}
