--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Registry = require(ReplicatedStorage.shared.Modux.Classes.Registry)
local Utils = require(ReplicatedStorage.shared.Utils)

export type Store = Registry.Store

-- Core always fills this in, so nothing here is optional. Leaving `Profile`
-- optional made `{ Profile: boolean }` fail to pass as `{ Profile: boolean? }`,
-- which is table invariance, not a mistake at the call site.
export type Options = {
	Profile: boolean,
}

export type Tick = {
	instance: any,
	callback: (any, number) -> (),
	period: number,
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
			instance.Utils = Utils
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
	profile: boolean
)
	for _, callback in callbacks do
		if profile then
			debug.profilebegin(`Modux.{phase}.{label}`)
		end
		const ok, err = pcall(callback, object)
		if profile then
			debug.profileend()
		end
		if not ok then
			warn(`[Modux] {phase} of "{label}" errored: {err}`)
		end
	end
end

local function fire(entries: { Registry.Entry }, phase: "OnInit" | "OnStart", profile: boolean)
	for _, entry in entries do
		const instance = entry.Class :: any
		Loader.invoke(instance, instance._registry[phase], phase, entry.ID, profile)
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
					local ok, err = pcall(tick.callback, tick.instance, delta)
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
function Loader.addTicks(instance: any, ticks: { { callback: (any, number) -> (), frequency: number } }): TickHandle
	const handle: TickHandle = {}
	for _, tick in ticks do
		const row: Tick = {
			instance = instance,
			callback = tick.callback,
			period = 1 / math.max(tick.frequency, 0.001),
			elapsed = 0,
			dead = false,
		}
		table.insert(ticking, row)
		table.insert(handle, row)
	end
	if #ticks > 0 then
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
		Loader.addTicks(instance, instance._registry.OnTick)
	end
end

local loadOne = require :: (ModuleScript) -> any

local function loadModules(moduleScripts: { ModuleScript })
	for _, moduleScript in moduleScripts do
		loadOne(moduleScript)
	end
end

-- Split from run on purpose. Between the two, every singleton exists and has
-- its dependencies, but nothing has booted yet, which is the only window where
-- the ComponentManager can be handed the same map and still be usable from
-- inside a Controller's OnStart.
function Loader.prepare(stores: { Store }, moduleScripts: { ModuleScript }?): { [string]: Registry.Entry }
	if started then
		error("[Modux] Start was already called")
	end
	started = true

	if moduleScripts then
		loadModules(moduleScripts)
	end

	const byId = indexById(stores)
	inject(stores, byId)
	return byId
end

function Loader.run(stores: { Store }, options: Options?)
	if not started then
		error("[Modux] Loader.prepare must run before Loader.run")
	end

	const entries = ordered(stores)
	const profile = (options and options.Profile) == true

	fire(entries, "OnInit", profile)
	fire(entries, "OnStart", profile)

	collectTicks(entries)
end

function Loader.stop()
	if heartbeat then
		heartbeat:Disconnect()
		heartbeat = nil
	end
	table.clear(ticking)
	buryCount = 0
	started = false
end

return Loader
