--!strict
local Manifest = require(script.Parent.Manifest)

export type ServiceKey = keyof<Manifest.AllServices>
export type ComponentKey = keyof<Manifest.AllComponents>

export type ServiceSelf<ID> = index<Manifest.AllServices, ID>
export type ComponentSelf<ID> = index<Manifest.AllComponents, ID>

export type ServiceBase<ID> = {
	GetComponent: (self: any) -> (),
	CreateComponent: (self: any) -> (),
	OnTick: (self: any, callback: (self: ServiceSelf<ID>) -> (), frequency: number?) -> (),
	OnInit: (self: any, callback: (self: ServiceSelf<ID>) -> ()) -> (),
	OnStart: (self: any, callback: (self: ServiceSelf<ID>) -> ()) -> (),
}

export type ComponentBase<ID> = {
	GetComponent: (self: any) -> (),
	CreateComponent: (self: any) -> (),
	OnTick: (self: any, callback: (self: ComponentSelf<ID>) -> (), frequency: number?) -> (),
	OnInit: (self: any, callback: (self: ComponentSelf<ID>) -> ()) -> (),
	OnStart: (self: any, callback: (self: ComponentSelf<ID>) -> ()) -> (),
}

export type ServiceReturn<ID> = setmetatable<ServiceSelf<ID>, { __index: ServiceBase<ID> }>
export type ComponentReturn<ID> = setmetatable<ComponentSelf<ID>, { __index: ComponentBase<ID> }>

return {}
