import { BrowserWindow, ApplicationMenu, Utils, Updater } from "electrobun/bun";

const DEV_SERVER_PORT = 7300;
const DEV_SERVER_URL = `http://localhost:${DEV_SERVER_PORT}`;

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
