local StarterPlayer = game:GetService("StarterPlayer")
local ClassTyped = require(StarterPlayer.StarterPlayerScripts.client.Modux.ClassTyped)
local PlayerTyped = require(StarterPlayer.StarterPlayerScripts.client.Modux.PlayerTyped)

--> Adicionar abaixo os types
local Manifest = {
    Controller = {
        ["ClassTyped"] = ClassTyped,
        ["PlayerTyped"] = PlayerTyped
	},
	Service = {},
	Component = {},
}

--> ======== IGNORE ========
local types = require(script.types)
type AllControllers = typeof(Manifest.Controller)
type AllServices = typeof(Manifest.Service)
type AllComponents = typeof(Manifest.Component)

export type ControllerKeys = keyof<AllControllers> | { keyof<AllControllers> }
export type ServiceKeys = keyof<AllServices> | { keyof<AllControllers> }
export type ComponentKeys = keyof<AllComponents> | { keyof<AllControllers> }

local function getTargetClass<T>(ID: T & ControllerKeys): types.getList<AllControllers, T>
    return {} :: any
end

local required = getTargetClass({"ClassTyped", "PlayerTyped"})

return Manifest