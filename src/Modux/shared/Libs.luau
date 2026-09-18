--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local FSM = require(ReplicatedStorage.shared.Libs.FSM)
local Promise = require(ReplicatedStorage.shared.Libs.Promise)
local Signal = require(ReplicatedStorage.shared.Libs.Signal)

export type Api = {
	FSM: typeof(FSM),
	Promise: typeof(Promise),
	Signal: typeof(Signal),
}

return {
	FSM = FSM,
	Promise = Promise,
	Signal = Signal,
} :: Api
