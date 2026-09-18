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

	const byId = Loader.start(stores, moduleScripts, options)
	ComponentManager.start(templates, byId, options)
end

function Core.Stop()
	ComponentManager.stop()
	Loader.stop()
end

return Core
