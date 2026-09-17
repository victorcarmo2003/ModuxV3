--!strict
const Controller = {}
Controller.__index = Controller

export type Registry = {
	OnInit: { (any) -> () },
	OnStart: { (any) -> () },
	OnTick: { { callback: (any) -> (), frequency: number } },
}

-- It creates a new component for you and it returns the target component
function Controller:CreateComponent() end

function Controller:GetComponent() end

-- OnTick is a callback register that runs at 1hz or the specified in frequency.
function Controller:OnTick(callback, frequency: number?)
	const onTickList = self._registry.OnTick
	if type(callback) ~= "function" then
		error(`[OnTick] Must be callback function, got {type(callback)}`)
	end
	table.insert(onTickList, {
		callback = callback,
		frequency = frequency or 1,
	})
end

-- OnInit is a callback register called first when the module is loaded
function Controller:OnInit(callback)
	const onInitList = self._registry.OnInit
	if type(callback) ~= "function" then
		error(`[OnInit] Must be callback function, got {type(callback)}`)
	end
	table.insert(onInitList, callback)
end

-- OnStart is a callback register called after Init
function Controller:OnStart(callback)
	const onStartList = self._registry.OnStart
	if type(callback) ~= "function" then
		error(`[OnStart] Must be callback function, got {type(callback)}`)
	end
	table.insert(onStartList, callback)
end

-- It creates a new Controller class.
-- O registry nasce POR INSTANCIA. Enquanto morava em `Controller._registry`,
-- todo controller resolvia pelo `__index` e empilhava na mesma lista.
function Controller.New()
	return setmetatable({
		_registry = {
			OnInit = {},
			OnStart = {},
			OnTick = {},
		} :: Registry,
	}, { __index = Controller })
end

return Controller
