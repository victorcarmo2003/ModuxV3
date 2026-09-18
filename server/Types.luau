--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Pick = require(ReplicatedStorage.shared.Types.Pick)
local SelfOf = require(ReplicatedStorage.shared.Types.SelfOf)
local Utils = require(ReplicatedStorage.shared.Utils)
local Manifest = require(script.Parent.Manifest)

export type ServiceKey = keyof<Manifest.AllServices>
export type ComponentKey = keyof<Manifest.AllComponents>

export type ServiceProps = {
	Require: { ServiceKey },
	Priority: number?,
}

export type ComponentProps = {
	Require: { ServiceKey },
	Priority: number?,
	Tag: string?,
}

export type ServiceSelf<ID, P> = SelfOf.Build<
	index<Manifest.AllServices, ID>,
	{
		Dependencies: Pick.Table<Manifest.AllServices, SelfOf.RequireOf<P>>,
		Utils: Utils.Api,
		Components: Manifest.ComponentAccess,
	}
>

export type ComponentSelf<ID, P> = SelfOf.Build<
	index<Manifest.AllComponents, ID>,
	{
		Dependencies: Pick.Table<Manifest.AllServices, SelfOf.RequireOf<P>>,
		Utils: Utils.Api,
		Components: Manifest.ComponentAccess,
		Destroy: (self: any) -> (),
	}
>

export type ServiceBase<ID, P> = {
	OnTick: (self: any, callback: (self: ServiceSelf<ID, P>) -> (), frequency: number?) -> (),
	OnInit: (self: any, callback: (self: ServiceSelf<ID, P>) -> ()) -> (),
	OnStart: (self: any, callback: (self: ServiceSelf<ID, P>) -> ()) -> (),
}

export type ComponentBase<ID, P> = {
	OnTick: (self: any, callback: (self: ComponentSelf<ID, P>) -> (), frequency: number?) -> (),
	OnInit: (self: any, callback: (self: ComponentSelf<ID, P>) -> ()) -> (),
	OnStart: (self: any, callback: (self: ComponentSelf<ID, P>) -> ()) -> (),
	OnDestroy: (self: any, callback: (self: ComponentSelf<ID, P>) -> ()) -> (),
}

export type ServiceReturn<ID, P> = setmetatable<ServiceSelf<ID, P>, { __index: ServiceBase<ID, P> }>
export type ComponentReturn<ID, P> = setmetatable<ComponentSelf<ID, P>, { __index: ComponentBase<ID, P> }>

return {}
