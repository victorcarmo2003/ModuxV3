--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Runtime = require(ReplicatedStorage.shared.Modux.Classes)
local Registry = require(ReplicatedStorage.shared.Modux.Classes.Registry)
local Core = require(ReplicatedStorage.shared.Modux.Core)
local Types = require(script.Types)
local Modules = require(script.Modules)

export type Settings = Core.Settings

const Modux = {}

Modux._registry = {
	Controller = {} :: Registry.Store,
}

Modux._templates = {
	Component = {} :: Registry.Templates,
}

Modux._settings = {} :: Settings

function Modux.Controller<ID, P>(
	id: ID & Types.ControllerKey,
	props: (P | Types.ControllerProps)?
): Types.ControllerReturn<ID, P>
	const p = ((props :: any) or {}) :: Types.ControllerProps
	return Registry.register(
			"Controller",
			Runtime.Controller,
			Modux._registry.Controller,
			(id :: any) :: string,
			p
		) :: any
end

function Modux.Component<ID, P>(id: ID & Types.ComponentKey, props: (P | Types.ComponentProps)?): Types.ComponentReturn<ID, P>
	const p = ((props :: any) or {}) :: Types.ComponentProps
	return Registry.template(
			"Component",
			Runtime.Component,
			Modux._templates.Component,
			(id :: any) :: string,
			p
		) :: any
end

function Modux.Configure(settings: Settings)
	Modux._settings = settings
end

function Modux.Start()
	Core.Start({ Modux._registry.Controller }, Modux._templates.Component, Modules, Modux._settings)
end

function Modux.Stop()
	Core.Stop()
end

return Modux
