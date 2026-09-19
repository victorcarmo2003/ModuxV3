<script setup lang="ts">
import { withBase } from "vitepress"

withDefaults(
	defineProps<{
		src: string
		alt?: string
		caption?: string
		title?: string
		width?: string
	}>(),
	{ alt: "", title: "" }
)
</script>

<template>
	<figure class="shot">
		<div class="shot-bar">
			<span class="shot-dot shot-red" />
			<span class="shot-dot shot-amber" />
			<span class="shot-dot shot-green" />
			<span v-if="title" class="shot-title">{{ title }}</span>
		</div>

		<!-- withBase porque o src chega por prop: o VitePress so reescreve o
		     caminho quando ele esta escrito no markdown, nao quando vem de um
		     binding. Sem isso a imagem some no deploy e funciona local. -->
		<img
			class="shot-img"
			:src="withBase(src)"
			:alt="alt"
			:style="width ? { maxWidth: width } : undefined"
			loading="lazy"
		/>

		<figcaption v-if="caption" class="shot-caption">{{ caption }}</figcaption>
	</figure>
</template>

<style scoped>
.shot {
	margin: 24px 0;
	border: 1px solid var(--vp-c-divider);
	border-radius: 12px;
	overflow: hidden;
	background: var(--vp-c-bg-alt);
}

.shot-bar {
	display: flex;
	align-items: center;
	gap: 7px;
	padding: 10px 14px;
	border-bottom: 1px solid var(--vp-c-divider);
	background: var(--vp-c-bg-soft);
}

.shot-dot {
	width: 11px;
	height: 11px;
	border-radius: 50%;
	flex-shrink: 0;
}

/* Cores fixas: sao o unico sinal de "isto e uma janela" e precisam ler igual
   nos dois temas, entao nao saem das variaveis do tema. */
.shot-red {
	background: #ed6a5e;
}
.shot-amber {
	background: #f4bf4f;
}
.shot-green {
	background: #61c554;
}

.shot-title {
	margin-left: 6px;
	font-family: var(--vp-font-family-mono);
	font-size: 11.5px;
	color: var(--vp-c-text-2);
}

.shot-img {
	display: block;
	width: 100%;
	height: auto;
	margin: 0 auto;
}

.shot-caption {
	padding: 10px 14px;
	border-top: 1px solid var(--vp-c-divider);
	font-size: 13px;
	line-height: 1.5;
	color: var(--vp-c-text-2);
	text-align: center;
}
</style>
