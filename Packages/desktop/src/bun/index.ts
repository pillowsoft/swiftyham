import { BrowserWindow, Updater } from "electrobun/bun";

const DEV_SERVER_PORT = 7300;
const DEV_SERVER_URL = `http://localhost:${DEV_SERVER_PORT}`;

// In dev mode, check if the Vite dev server is running for HMR
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
	frame: {
		width: 1400,
		height: 900,
		x: 100,
		y: 100,
	},
});

console.log("HamStation Pro desktop started!");
