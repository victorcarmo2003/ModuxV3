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
	Controller = {} :: Registry.Store,
	Component = {} :: Registry.Store,
}

Modux._settings = {} :: Settings

function Modux.Controller<ID, P>(id: ID & Types.ControllerKey, props: P?): Types.ControllerReturn<ID>
	return Registry.register("Controller", Runtime.Controller, Modux._registry.Controller, (id :: any) :: string, props) :: any
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
