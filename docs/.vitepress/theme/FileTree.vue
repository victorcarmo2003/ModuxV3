<script setup lang="ts">
import { computed } from "vue"

const props = withDefaults(
	defineProps<{
		paths: string[]
		title?: string
	}>(),
	{ title: "FILE SYSTEM" }
)

type Row = {
	name: string
	depth: number
	dir: boolean
	note?: string
	key: string
}

// Uma lista achatada, ja na ordem de leitura. A arvore existe so enquanto e
// construida: renderizar recursivamente exigiria um componente por nivel, e o
// unico dado que a linha precisa e a profundidade.
const rows = computed<Row[]>(() => {
	const out: Row[] = []
	const seen = new Set<string>()

	for (const raw of props.paths) {
		const [pathPart, notePart] = raw.split("#").map((s) => s.trim())
		const segments = pathPart.split("/").filter(Boolean)
		const isDir = pathPart.endsWith("/")

		segments.forEach((name, i) => {
			const key = segments.slice(0, i + 1).join("/")
			if (seen.has(key)) return
			seen.add(key)

			const last = i === segments.length - 1
			out.push({
				name,
				depth: i,
				dir: !last || isDir,
				note: last ? notePart : undefined,
				key,
			})
		})
	}

	return out
})
</script>

<template>
	<div class="ft">
		<div class="ft-head">
			<span class="ft-prompt">&gt;_</span>
			<span class="ft-title">{{ title }}</span>
		</div>

		<div class="ft-body">
			<div
				v-for="row in rows"
				:key="row.key"
				class="ft-row"
				:style="{ paddingLeft: `${row.depth * 1.4}rem` }"
			>
				<svg
					v-if="row.dir"
					class="ft-icon ft-dir"
					viewBox="0 0 16 16"
					aria-hidden="true"
				>
					<path
						fill="currentColor"
						d="M1.5 3.5A1.5 1.5 0 0 1 3 2h3.2c.5 0 .97.25 1.25.67L8.1 3.7H13a1.5 1.5 0 0 1 1.5 1.5v7A1.5 1.5 0 0 1 13 13.7H3a1.5 1.5 0 0 1-1.5-1.5v-8.7Z"
					/>
				</svg>
				<svg v-else class="ft-icon ft-file" viewBox="0 0 16 16" aria-hidden="true">
					<path
						fill="currentColor"
						d="M4 1.5h5l3.5 3.5v9A1 1 0 0 1 11.5 15h-7a1 1 0 0 1-1-1V2.5a1 1 0 0 1 1-1Z"
						opacity=".55"
					/>
					<path fill="currentColor" d="M9 1.5 12.5 5H9.6A.6.6 0 0 1 9 4.4V1.5Z" />
				</svg>

				<span :class="row.dir ? 'ft-name-dir' : 'ft-name-file'">{{ row.name }}</span>
				<span v-if="row.note" class="ft-note">{{ row.note }}</span>
			</div>
		</div>
	</div>
</template>

<style scoped>
.ft {
	margin: 20px 0;
	border: 1px solid var(--vp-c-divider);
	border-radius: 10px;
	overflow: hidden;
	background: var(--vp-c-bg-alt);
	font-family: var(--vp-font-family-mono);
}

.ft-head {
	display: flex;
	align-items: center;
	gap: 8px;
	padding: 10px 14px;
	border-bottom: 1px solid var(--vp-c-divider);
	background: var(--vp-c-bg-soft);
}

.ft-prompt {
	color: var(--vp-c-brand-1);
	font-weight: 700;
	font-size: 12px;
}

.ft-title {
	font-size: 11px;
	letter-spacing: 0.1em;
	color: var(--vp-c-text-2);
	text-transform: uppercase;
}

.ft-body {
	padding: 14px 16px;
	overflow-x: auto;
}

.ft-row {
	display: flex;
	align-items: center;
	gap: 8px;
	line-height: 1.9;
	font-size: 13px;
	white-space: nowrap;
}

.ft-icon {
	width: 15px;
	height: 15px;
	flex-shrink: 0;
}

/* Amarelo e azul aguentam os dois temas sem virar outra cor: sao os unicos
   dois acentos aqui, entao nao competem com o brand do VitePress. */
.ft-dir {
	color: #d9a441;
}

.ft-file {
	color: #6ba7e8;
}

.ft-name-dir {
	color: var(--vp-c-text-1);
	font-weight: 600;
}

.ft-name-file {
	color: var(--vp-c-text-2);
}

.ft-note {
	margin-left: 6px;
	padding: 1px 7px;
	border-radius: 20px;
	font-size: 10.5px;
	letter-spacing: 0.03em;
	color: var(--vp-c-text-3);
	background: var(--vp-c-default-soft);
}

@media (max-width: 640px) {
	.ft-row {
		font-size: 12px;
	}
}
</style>
