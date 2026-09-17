--!strict
local Registry = require(script.Parent.Classes.Registry)

export type RegistryEntry = Registry.Entry

export type ClassesRegistry = {
	Controller: Registry.Store,
	Service: Registry.Store,
	Component: Registry.Store,
}

return {}
