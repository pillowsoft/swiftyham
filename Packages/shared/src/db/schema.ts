/**
 * SQLite schema for HamStation Pro.
 * Verbatim port of Packages/HamStationKit/Sources/Database/Migrations.swift
 * Databases are interchangeable between the macOS app and web app.
 */

export const MIGRATIONS = [
  {
    version: 1,
    name: 'initial',
    sql: `
      CREATE TABLE IF NOT EXISTS schema_version (
        version INTEGER NOT NULL
      );

      CREATE TABLE IF NOT EXISTS logbook (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT,
        is_default INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL
      );

      CREATE TABLE IF NOT EXISTS dxcc_entity (
        id INTEGER PRIMARY KEY,
        name TEXT NOT NULL,
        prefix TEXT NOT NULL,
        continent TEXT NOT NULL,
        cq_zone INTEGER NOT NULL,
        itu_zone INTEGER NOT NULL,
        latitude REAL,
        longitude REAL,
        is_deleted INTEGER NOT NULL DEFAULT 0,
        updated_at TEXT
      );

      CREATE TABLE IF NOT EXISTS qso (
        id TEXT PRIMARY KEY,
        callsign TEXT NOT NULL,
        my_callsign TEXT NOT NULL,
        band TEXT NOT NULL,
        frequency_hz REAL NOT NULL,
        mode TEXT NOT NULL,
        datetime_on TEXT NOT NULL,
        datetime_off TEXT,
        rst_sent TEXT NOT NULL,
        rst_received TEXT NOT NULL,
        tx_power_watts REAL,
        my_grid TEXT,
        their_grid TEXT,
        dxcc_entity_id INTEGER REFERENCES dxcc_entity(id) ON DELETE SET NULL,
        continent TEXT,
        cq_zone INTEGER,
        itu_zone INTEGER,
        name TEXT,
        qth TEXT,
        comment TEXT,
        logbook_id TEXT REFERENCES logbook(id) ON DELETE SET NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      );

      CREATE INDEX IF NOT EXISTS idx_qso_datetime_on ON qso(datetime_on);
      CREATE INDEX IF NOT EXISTS idx_qso_callsign ON qso(callsign);
      CREATE INDEX IF NOT EXISTS idx_qso_band_mode ON qso(band, mode);
      CREATE INDEX IF NOT EXISTS idx_qso_dxcc_entity_id ON qso(dxcc_entity_id);
      CREATE INDEX IF NOT EXISTS idx_qso_logbook_id ON qso(logbook_id);

      CREATE TABLE IF NOT EXISTS qso_extended (
        qso_id TEXT PRIMARY KEY REFERENCES qso(id) ON DELETE CASCADE,
        propagation_mode TEXT,
        satellite_name TEXT,
        satellite_mode TEXT,
        contest_id TEXT,
        contest_exchange_sent TEXT,
        contest_exchange_rcvd TEXT,
        sota_ref TEXT,
        pota_ref TEXT,
        wwff_ref TEXT,
        my_county TEXT,
        their_county TEXT,
        qsl_sent TEXT,
        qsl_received TEXT,
        lotw_sent INTEGER,
        lotw_received INTEGER,
        eqsl_sent INTEGER,
        eqsl_received INTEGER,
        clublog_status TEXT,
        adif_import_source TEXT,
        is_verified INTEGER,
        app_fields TEXT
      );

      CREATE TABLE IF NOT EXISTS callsign_cache (
        callsign TEXT PRIMARY KEY,
        name TEXT,
        qth TEXT,
        grid TEXT,
        country TEXT,
        state TEXT,
        county TEXT,
        email TEXT,
        lotw_member INTEGER,
        source TEXT NOT NULL,
        fetched_at TEXT NOT NULL,
        expires_at TEXT NOT NULL
      );

      CREATE INDEX IF NOT EXISTS idx_callsign_cache_expires_at ON callsign_cache(expires_at);

      CREATE TABLE IF NOT EXISTS award_progress (
        id TEXT PRIMARY KEY,
        award_type TEXT NOT NULL,
        band TEXT,
        mode TEXT,
        entity_or_ref TEXT NOT NULL,
        worked INTEGER NOT NULL DEFAULT 0,
        confirmed INTEGER NOT NULL DEFAULT 0,
        qso_id TEXT REFERENCES qso(id) ON DELETE SET NULL,
        confirmed_via TEXT
      );

      CREATE INDEX IF NOT EXISTS idx_award_progress_type_band_mode ON award_progress(award_type, band, mode);

      INSERT OR IGNORE INTO schema_version VALUES (1);
    `,
  },
];

/** Get the current schema version from the database. */
export function getSchemaVersion(db: { exec: (sql: string) => any[] }): number {
  try {
    const result = db.exec('SELECT version FROM schema_version ORDER BY version DESC LIMIT 1');
    if (result.length > 0 && result[0].values.length > 0) {
      return result[0].values[0][0] as number;
    }
  } catch {
    // Table doesn't exist yet
  }
  return 0;
}

/** Run pending migrations. */
export function runMigrations(db: { run: (sql: string) => void; exec: (sql: string) => any[] }): void {
  const current = getSchemaVersion(db);
  for (const migration of MIGRATIONS) {
    if (migration.version > current) {
      db.run(migration.sql);
    }
  }
}
