--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Runtime = require(ReplicatedStorage.shared.Modux.Classes)
local Registry = require(ReplicatedStorage.shared.Modux.Classes.Registry)
local Core = require(ReplicatedStorage.shared.Modux)
local Types = require(script.Types)

export type Settings = {
	LogLevel: ("none" | "error" | "warn" | "info")?,
	TickRate: number?,
}

const Modux = {}

Modux._registry = {
	Service = {} :: Registry.Store,
	Component = {} :: Registry.Store,
}

Modux._settings = {} :: Settings

function Modux.Service<ID, P>(id: ID & Types.ServiceKey, props: P?): Types.ServiceReturn<ID>
	return Registry.register("Service", Runtime.Service, Modux._registry.Service, (id :: any) :: string, props) :: any
end

function Modux.Component<ID, P>(id: ID & Types.ComponentKey, props: P?): Types.ComponentReturn<ID>
	return Registry.register("Component", Runtime.Component, Modux._registry.Component, (id :: any) :: string, props) :: any
end

function Modux.Configure(settings: Settings)
	Modux._settings = settings
end

function Modux.Start()
	Core.Start()
end

return Modux
