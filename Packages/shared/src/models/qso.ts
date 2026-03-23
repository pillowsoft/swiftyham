import type { BandId } from './band';
import type { OperatingMode } from './operating-mode';

/** Core QSO record — matches the `qso` SQLite table exactly. */
export interface QSO {
  id: string;
  callsign: string;
  myCallsign: string;
  band: BandId;
  frequencyHz: number;
  mode: OperatingMode;
  datetimeOn: string;   // ISO 8601 UTC
  datetimeOff?: string;
  rstSent: string;
  rstReceived: string;
  txPowerWatts?: number;
  myGrid?: string;
  theirGrid?: string;
  dxccEntityId?: number;
  continent?: string;
  cqZone?: number;
  ituZone?: number;
  name?: string;
  qth?: string;
  comment?: string;
  logbookId?: string;
  createdAt: string;
  updatedAt: string;
}

/** Extended QSO fields (1:1 with QSO, less-queried). */
export interface QSOExtended {
  qsoId: string;
  propagationMode?: string;
  satelliteName?: string;
  satelliteMode?: string;
  contestId?: string;
  contestExchangeSent?: string;
  contestExchangeRcvd?: string;
  sotaRef?: string;
  potaRef?: string;
  wwffRef?: string;
  myCounty?: string;
  theirCounty?: string;
  qslSent?: string;
  qslReceived?: string;
  lotwSent?: boolean;
  lotwReceived?: boolean;
  eqslSent?: boolean;
  eqslReceived?: boolean;
  clublogStatus?: string;
  adifImportSource?: string;
  isVerified?: boolean;
  appFields?: string; // JSON string for unknown APP_ tags
}

/** QSO sort fields for queries. */
export type QSOSortField = 'datetimeOn' | 'callsign' | 'band' | 'mode' | 'frequency';

/** QSO query filter. */
export interface QSOFilter {
  logbookId?: string;
  band?: BandId;
  mode?: OperatingMode;
  callsignContains?: string;
  dateFrom?: string;
  dateTo?: string;
  sortBy?: QSOSortField;
  ascending?: boolean;
  limit?: number;
  offset?: number;
}
