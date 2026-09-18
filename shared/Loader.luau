--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Registry = require(ReplicatedStorage.shared.Modux.Classes.Registry)
local Libs = require(ReplicatedStorage.shared.Modux.Libs)

export type Store = Registry.Store

export type DebugLevel = "Low" | "Medium" | "High"

-- Core always fills these in, so nothing here is optional. Leaving a field
-- optional made `{ Profiling: boolean }` fail to pass as
-- `{ Profiling: boolean? }`, which is table invariance, not a mistake at the
-- call site. Debug is a value, not an absent field: "None" means quiet.
export type Options = {
	Profiling: boolean,
	Debug: DebugLevel | "None",
}

-- O aviso de lentidao existe em todo nivel; o que muda e o que conta como
-- lento. Em Low so o que derruba varios frames aparece; em High qualquer
-- coisa acima de um milissegundo, que e o nivel de quem esta cacando.
local LIMITE: { [string]: number } = {
	None = math.huge,
	Low = 100,
	Medium = 1000 / 60,
	High = 1,
}

export type Tick = {
	instance: any,
	label: string,
	callback: (any, number) -> (),
	period: number,
	priority: number,
	seq: number,
	elapsed: number,
	dead: boolean,
}

-- Holds the rows it owns, rather than being an identity the removal has to go
-- looking for. Scanning the whole list per removal made tearing down N
-- components O(N^2): destroying an area with a thousand tagged instances spent
-- a million iterations finding rows it was already holding.
export type TickHandle = { Tick }

local Loader = {}

local started = false
local inicioDoBoot = 0
local proximaSeq = 0
-- O clock e uma conexao unica criada uma vez; ele nao recebe options por
-- parametro, entao elas ficam aqui.
local opcoes: Options = { Profiling = false, Debug = "None" }
local modulosCarregados = 0
local porModulo: { { nome: string, ms: number } } = {}
local ticking: { Tick } = {}
local buryCount = 0
local heartbeat: RBXScriptConnection? = nil

local function indexById(stores: { Store }): { [string]: Registry.Entry }
	local byId = {}
	for _, store in stores do
		for _, entry in store do
			byId[entry.ID] = entry
		end
	end
	return byId
end

-- Shared with the ComponentManager, which resolves the same way from the same
-- map. Keeping it here keeps the "not registered" message single-sourced.
function Loader.resolve(
	owner: string,
	dependency: { string },
	byId: { [string]: Registry.Entry }
): { [string]: any }
	const dependencies = {}
	for _, id in dependency do
		const target = byId[id]
		if target == nil then
			const available = {}
			for other in byId do
				table.insert(available, other)
			end
			table.sort(available)
			error(
				`[Modux] "{owner}" requires "{id}", which is not registered. `
					.. `Registered: {table.concat(available, ", ")}`
			)
		end
		dependencies[id] = target.Class
	end
	return dependencies
end

local function inject(stores: { Store }, byId: { [string]: Registry.Entry })
	for _, store in stores do
		for _, entry in store do
			const instance = entry.Class :: any
			instance.Dependencies = Loader.resolve(entry.ID, entry.Dependency, byId)
			instance.Libs = Libs
		end
	end
end

local function ordered(stores: { Store }): { Registry.Entry }
	local all = {}
	for _, store in stores do
		for _, entry in store do
			table.insert(all, entry)
		end
	end
	table.sort(all, function(a: Registry.Entry, b: Registry.Entry)
		if a.Priority ~= b.Priority then
			return a.Priority > b.Priority
		end
		return a.ID < b.ID
	end)
	return all
end

-- Shared with the ComponentManager, which runs the same phases against an
-- object rather than a singleton. One callback erroring must never take the
-- others down, so each is its own pcall.
function Loader.invoke(
	object: any,
	callbacks: { (any) -> () },
	phase: string,
	label: string,
	options: Options
)
	const limite = LIMITE[options.Debug] or math.huge
	for _, callback in callbacks do
		-- Categoria de memoria e o par do profilebegin: um aparece no
		-- MicroProfiler, o outro na aba de memoria do Developer Console e no
		-- Stats:GetMemoryUsageMbForTag. Sem isso tudo que o framework aloca
		-- cai num balde so e nao da para saber de qual modulo veio.
		--
		-- Guarda e restaura em vez de resetmemorycategory: invoke aninha - um
		-- OnStart de Controller pode criar componente, que invoca de novo - e
		-- o reset voltaria para o padrao do script, perdendo a categoria de
		-- fora.
		local categoriaAnterior: string? = nil
		if options.Profiling then
			debug.profilebegin(`Modux.{phase}.{label}`)
			categoriaAnterior = debug.getmemorycategory()
			debug.setmemorycategory(`Modux.{label}`)
		end
		const inicio = os.clock()
		const ok, err = pcall(callback, object)
		const ms = (os.clock() - inicio) * 1000
		if options.Profiling then
			if categoriaAnterior ~= nil then
				debug.setmemorycategory(categoriaAnterior)
			end
			debug.profileend()
		end
		if not ok then
			warn(`[Modux] {phase} of "{label}" errored: {err}`)
		elseif ms > limite then
			warn(`[Modux] {phase} of "{label}" took {string.format("%.1f", ms)} ms`)
		end
	end
end

local function fire(entries: { Registry.Entry }, phase: "OnInit" | "OnStart", options: Options)
	for _, entry in entries do
		const instance = entry.Class :: any
		Loader.invoke(instance, instance._registry[phase], phase, entry.ID, options)
	end
end

local function bury()
	if buryCount == 0 then
		return
	end
	local alive = {}
	for _, tick in ticking do
		if not tick.dead then
			table.insert(alive, tick)
		end
	end
	ticking = alive
	buryCount = 0
end

-- The clock connects on the first tick registered, not at boot. Components are
-- born and die while the game runs, so there is no moment at which the set of
-- tick callbacks is known and final.
local function ensureClock()
	if heartbeat ~= nil then
		return
	end
	heartbeat = RunService.Heartbeat:Connect(function(delta: number)
		bury()
		for _, tick in ticking do
			if not tick.dead then
				tick.elapsed += delta
				if tick.elapsed >= tick.period then
					-- Modulo, not `-= period`. A single Heartbeat after a hitch
					-- can carry a delta of a second or more; subtracting one
					-- period leaves the rest as debt, which then gets paid off
					-- by firing every frame until it drains. That turns a lag
					-- spike into a burst of catch-up ticks at exactly the
					-- moment the game can least afford them. Missed ticks are
					-- dropped; the fractional phase is kept so a normal frame
					-- still does not drift.
					tick.elapsed %= tick.period

					local categoriaAnterior: string? = nil
					if opcoes.Profiling then
						debug.profilebegin(`Modux.OnTick.{tick.label}`)
						categoriaAnterior = debug.getmemorycategory()
						debug.setmemorycategory(`Modux.{tick.label}`)
					end
					local ok, err = pcall(tick.callback, tick.instance, delta)
					if opcoes.Profiling then
						if categoriaAnterior ~= nil then
							debug.setmemorycategory(categoriaAnterior)
						end
						debug.profileend()
					end
					if not ok then
						warn(`[Modux] OnTick errored: {err}`)
					end
				end
			end
		end
	end)
end

-- A callback removed mid-frame is only marked, never spliced: the heartbeat may
-- be walking this very list, and one of the callbacks it is walking is what
-- destroys a component. Compaction happens at the top of the next frame.
function Loader.addTicks(
	instance: any,
	ticks: { { callback: (any, number) -> (), tickRate: number, priority: number } },
	label: string
): TickHandle
	const handle: TickHandle = {}
	for _, tick in ticks do
		const row: Tick = {
			instance = instance,
			label = label,
			callback = tick.callback,
			period = 1 / math.max(tick.tickRate, 0.001),
			priority = tick.priority,
			seq = proximaSeq,
			elapsed = 0,
			dead = false,
		}
		proximaSeq += 1
		table.insert(ticking, row)
		table.insert(handle, row)
	end
	if #ticks > 0 then
		-- Ordenar aqui e nao a cada frame: registrar tick e raro, percorrer a
		-- lista acontece sessenta vezes por segundo.
		--
		-- O desempate por seq nao e detalhe. table.sort nao e estavel, e sem
		-- priority declarado todo mundo fica em 1, entao sem o desempate a
		-- ordem entre iguais seria arbitraria E mudaria a cada registro novo:
		-- criar um componente embaralharia a ordem dos ticks que ja existiam,
		-- em runtime. Com seq, quem registrou antes roda antes, sempre.
		table.sort(ticking, function(a: Tick, b: Tick)
			if a.priority ~= b.priority then
				return a.priority > b.priority
			end
			return a.seq < b.seq
		end)
		ensureClock()
	end
	return handle
end

function Loader.removeTicks(handle: TickHandle)
	for _, tick in handle do
		if not tick.dead then
			tick.dead = true
			buryCount += 1
		end
	end
end

local function collectTicks(entries: { Registry.Entry })
	for _, entry in entries do
		const instance = entry.Class :: any
		Loader.addTicks(instance, instance._registry.OnTick, entry.ID)
	end
end

local loadOne = require :: (ModuleScript) -> any

-- O require domina o boot: nas medicoes ele foi ~88% do total, e o resto do
-- Loader somado deu fracao de milissegundo. Por isso o nivel High mede por
-- modulo - e o unico lugar onde vale procurar.
local function loadModules(moduleScripts: { ModuleScript }, options: Options)
	const detalhado = options.Debug == "High"
	for _, moduleScript in moduleScripts do
		if detalhado then
			const inicio = os.clock()
			loadOne(moduleScript)
			table.insert(porModulo, {
				nome = moduleScript.Name,
				ms = (os.clock() - inicio) * 1000,
			})
		else
			loadOne(moduleScript)
		end
		modulosCarregados += 1
	end
end

-- Split from run on purpose. Between the two, every singleton exists and has
-- its dependencies, but nothing has booted yet, which is the only window where
-- the ComponentManager can be handed the same map and still be usable from
-- inside a Controller's OnStart.
function Loader.prepare(
	stores: { Store },
	moduleScripts: { ModuleScript }?,
	options: Options
): { [string]: Registry.Entry }
	if started then
		error("[Modux] Start was already called")
	end
	started = true
	inicioDoBoot = os.clock()
	opcoes = options

	if moduleScripts then
		loadModules(moduleScripts, options)
	end

	const byId = indexById(stores)
	inject(stores, byId)
	return byId
end

function Loader.run(stores: { Store }, options: Options)
	if not started then
		error("[Modux] Loader.prepare must run before Loader.run")
	end

	const entries = ordered(stores)
	fire(entries, "OnInit", options)
	fire(entries, "OnStart", options)
	collectTicks(entries)

	if options.Debug ~= "None" then
		const total = (os.clock() - inicioDoBoot) * 1000
		local linha = `[Modux] boot em {string.format("%.1f", total)} ms`
		if options.Debug ~= "Low" then
			linha ..= ` | {#entries} singletons | {modulosCarregados} modulos requeridos`
		end
		print(linha)
		if options.Debug == "High" then
			for _, m in porModulo do
				print(`[Modux]   require {m.nome}: {string.format("%.2f", m.ms)} ms`)
			end
		end
	end
end

function Loader.stop()
	if heartbeat then
		heartbeat:Disconnect()
		heartbeat = nil
	end
	table.clear(ticking)
	table.clear(porModulo)
	proximaSeq = 0
	buryCount = 0
	modulosCarregados = 0
	started = false
end

return Loader
