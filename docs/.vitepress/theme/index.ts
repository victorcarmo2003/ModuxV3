import DefaultTheme from "vitepress/theme"
import type { Theme } from "vitepress"
import FileTree from "./FileTree.vue"
import Shot from "./Shot.vue"
import "./shortcut.css"

export default {
	extends: DefaultTheme,
	enhanceApp({ app }) {
		app.component("FileTree", FileTree)
		app.component("Shot", Shot)
	},
} satisfies Theme
