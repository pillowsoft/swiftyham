/**
 * Database repository — typed CRUD operations over raw SQL.
 * Works with any driver that exposes run/exec/get interfaces (sql.js, better-sqlite3).
 */

import type { QSO, QSOFilter, QSOSortField, BandId } from '../models';
import type { OperatingMode } from '../models';
import { v4 as uuid } from 'uuid';

/** Minimal database driver interface. */
export interface DatabaseDriver {
  run(sql: string, params?: any[]): void;
  exec(sql: string): any[];
  get(sql: string, params?: any[]): any;
  all(sql: string, params?: any[]): any[];
}

// Column name mapping: TypeScript camelCase → SQL snake_case
function qsoFromRow(row: any): QSO {
  return {
    id: row.id,
    callsign: row.callsign,
    myCallsign: row.my_callsign,
    band: row.band as BandId,
    frequencyHz: row.frequency_hz,
    mode: row.mode as OperatingMode,
    datetimeOn: row.datetime_on,
    datetimeOff: row.datetime_off || undefined,
    rstSent: row.rst_sent,
    rstReceived: row.rst_received,
    txPowerWatts: row.tx_power_watts || undefined,
    myGrid: row.my_grid || undefined,
    theirGrid: row.their_grid || undefined,
    dxccEntityId: row.dxcc_entity_id || undefined,
    continent: row.continent || undefined,
    cqZone: row.cq_zone || undefined,
    ituZone: row.itu_zone || undefined,
    name: row.name || undefined,
    qth: row.qth || undefined,
    comment: row.comment || undefined,
    logbookId: row.logbook_id || undefined,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}

export class QSORepository {
  constructor(private db: DatabaseDriver) {}

  insert(qso: QSO): void {
    this.db.run(
      `INSERT INTO qso (id, callsign, my_callsign, band, frequency_hz, mode, datetime_on, datetime_off,
        rst_sent, rst_received, tx_power_watts, my_grid, their_grid, dxcc_entity_id, continent,
        cq_zone, itu_zone, name, qth, comment, logbook_id, created_at, updated_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        qso.id, qso.callsign, qso.myCallsign, qso.band, qso.frequencyHz, qso.mode,
        qso.datetimeOn, qso.datetimeOff || null, qso.rstSent, qso.rstReceived,
        qso.txPowerWatts || null, qso.myGrid || null, qso.theirGrid || null,
        qso.dxccEntityId || null, qso.continent || null, qso.cqZone || null,
        qso.ituZone || null, qso.name || null, qso.qth || null, qso.comment || null,
        qso.logbookId || null, qso.createdAt, qso.updatedAt,
      ]
    );
  }

  update(qso: QSO): void {
    this.db.run(
      `UPDATE qso SET callsign=?, my_callsign=?, band=?, frequency_hz=?, mode=?, datetime_on=?,
        datetime_off=?, rst_sent=?, rst_received=?, tx_power_watts=?, my_grid=?, their_grid=?,
        dxcc_entity_id=?, continent=?, cq_zone=?, itu_zone=?, name=?, qth=?, comment=?,
        logbook_id=?, updated_at=? WHERE id=?`,
      [
        qso.callsign, qso.myCallsign, qso.band, qso.frequencyHz, qso.mode,
        qso.datetimeOn, qso.datetimeOff || null, qso.rstSent, qso.rstReceived,
        qso.txPowerWatts || null, qso.myGrid || null, qso.theirGrid || null,
        qso.dxccEntityId || null, qso.continent || null, qso.cqZone || null,
        qso.ituZone || null, qso.name || null, qso.qth || null, qso.comment || null,
        qso.logbookId || null, new Date().toISOString(), qso.id,
      ]
    );
  }

  delete(id: string): void {
    this.db.run('DELETE FROM qso WHERE id = ?', [id]);
  }

  findById(id: string): QSO | null {
    const row = this.db.get('SELECT * FROM qso WHERE id = ?', [id]);
    return row ? qsoFromRow(row) : null;
  }

  findAll(filter?: QSOFilter): QSO[] {
    let sql = 'SELECT * FROM qso WHERE 1=1';
    const params: any[] = [];

    if (filter?.logbookId) { sql += ' AND logbook_id = ?'; params.push(filter.logbookId); }
    if (filter?.band) { sql += ' AND band = ?'; params.push(filter.band); }
    if (filter?.mode) { sql += ' AND mode = ?'; params.push(filter.mode); }
    if (filter?.callsignContains) { sql += ' AND callsign LIKE ?'; params.push(`%${filter.callsignContains}%`); }
    if (filter?.dateFrom) { sql += ' AND datetime_on >= ?'; params.push(filter.dateFrom); }
    if (filter?.dateTo) { sql += ' AND datetime_on <= ?'; params.push(filter.dateTo); }

    const sortCol = sortColumnMap[filter?.sortBy || 'datetimeOn'];
    const dir = filter?.ascending ? 'ASC' : 'DESC';
    sql += ` ORDER BY ${sortCol} ${dir}`;

    if (filter?.limit) { sql += ' LIMIT ?'; params.push(filter.limit); }
    if (filter?.offset) { sql += ' OFFSET ?'; params.push(filter.offset); }

    return this.db.all(sql, params).map(qsoFromRow);
  }

  count(logbookId?: string): number {
    let sql = 'SELECT COUNT(*) as cnt FROM qso';
    const params: any[] = [];
    if (logbookId) { sql += ' WHERE logbook_id = ?'; params.push(logbookId); }
    const row = this.db.get(sql, params);
    return row?.cnt || 0;
  }

  /** Ensure default logbook exists. */
  ensureDefaultLogbook(): string {
    const existing = this.db.get('SELECT id FROM logbook WHERE is_default = 1');
    if (existing) return existing.id;

    const id = uuid();
    this.db.run(
      'INSERT INTO logbook (id, name, is_default, created_at) VALUES (?, ?, 1, ?)',
      [id, 'Default', new Date().toISOString()]
    );
    return id;
  }
}

const sortColumnMap: Record<QSOSortField, string> = {
  datetimeOn: 'datetime_on',
  callsign: 'callsign',
  band: 'band',
  mode: 'mode',
  frequency: 'frequency_hz',
};
