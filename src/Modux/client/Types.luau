--!strict
local Manifest = require(script.Parent.Manifest)

export type ControllerKey = keyof<Manifest.AllControllers>
export type ComponentKey = keyof<Manifest.AllComponents>

export type ControllerSelf<ID> = index<Manifest.AllControllers, ID>
export type ComponentSelf<ID> = index<Manifest.AllComponents, ID>

export type ControllerBase<ID> = {
	GetComponent: (self: any) -> (),
	CreateComponent: (self: any) -> (),
	OnTick: (self: any, callback: (self: ControllerSelf<ID>) -> (), frequency: number?) -> (),
	OnInit: (self: any, callback: (self: ControllerSelf<ID>) -> ()) -> (),
	OnStart: (self: any, callback: (self: ControllerSelf<ID>) -> ()) -> (),
}

export type ComponentBase<ID> = {
	GetComponent: (self: any) -> (),
	CreateComponent: (self: any) -> (),
	OnTick: (self: any, callback: (self: ComponentSelf<ID>) -> (), frequency: number?) -> (),
	OnInit: (self: any, callback: (self: ComponentSelf<ID>) -> ()) -> (),
	OnStart: (self: any, callback: (self: ComponentSelf<ID>) -> ()) -> (),
}

export type ControllerReturn<ID> = setmetatable<ControllerSelf<ID>, { __index: ControllerBase<ID> }>
export type ComponentReturn<ID> = setmetatable<ComponentSelf<ID>, { __index: ComponentBase<ID> }>

return {}
