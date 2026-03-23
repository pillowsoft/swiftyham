import { BrowserWindow, ApplicationMenu, Utils, Updater } from "electrobun/bun";
import { Database } from "bun:sqlite";
import { join } from "path";
import { homedir } from "os";
import { mkdirSync, existsSync } from "fs";

const DEV_SERVER_PORT = 7300;
const DEV_SERVER_URL = `http://localhost:${DEV_SERVER_PORT}`;
const BRIDGE_PORT = 8412;

// ── Native SQLite Database ──────────────────────────────────────────────────

const dataDir = join(homedir(), "Library", "Application Support", "HamStationPro");
if (!existsSync(dataDir)) mkdirSync(dataDir, { recursive: true });
const dbPath = join(dataDir, "hamstation.sqlite");
const db = new Database(dbPath);

// Run migrations
db.run(`CREATE TABLE IF NOT EXISTS schema_version (version INTEGER NOT NULL)`);
const version = db.query("SELECT MAX(version) as v FROM schema_version").get() as any;
if (!version?.v || version.v < 1) {
	db.run(`CREATE TABLE IF NOT EXISTS logbook (id TEXT PRIMARY KEY, name TEXT NOT NULL, description TEXT, is_default INTEGER NOT NULL DEFAULT 0, created_at TEXT NOT NULL)`);
	db.run(`CREATE TABLE IF NOT EXISTS qso (id TEXT PRIMARY KEY, callsign TEXT NOT NULL, my_callsign TEXT NOT NULL, band TEXT NOT NULL, frequency_hz REAL NOT NULL, mode TEXT NOT NULL, datetime_on TEXT NOT NULL, datetime_off TEXT, rst_sent TEXT NOT NULL, rst_received TEXT NOT NULL, tx_power_watts REAL, my_grid TEXT, their_grid TEXT, dxcc_entity_id INTEGER, continent TEXT, cq_zone INTEGER, itu_zone INTEGER, name TEXT, qth TEXT, comment TEXT, logbook_id TEXT, created_at TEXT NOT NULL, updated_at TEXT NOT NULL)`);
	db.run(`CREATE INDEX IF NOT EXISTS idx_qso_datetime_on ON qso(datetime_on)`);
	db.run(`CREATE INDEX IF NOT EXISTS idx_qso_callsign ON qso(callsign)`);
	db.run(`CREATE INDEX IF NOT EXISTS idx_qso_band_mode ON qso(band, mode)`);
	db.run(`INSERT OR REPLACE INTO schema_version VALUES (1)`);
	// Ensure default logbook
	const existing = db.query("SELECT id FROM logbook WHERE is_default = 1").get();
	if (!existing) {
		db.run("INSERT INTO logbook (id, name, is_default, created_at) VALUES (?, ?, 1, ?)", [crypto.randomUUID(), "Default", new Date().toISOString()]);
	}
	console.log("Database initialized at:", dbPath);
}

// ── Bridge HTTP Server (localhost:8412) ─────────────────────────────────────

const bridgeServer = Bun.serve({
	port: BRIDGE_PORT,
	hostname: "127.0.0.1",
	fetch(req) {
		const url = new URL(req.url);
		const path = url.pathname;

		// CORS headers
		const headers = {
			"Access-Control-Allow-Origin": "*",
			"Access-Control-Allow-Methods": "GET, POST, PUT, DELETE, OPTIONS",
			"Access-Control-Allow-Headers": "Content-Type",
			"Content-Type": "application/json",
		};

		if (req.method === "OPTIONS") return new Response(null, { headers });

		// Health check
		if (path === "/api/health") {
			return Response.json({ status: "ok", version: "0.1.0", runtime: "electrobun", capabilities: ["sqlite", "rig", "cluster"] }, { headers });
		}

		// System info
		if (path === "/api/system/ram") {
			const ramGB = Math.round(require("os").totalmem() / (1024 ** 3));
			return Response.json({ totalGB: ramGB }, { headers });
		}

		// ── QSO CRUD ──

		if (path === "/api/qsos" && req.method === "GET") {
			const limit = parseInt(url.searchParams.get("limit") || "200");
			const offset = parseInt(url.searchParams.get("offset") || "0");
			const band = url.searchParams.get("band");
			const callsign = url.searchParams.get("callsign");

			let sql = "SELECT * FROM qso WHERE 1=1";
			const params: any[] = [];
			if (band) { sql += " AND band = ?"; params.push(band); }
			if (callsign) { sql += " AND callsign LIKE ?"; params.push(`%${callsign}%`); }
			sql += " ORDER BY datetime_on DESC LIMIT ? OFFSET ?";
			params.push(limit, offset);

			const qsos = db.query(sql).all(...params);
			const count = (db.query("SELECT COUNT(*) as cnt FROM qso").get() as any)?.cnt || 0;
			return Response.json({ qsos, totalCount: count }, { headers });
		}

		if (path === "/api/qsos" && req.method === "POST") {
			return (async () => {
				const qso = await req.json();
				db.run(
					`INSERT INTO qso (id, callsign, my_callsign, band, frequency_hz, mode, datetime_on, rst_sent, rst_received, tx_power_watts, my_grid, their_grid, name, qth, comment, logbook_id, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
					[qso.id, qso.callsign, qso.myCallsign, qso.band, qso.frequencyHz, qso.mode, qso.datetimeOn, qso.rstSent, qso.rstReceived, qso.txPowerWatts || null, qso.myGrid || null, qso.theirGrid || null, qso.name || null, qso.qth || null, qso.comment || null, qso.logbookId || null, qso.createdAt, qso.updatedAt]
				);
				return Response.json({ ok: true }, { headers });
			})();
		}

		if (path.startsWith("/api/qsos/") && req.method === "DELETE") {
			const id = path.split("/").pop();
			db.run("DELETE FROM qso WHERE id = ?", [id]);
			return Response.json({ ok: true }, { headers });
		}

		// ── NTP Status ──
		if (path === "/api/ntp/status") {
			return Response.json({ offsetMs: 0, acceptable: true, description: "System clock OK" }, { headers });
		}

		return Response.json({ error: "Not found" }, { status: 404, headers });
	},
});

console.log(`Bridge server running on http://127.0.0.1:${BRIDGE_PORT}`);

// ── Application Menu ────────────────────────────────────────────────────────

ApplicationMenu.setApplicationMenu([
	{
		label: "HamStation Pro",
		submenu: [
			{ role: "about" },
			{ type: "separator" },
			{ role: "hide" },
			{ role: "hideOthers" },
			{ role: "showAll" },
			{ type: "separator" },
			{
				label: "Quit HamStation Pro",
				accelerator: "CommandOrControl+Q",
				action: "quit-app",
			},
		],
	},
	{
		label: "File",
		submenu: [
			{
				label: "New QSO",
				accelerator: "CommandOrControl+N",
				action: "new-qso",
			},
			{ type: "separator" },
			{
				label: "Import ADIF...",
				accelerator: "CommandOrControl+I",
				action: "import-adif",
			},
			{
				label: "Export ADIF...",
				accelerator: "CommandOrControl+E",
				action: "export-adif",
			},
			{ type: "separator" },
			{ role: "close" },
		],
	},
	{
		label: "Edit",
		submenu: [
			{ role: "undo" },
			{ role: "redo" },
			{ type: "separator" },
			{ role: "cut" },
			{ role: "copy" },
			{ role: "paste" },
			{ role: "selectAll" },
		],
	},
	{
		label: "View",
		submenu: [
			{
				label: "Toggle Inspector",
				accelerator: "CommandOrControl+\\",
				action: "toggle-inspector",
			},
			{ type: "separator" },
			{ role: "toggleFullScreen" },
		],
	},
	{
		label: "Window",
		submenu: [
			{ role: "minimize" },
			{ role: "zoom" },
			{ type: "separator" },
			{ role: "bringAllToFront" },
		],
	},
	{
		label: "Help",
		submenu: [
			{
				label: "HamStation Pro Help",
				action: "show-help",
			},
		],
	},
]);

// Handle menu actions
ApplicationMenu.on("application-menu-clicked", async (event: any) => {
	const action = event?.data?.action;

	switch (action) {
		case "quit-app": {
			const { response } = await Utils.showMessageBox({
				type: "question",
				title: "Quit HamStation Pro",
				message: "Are you sure you want to quit?",
				detail: "Any unsaved changes will be lost.",
				buttons: ["Quit", "Cancel"],
				defaultId: 1,
				cancelId: 1,
			});
			if (response === 0) {
				Utils.quit();
			}
			break;
		}
	}
});

// ── Main Window ─────────────────────────────────────────────────────────────

async function getMainViewUrl(): Promise<string> {
	const channel = await Updater.localInfo.channel();
	if (channel === "dev") {
		try {
			await fetch(DEV_SERVER_URL, { method: "HEAD" });
			console.log(`HMR enabled: Using Vite dev server at ${DEV_SERVER_URL}`);
			return DEV_SERVER_URL;
		} catch {
			console.log(
				`Vite dev server not running on port ${DEV_SERVER_PORT}. Run 'just web-dev' first.`,
			);
		}
	}
	return "views://mainview/index.html";
}

const url = await getMainViewUrl();

const mainWindow = new BrowserWindow({
	title: "HamStation Pro",
	url,
	renderer: "cef", // Use CEF (Chromium) for full DevTools support
	frame: {
		width: 1400,
		height: 900,
		x: 100,
		y: 100,
	},
});

console.log("HamStation Pro desktop started! (CEF renderer)");
console.log("Press Cmd+Opt+I for DevTools");
