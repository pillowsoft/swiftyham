import Foundation
import GRDB

/// Database migration definitions for hamstation.sqlite.
///
/// Each migration is named with a version prefix and descriptive name.
/// Migrations only add — they never remove columns.
public struct DatabaseMigrations: Sendable {

    /// Registers all known migrations with the given migrator.
    public static func registerMigrations(_ migrator: inout DatabaseMigrator) {
        migrator.registerMigration("v1_initial") { db in
            // -- logbook --
            try db.create(table: "logbook") { t in
                t.primaryKey("id", .text).notNull()
                t.column("name", .text).notNull()
                t.column("description", .text)
                t.column("is_default", .boolean).notNull().defaults(to: false)
                t.column("created_at", .datetime).notNull()
            }

            // -- dxcc_entity (must be created before qso which references it) --
            try db.create(table: "dxcc_entity") { t in
                t.primaryKey("id", .integer)
                t.column("name", .text).notNull()
                t.column("prefix", .text).notNull()
                t.column("continent", .text).notNull()
                t.column("cq_zone", .integer).notNull()
                t.column("itu_zone", .integer).notNull()
                t.column("latitude", .double)
                t.column("longitude", .double)
                t.column("is_deleted", .boolean).notNull().defaults(to: false)
                t.column("updated_at", .datetime)
            }

            // -- qso --
            try db.create(table: "qso") { t in
                t.primaryKey("id", .text).notNull()
                t.column("callsign", .text).notNull()
                t.column("my_callsign", .text).notNull()
                t.column("band", .text).notNull()
                t.column("frequency_hz", .double).notNull()
                t.column("mode", .text).notNull()
                t.column("datetime_on", .datetime).notNull()
                t.column("datetime_off", .datetime)
                t.column("rst_sent", .text).notNull()
                t.column("rst_received", .text).notNull()
                t.column("tx_power_watts", .double)
                t.column("my_grid", .text)
                t.column("their_grid", .text)
                t.column("dxcc_entity_id", .integer)
                    .references("dxcc_entity", onDelete: .setNull)
                t.column("continent", .text)
                t.column("cq_zone", .integer)
                t.column("itu_zone", .integer)
                t.column("name", .text)
                t.column("qth", .text)
                t.column("comment", .text)
                t.column("logbook_id", .text)
                    .references("logbook", onDelete: .setNull)
                t.column("created_at", .datetime).notNull()
                t.column("updated_at", .datetime).notNull()
            }

            try db.create(index: "idx_qso_datetime_on", on: "qso", columns: ["datetime_on"])
            try db.create(index: "idx_qso_callsign", on: "qso", columns: ["callsign"])
            try db.create(index: "idx_qso_band_mode", on: "qso", columns: ["band", "mode"])
            try db.create(index: "idx_qso_dxcc_entity_id", on: "qso", columns: ["dxcc_entity_id"])
            try db.create(index: "idx_qso_logbook_id", on: "qso", columns: ["logbook_id"])

            // -- qso_extended --
            try db.create(table: "qso_extended") { t in
                t.primaryKey("qso_id", .text)
                    .notNull()
                    .references("qso", onDelete: .cascade)
                t.column("propagation_mode", .text)
                t.column("satellite_name", .text)
                t.column("satellite_mode", .text)
                t.column("contest_id", .text)
                t.column("contest_exchange_sent", .text)
                t.column("contest_exchange_rcvd", .text)
                t.column("sota_ref", .text)
                t.column("pota_ref", .text)
                t.column("wwff_ref", .text)
                t.column("my_county", .text)
                t.column("their_county", .text)
                t.column("qsl_sent", .text)
                t.column("qsl_received", .text)
                t.column("lotw_sent", .boolean)
                t.column("lotw_received", .boolean)
                t.column("eqsl_sent", .boolean)
                t.column("eqsl_received", .boolean)
                t.column("clublog_status", .text)
                t.column("adif_import_source", .text)
                t.column("is_verified", .boolean)
                t.column("app_fields", .text)
            }

            // -- callsign_cache --
            try db.create(table: "callsign_cache") { t in
                t.primaryKey("callsign", .text).notNull()
                t.column("name", .text)
                t.column("qth", .text)
                t.column("grid", .text)
                t.column("country", .text)
                t.column("state", .text)
                t.column("county", .text)
                t.column("email", .text)
                t.column("lotw_member", .boolean)
                t.column("source", .text).notNull()
                t.column("fetched_at", .datetime).notNull()
                t.column("expires_at", .datetime).notNull()
            }

            try db.create(
                index: "idx_callsign_cache_expires_at",
                on: "callsign_cache",
                columns: ["expires_at"]
            )

            // -- award_progress --
            try db.create(table: "award_progress") { t in
                t.primaryKey("id", .text).notNull()
                t.column("award_type", .text).notNull()
                t.column("band", .text)
                t.column("mode", .text)
                t.column("entity_or_ref", .text).notNull()
                t.column("worked", .boolean).notNull().defaults(to: false)
                t.column("confirmed", .boolean).notNull().defaults(to: false)
                t.column("qso_id", .text)
                    .references("qso", onDelete: .setNull)
                t.column("confirmed_via", .text)
            }

            try db.create(
                index: "idx_award_progress_type_band_mode",
                on: "award_progress",
                columns: ["award_type", "band", "mode"]
            )
        }
    }
}
