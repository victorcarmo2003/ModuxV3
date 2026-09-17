--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Loader = require(ReplicatedStorage.shared.Modux.Loader)

export type Settings = {
	LogLevel: ("none" | "error" | "warn" | "info")?,
	Profile: boolean?,
	TickRate: number?,
}

const Core = {}

function Core.Start(stores: { Loader.Store }, moduleScripts: { ModuleScript }?, settings: Settings?)
	const s = (settings or {}) :: Settings
	Loader.start(stores, moduleScripts, {
		Profile = s.Profile == true,
	})
end

function Core.Stop()
	Loader.stop()
end

return Core
