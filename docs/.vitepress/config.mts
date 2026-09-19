import { defineConfig } from "vitepress"
import container from "markdown-it-container"

export default defineConfig({
	title: "Modux",
	description: "Framework de módulos para Roblox em que o self já vem tipado",
	lang: "pt-BR",
	base: "/ModuxV3/",
	lastUpdated: true,
	cleanUrls: true,

	// `::: demo Titulo` — uma moldura para demonstrar, que aceita markdown
	// dentro: bloco de codigo, lista, imagem, outro container. Os containers do
	// VitePress (tip, warning) carregam um tom de aviso que nao serve quando a
	// intencao e so emoldurar um exemplo.
	markdown: {
		config(md) {
			md.use(container, "demo", {
				render(tokens: any[], index: number) {
					const token = tokens[index]
					if (token.nesting !== 1) {
						return "</div></div>\n"
					}
					const dots =
						'<span class="demo-dot" /><span class="demo-dot" /><span class="demo-dot" />'
					const title = token.info.trim().slice("demo".length).trim()
					const label = title
						? `<span class="demo-title">${md.utils.escapeHtml(title)}</span>`
						: ""
					return `<div class="demo-box"><div class="demo-bar">${dots}${label}</div><div class="demo-body">\n`
				},
			})
		},
	},

	themeConfig: {
		nav: [
			{ text: "Guia", link: "/guia/introducao" },
			{ text: "Arquitetura", link: "/arquitetura/" },
			{ text: "Tipagem", link: "/tipagem/" },
			{ text: "Setup", link: "/setup/" },
		],

		sidebar: [
			{
				text: "Guia",
				items: [
					{ text: "Introdução", link: "/guia/introducao" },
					{ text: "Instalação", link: "/guia/instalacao" },
					{ text: "Configuração", link: "/guia/configuracao" },
				],
			},
			{
				text: "Arquitetura",
				items: [
					{ text: "As três espécies", link: "/arquitetura/" },
					{ text: "Controllers", link: "/arquitetura/controllers" },
					{ text: "Services", link: "/arquitetura/services" },
					{ text: "Componentes", link: "/arquitetura/componentes" },
					{ text: "Ciclo de vida", link: "/arquitetura/ciclo-de-vida" },
					{ text: "Dependências", link: "/arquitetura/dependencias" },
					{ text: "Libs", link: "/arquitetura/libs" },
				],
			},
			{
				text: "Tipagem",
				items: [
					{ text: "Como a tipagem funciona", link: "/tipagem/" },
					{ text: "SelfOf", link: "/tipagem/selfof" },
					{ text: "Pick", link: "/tipagem/pick" },
					{ text: "Struct", link: "/tipagem/struct" },
					{ text: "Union", link: "/tipagem/union" },
					{ text: "Occlude", link: "/tipagem/occlude" },
					{ text: "Atomic", link: "/tipagem/atomic" },
					{ text: "Escrevendo a sua", link: "/tipagem/escrevendo" },
				],
			},
			{
				text: "Setup",
				items: [
					{ text: "Tools e watcher", link: "/setup/" },
					{ text: "VS Code", link: "/setup/Vscode" },
					{ text: "Wally", link: "/setup/Wally" },
					{ text: "Rogen", link: "/setup/Rogen" },
					{ text: "Modux", link: "/setup/Modux" },
					{ text: "Rojo", link: "/setup/Rojo" },
				],
			},
		],

		socialLinks: [{ icon: "github", link: "https://github.com/victorcarmo2003/ModuxV3" }],

		search: { provider: "local" },

		footer: {
			message: "Publicado sob a licença MIT.",
			copyright: "Modux",
		},

		outline: { level: [2, 3] },
	},
})
