import { defineConfig } from "vitepress"
import container from "markdown-it-container"

// O seletor de idioma do VitePress so aparece quando existe mais de um locale,
// e ele nasce na nav ao lado do social link e do toggle de tema — que e onde a
// gente quer. Por isso nav e sidebar mudaram de lugar: cada idioma tem os seus
// dentro do proprio `themeConfig`. O `root` e o portugues, servido na raiz; o
// `en` e o ingles, servido em `/en/`.
//
// O que nao depende de idioma (social link, busca) fica no `themeConfig` de
// fora, que os dois herdam.
const pt = {
	label: "Português",
	lang: "pt-BR",
	description: "Framework de módulos para Roblox em que o self já vem tipado",
	themeConfig: {
		nav: [
			{ text: "Guia", link: "/guia/introducao" },
			{ text: "Arquitetura", link: "/arquitetura/" },
			{ text: "Tipagem", link: "/tipagem/" },
			{ text: "Setup", link: "/setup/" },
			{ text: "Benchmarks", link: "/benchmarks" },
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
					{ text: "Modelos", link: "/arquitetura/" },
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
					{ text: "Azul", link: "/setup/Azul" },
					{ text: "SyncTeam", link: "/setup/SyncTeam" },
				],
			},
			{
				text: "Medições",
				items: [{ text: "Benchmarks", link: "/benchmarks" }],
			},
		],

		outline: { level: [2, 3] as [number, number], label: "Nesta página" },
		docFooter: { prev: "Anterior", next: "Próxima" },
		lastUpdatedText: "Atualizado em",
		darkModeSwitchLabel: "Aparência",
		lightModeSwitchTitle: "Mudar para o tema claro",
		darkModeSwitchTitle: "Mudar para o tema escuro",
		sidebarMenuLabel: "Menu",
		returnToTopLabel: "Voltar ao topo",
		langMenuLabel: "Mudar de idioma",
		skipToContentLabel: "Pular para o conteúdo",

		footer: {
			message: "Publicado sob a licença MIT.",
			copyright: "Modux",
		},
	},
}

const en = {
	label: "English",
	lang: "en-US",
	link: "/en/",
	description: "A Roblox module framework where self comes typed for free",
	themeConfig: {
		nav: [
			{ text: "Guide", link: "/en/guia/introducao" },
			{ text: "Architecture", link: "/en/arquitetura/" },
			{ text: "Typing", link: "/en/tipagem/" },
			{ text: "Setup", link: "/en/setup/" },
			{ text: "Benchmarks", link: "/en/benchmarks" },
		],

		sidebar: [
			{
				text: "Guide",
				items: [
					{ text: "Introduction", link: "/en/guia/introducao" },
					{ text: "Installation", link: "/en/guia/instalacao" },
					{ text: "Configuration", link: "/en/guia/configuracao" },
				],
			},
			{
				text: "Architecture",
				items: [
					{ text: "Models", link: "/en/arquitetura/" },
					{ text: "Controllers", link: "/en/arquitetura/controllers" },
					{ text: "Services", link: "/en/arquitetura/services" },
					{ text: "Components", link: "/en/arquitetura/componentes" },
					{ text: "Lifecycle", link: "/en/arquitetura/ciclo-de-vida" },
					{ text: "Dependencies", link: "/en/arquitetura/dependencias" },
					{ text: "Libs", link: "/en/arquitetura/libs" },
				],
			},
			{
				text: "Typing",
				items: [
					{ text: "How the typing works", link: "/en/tipagem/" },
					{ text: "SelfOf", link: "/en/tipagem/selfof" },
					{ text: "Pick", link: "/en/tipagem/pick" },
					{ text: "Struct", link: "/en/tipagem/struct" },
					{ text: "Union", link: "/en/tipagem/union" },
					{ text: "Occlude", link: "/en/tipagem/occlude" },
					{ text: "Atomic", link: "/en/tipagem/atomic" },
					{ text: "Writing your own", link: "/en/tipagem/escrevendo" },
				],
			},
			{
				text: "Setup",
				items: [
					{ text: "Tools and watchers", link: "/en/setup/" },
					{ text: "VS Code", link: "/en/setup/Vscode" },
					{ text: "Wally", link: "/en/setup/Wally" },
					{ text: "Rogen", link: "/en/setup/Rogen" },
					{ text: "Modux", link: "/en/setup/Modux" },
					{ text: "Rojo", link: "/en/setup/Rojo" },
					{ text: "Azul", link: "/en/setup/Azul" },
					{ text: "SyncTeam", link: "/en/setup/SyncTeam" },
				],
			},
			{
				text: "Measurements",
				items: [{ text: "Benchmarks", link: "/en/benchmarks" }],
			},
		],

		outline: { level: [2, 3] as [number, number], label: "On this page" },

		footer: {
			message: "Released under the MIT License.",
			copyright: "Modux",
		},
	},
}

export default defineConfig({
	title: "Modux",
	description: pt.description,
	base: "/ModuxV3/",
	lastUpdated: true,
	cleanUrls: true,

	locales: { root: pt, en: en },

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
		socialLinks: [
			{ icon: "github", link: "https://github.com/victorcarmo2003/ModuxV3" },
		],

		search: {
			provider: "local",
			options: {
				locales: {
					root: {
						translations: {
							button: { buttonText: "Buscar", buttonAriaLabel: "Buscar" },
							modal: {
								displayDetails: "Mostrar lista detalhada",
								resetButtonTitle: "Limpar a busca",
								backButtonTitle: "Fechar a busca",
								noResultsText: "Nenhum resultado para",
								footer: {
									selectText: "para selecionar",
									navigateText: "para navegar",
									closeText: "para fechar",
								},
							},
						},
					},
				},
			},
		},
	},
})
