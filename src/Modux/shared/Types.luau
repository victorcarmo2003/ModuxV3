--!strict
local Manifest = require(script.Parent.Manifest)

export type ControllerKey = keyof<Manifest.AllControllers>
export type ServiceKey = keyof<Manifest.AllServices>
export type ComponentKey = keyof<Manifest.AllComponents>

export type RegistryEntry = {
	ID: string,
	Class: any,
	Dependency: { string },
	Priority: number,
}

export type ClassesRegistry = {
	Controller: { RegistryEntry },
	Service: { RegistryEntry },
	Component: { RegistryEntry },
}

-- O `self` do controller ja vem montado do Manifest: Type.luau + Dependencies
export type ControllerSelf<ID> = index<Manifest.AllControllers, ID>

--[[
Base alcancada por `__index`, o `self` externo e `any` de proposito: o tipo
exato seria recursivo atraves do `setmetatable` e type function nao fecha
recursao, o `self` do callback e exato, que e o que importa
]]
export type ControllerBase<ID> = {
	GetComponent: (self: any) -> (),
	CreateComponent: (self: any) -> (),
	OnTick: (self: any, callback: (self: ControllerSelf<ID>) -> (), frequency: number?) -> (),
	OnInit: (self: any, callback: (self: ControllerSelf<ID>) -> ()) -> (),
	OnStart: (self: any, callback: (self: ControllerSelf<ID>) -> ()) -> (),
}

-- `setmetatable<T, { __index: Base }>` e a unica forma que nao sela a tabela (fica em read-only se eu não fizer isso) `T & Base` sela e da `Cannot add property`
export type ControllerReturn<ID> = setmetatable<ControllerSelf<ID>, { __index: ControllerBase<ID> }>

return {}
