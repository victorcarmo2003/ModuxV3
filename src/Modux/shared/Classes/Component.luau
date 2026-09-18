--!strict
const Component = {}
Component.__index = Component

export type Registry = {
	OnInit: { (any) -> () },
	OnStart: { (any) -> () },
	OnDestroy: { (any) -> () },
	OnTick: { { callback: (any) -> (), frequency: number } },
}

function Component:CreateComponent() end

function Component:GetComponent() end

function Component:OnTick(callback, frequency: number?)
	const onTickList = self._registry.OnTick
	if type(callback) ~= "function" then
		error(`[OnTick] Must be callback function, got {type(callback)}`)
	end
	table.insert(onTickList, {
		callback = callback,
		frequency = frequency or 1,
	})
end

function Component:OnInit(callback)
	const onInitList = self._registry.OnInit
	if type(callback) ~= "function" then
		error(`[OnInit] Must be callback function, got {type(callback)}`)
	end
	table.insert(onInitList, callback)
end

function Component:OnStart(callback)
	const onStartList = self._registry.OnStart
	if type(callback) ~= "function" then
		error(`[OnStart] Must be callback function, got {type(callback)}`)
	end
	table.insert(onStartList, callback)
end

-- Only Component has this. A Controller or a Service is a singleton and lives
-- as long as the session; a component object goes away whenever its tag is
-- removed or its Instance is destroyed.
function Component:OnDestroy(callback)
	const onDestroyList = self._registry.OnDestroy
	if type(callback) ~= "function" then
		error(`[OnDestroy] Must be callback function, got {type(callback)}`)
	end
	table.insert(onDestroyList, callback)
end

function Component.New()
	return setmetatable({
		_registry = {
			OnInit = {},
			OnStart = {},
			OnDestroy = {},
			OnTick = {},
		} :: Registry,
	}, { __index = Component })
end

return Component
