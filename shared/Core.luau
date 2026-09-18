--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ComponentManager = require(ReplicatedStorage.shared.Modux.ComponentManager)
local Loader = require(ReplicatedStorage.shared.Modux.Loader)
local Registry = require(ReplicatedStorage.shared.Modux.Classes.Registry)

export type Settings = {
	LogLevel: ("none" | "error" | "warn" | "info")?,
	Profile: boolean?,
	TickRate: number?,
}

const Core = {}

function Core.Start(
	stores: { Loader.Store },
	templates: Registry.Templates,
	moduleScripts: { ModuleScript }?,
	settings: Settings?
)
	const s = (settings or {}) :: Settings
	const options = {
		Profile = s.Profile == true,
	}

	-- Four steps because two different orderings have to hold at once.
	--
	-- Tag-driven construction happens last: nobody asked for a component to be
	-- built at a particular moment, so it must not be built before the
	-- Controller or Service it depends on has started.
	--
	-- An explicit Create is the opposite. It says build this now, and a
	-- Controller's OnStart is exactly where that gets called, so the manager
	-- has to be usable before the Loader fires anything.
	const byId = Loader.prepare(stores, moduleScripts)
	ComponentManager.prepare(templates, byId, options)
	Loader.run(stores, options)
	ComponentManager.start()
end

function Core.Stop()
	ComponentManager.stop()
	Loader.stop()
end

return Core
