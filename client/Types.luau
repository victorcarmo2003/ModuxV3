--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Pick = require(ReplicatedStorage.shared.Types.Pick)
local SelfOf = require(ReplicatedStorage.shared.Types.SelfOf)
local Utils = require(ReplicatedStorage.shared.Utils)
local Manifest = require(script.Parent.Manifest)

export type ControllerKey = keyof<Manifest.AllControllers>
export type ComponentKey = keyof<Manifest.AllComponents>

export type ControllerProps = {
	Require: { ControllerKey },
	Priority: number?,
}

export type ComponentProps = {
	Require: { ComponentKey },
	Priority: number?,
	Tag: string?,
}

export type ControllerSelf<ID, P> = SelfOf.Build<
	index<Manifest.AllControllers, ID>,
	{
		Dependencies: Pick.Table<Manifest.AllControllers, SelfOf.RequireOf<P>>,
		Utils: Utils.Api,
	}
>

export type ComponentSelf<ID, P> = SelfOf.Build<
	index<Manifest.AllComponents, ID>,
	{
		Dependencies: Pick.Table<Manifest.AllComponents, SelfOf.RequireOf<P>>,
		Utils: Utils.Api,
		Instance: Instance,
	}
>

export type ControllerBase<ID, P> = {
	GetComponent: (self: any) -> (),
	CreateComponent: (self: any) -> (),
	OnTick: (self: any, callback: (self: ControllerSelf<ID, P>) -> (), frequency: number?) -> (),
	OnInit: (self: any, callback: (self: ControllerSelf<ID, P>) -> ()) -> (),
	OnStart: (self: any, callback: (self: ControllerSelf<ID, P>) -> ()) -> (),
}

export type ComponentBase<ID, P> = {
	GetComponent: (self: any) -> (),
	CreateComponent: (self: any) -> (),
	OnTick: (self: any, callback: (self: ComponentSelf<ID, P>) -> (), frequency: number?) -> (),
	OnInit: (self: any, callback: (self: ComponentSelf<ID, P>) -> ()) -> (),
	OnStart: (self: any, callback: (self: ComponentSelf<ID, P>) -> ()) -> (),
}

export type ControllerReturn<ID, P> = setmetatable<ControllerSelf<ID, P>, { __index: ControllerBase<ID, P> }>
export type ComponentReturn<ID, P> = setmetatable<ComponentSelf<ID, P>, { __index: ComponentBase<ID, P> }>

return {}
