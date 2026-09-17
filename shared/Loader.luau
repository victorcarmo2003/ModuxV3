--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Registry = require(ReplicatedStorage.shared.Modux.Classes.Registry)
local Utils = require(ReplicatedStorage.shared.Utils)

export type Store = Registry.Store

export type Options = {
	Profile: boolean?,
}

local Loader = {}

local started = false
local ticking: { { instance: any, callback: (any) -> (), period: number, elapsed: number } } = {}
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

local function inject(stores: { Store }, byId: { [string]: Registry.Entry })
	for _, store in stores do
		for _, entry in store do
			local dependencies = {}
			for _, id in entry.Dependency do
				local target = byId[id]
				if target == nil then
					local available = {}
					for other in byId do
						table.insert(available, other)
					end
					table.sort(available)
					error(
						`[Modux] "{entry.ID}" requires "{id}", which is not registered. `
							.. `Registered: {table.concat(available, ", ")}`
					)
				end
				dependencies[id] = target.Class
			end

			local instance = entry.Class :: any
			instance.Dependencies = dependencies
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

local function fire(entries: { Registry.Entry }, phase: "OnInit" | "OnStart", profile: boolean)
	for _, entry in entries do
		local instance = entry.Class :: any
		local callbacks = instance._registry[phase]
		for _, callback in callbacks do
			if profile then
				debug.profilebegin(`Modux.{phase}.{entry.ID}`)
			end
			local ok, err = pcall(callback, instance)
			if profile then
				debug.profileend()
			end
			if not ok then
				warn(`[Modux] {phase} of "{entry.ID}" errored: {err}`)
			end
		end
	end
end

local function collectTicks(entries: { Registry.Entry })
	for _, entry in entries do
		local instance = entry.Class :: any
		for _, tick in instance._registry.OnTick do
			table.insert(ticking, {
				instance = instance,
				callback = tick.callback,
				period = 1 / math.max(tick.frequency, 0.001),
				elapsed = 0,
			})
		end
	end
end

local function startClock()
	if #ticking == 0 then
		return
	end
	heartbeat = RunService.Heartbeat:Connect(function(delta: number)
		for _, tick in ticking do
			tick.elapsed += delta
			if tick.elapsed >= tick.period then
				tick.elapsed -= tick.period
				local ok, err = pcall(tick.callback, tick.instance, delta)
				if not ok then
					warn(`[Modux] OnTick errored: {err}`)
				end
			end
		end
	end)
end

local loadOne = require :: (ModuleScript) -> any

local function loadModules(moduleScripts: { ModuleScript })
	for _, moduleScript in moduleScripts do
		loadOne(moduleScript)
	end
end

function Loader.start(stores: { Store }, moduleScripts: { ModuleScript }?, options: Options?)
	if started then
		error("[Modux] Start was already called")
	end
	started = true

	if moduleScripts then
		loadModules(moduleScripts)
	end

	local byId = indexById(stores)
	inject(stores, byId)

	local entries = ordered(stores)
	local profile = (options and options.Profile) == true
	fire(entries, "OnInit", profile)
	fire(entries, "OnStart", profile)

	collectTicks(entries)
	startClock()
end

function Loader.stop()
	if heartbeat then
		heartbeat:Disconnect()
		heartbeat = nil
	end
	table.clear(ticking)
	started = false
end

return Loader
