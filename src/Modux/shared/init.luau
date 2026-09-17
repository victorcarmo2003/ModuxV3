const ReplicatedStorage = game:GetService("ReplicatedStorage")
const Occlude = require(ReplicatedStorage.shared.Types.Occlude)
const ComponentManager = require(script.ComponentManager)
const Classes = require(script.Classes)
local Loader = require(script.Loader)
const Modux = {}

function Modux.Start() end

const public = {
	Controller = Classes.Controller,
	Service = Classes.Service,
	Component = Classes.Component,
}
return table.freeze(public) :: Occlude.Keys<typeof(public), "Dependencies">
