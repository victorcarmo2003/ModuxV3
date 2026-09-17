--!strict
local FSM = require(script.FSM)
local Promise = require(script.Promise)
local Signal = require(script.Signal)

export type Api = {
	FSM: FSM.Api,
	Promise: Promise.PromiseAPI,
	Signal: Signal.Api,
}

const Utils = {
	FSM = FSM,
	Promise = Promise,
	Signal = Signal,
}

return Utils :: Api
