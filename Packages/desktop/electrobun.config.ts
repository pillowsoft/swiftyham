import type { ElectrobunConfig } from "electrobun";

export default {
	app: {
		name: "HamStation Pro",
		identifier: "com.hamstation.pro",
		version: "0.1.0",
	},
	build: {
		// Web app builds to ../web/dist/ — copy from sibling package
		copy: {
			"../web/dist/index.html": "views/mainview/index.html",
			"../web/dist/assets": "views/mainview/assets",
		},
		watchIgnore: ["dist/**"],
		// CEF enabled for full Chrome DevTools and consistent rendering
		mac: {
			bundleCEF: true,
		},
		linux: {
			bundleCEF: true,
		},
		win: {
			bundleCEF: true,
		},
	},
} satisfies ElectrobunConfig;
