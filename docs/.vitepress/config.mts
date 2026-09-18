import { defineConfig } from "vitepress"

export default defineConfig({
	title: "Modux",
	description: "Framework de módulos para Roblox em que o self já vem tipado",
	lang: "pt-BR",
	base: "/ModuxV3/",
	lastUpdated: true,
	cleanUrls: true,

	themeConfig: {
		nav: [
			{ text: "Guia", link: "/guia/introducao" },
			{ text: "Tipos", link: "/tipos/" },
			{ text: "Ferramentas", link: "/ferramentas" },
		],

		sidebar: [
			{
				text: "Guia",
				items: [
					{ text: "Introdução", link: "/guia/introducao" },
					{ text: "Instalação", link: "/guia/instalacao" },
					{ text: "Módulos", link: "/guia/modulos" },
					{ text: "Ciclo de vida", link: "/guia/ciclo-de-vida" },
					{ text: "Dependências", link: "/guia/dependencias" },
					{ text: "Componentes", link: "/guia/componentes" },
					{ text: "Libs", link: "/guia/libs" },
					{ text: "Configuração", link: "/guia/configuracao" },
				],
			},
			{
				text: "Tipos",
				items: [
					{ text: "Como a tipagem funciona", link: "/tipos/" },
					{ text: "SelfOf", link: "/tipos/selfof" },
					{ text: "Pick", link: "/tipos/pick" },
					{ text: "Struct", link: "/tipos/struct" },
					{ text: "Union", link: "/tipos/union" },
					{ text: "Occlude", link: "/tipos/occlude" },
					{ text: "Escrevendo a sua", link: "/tipos/escrevendo" },
				],
			},
			{
				text: "Referência",
				items: [{ text: "Ferramentas e comandos", link: "/ferramentas" }],
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
