--!strict
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Loader = require(ReplicatedStorage.shared.Modux.Loader)
local Registry = require(ReplicatedStorage.shared.Modux.Classes.Registry)
local Utils = require(ReplicatedStorage.shared.Utils)

export type Options = Loader.Options

type Live = {
	object: any,
	ticks: Loader.TickHandle,
}

const ComponentManager = {}

local templates: Registry.Templates = {}
local options: Options = { Profile = false }
local connections: { RBXScriptConnection } = {}
local prepared = false

-- Weak keys on purpose. The strong reference to a component object is the
-- Instance being in the DataModel; once it is destroyed and nothing else holds
-- it, the entry should go with it. That way a removal signal that never
-- arrives costs nothing permanent.
local live: { [string]: { [Instance]: Live } } = {}

local function slot(id: string): { [Instance]: Live }
	local bucket = live[id]
	if bucket == nil then
		bucket = setmetatable({}, { __mode = "k" }) :: any
		live[id] = bucket
	end
	return bucket
end

local function construct(template: Registry.Template, instance: Instance): any
	const bucket = slot(template.ID)
	const existing = bucket[instance]
	if existing ~= nil then
		return existing.object
	end

	const object = setmetatable({
		Instance = instance,
	}, { __index = template.Class })

	const registry = template.Class._registry
	bucket[instance] = {
		object = object,
		ticks = Loader.addTicks(object, registry.OnTick),
	}

	const label = `{template.ID}@{instance.Name}`
	Loader.invoke(object, registry.OnInit, "OnInit", label, options.Profile)
	Loader.invoke(object, registry.OnStart, "OnStart", label, options.Profile)

	return object
end

local function teardown(template: Registry.Template, instance: Instance)
	const bucket = slot(template.ID)
	const entry = bucket[instance]
	if entry == nil then
		return
	end
	bucket[instance] = nil

	Loader.removeTicks(entry.ticks)
	Loader.invoke(
		entry.object,
		template.Class._registry.OnDestroy,
		"OnDestroy",
		`{template.ID}@{instance.Name}`,
		options.Profile
	)
end

local function ordered(): { Registry.Template }
	const all = {}
	for _, template in templates do
		table.insert(all, template)
	end
	table.sort(all, function(a: Registry.Template, b: Registry.Template)
		if a.Priority ~= b.Priority then
			return a.Priority > b.Priority
		end
		return a.ID < b.ID
	end)
	return all
end

-- The runtime half of Manifest.ComponentAccess: one entry per declared
-- component, so `self.Components.Whatever:Get(instance)` needs no id string
-- and no generic. Built once and shared; the accessor holds the id in a
-- closure, so the `self` these take is the accessor table and goes unused.
local function accessTable(): { [string]: any }
	const access = {}
	for id in templates do
		access[id] = {
			Get = function(_: any, instance: Instance): any?
				return ComponentManager.get(id, instance)
			end,
			Create = function(_: any, instance: Instance): any
				return ComponentManager.create(id, instance)
			end,
			All = function(_: any): { any }
				return ComponentManager.all(id)
			end,
		}
	end
	return access
end

-- Dependencies land here, before anything boots, so that an explicit Create
-- from inside a Controller's OnStart finds a usable manager.
function ComponentManager.prepare(
	declared: Registry.Templates,
	byId: { [string]: Registry.Entry },
	opts: Options
)
	if prepared then
		error("[Modux] Start was already called")
	end
	prepared = true
	templates = declared
	options = opts

	const access = accessTable()

	for _, template in templates do
		const class = template.Class :: any
		class.Dependencies = Loader.resolve(template.ID, template.Dependency, byId)
		class.Utils = Utils
		class.Components = access
	end

	-- Singletons were injected by Loader.prepare, which ran before this and
	-- could not know about components.
	for _, entry in byId do
		const class = entry.Class :: any
		class.Components = access
	end
end

-- Tag binding waits until every Controller and Service has started, so a
-- component nobody asked for by name cannot come up before what it depends on.
function ComponentManager.start()
	if not prepared then
		error("[Modux] ComponentManager.prepare must run before ComponentManager.start")
	end

	for _, template in ordered() do
		table.insert(
			connections,
			CollectionService:GetInstanceAddedSignal(template.Tag):Connect(function(instance: Instance)
				construct(template, instance)
			end)
		)
		table.insert(
			connections,
			CollectionService:GetInstanceRemovedSignal(template.Tag):Connect(function(instance: Instance)
				teardown(template, instance)
			end)
		)

		for _, instance in CollectionService:GetTagged(template.Tag) do
			construct(template, instance)
		end
	end
end

local function templateFor(id: string): Registry.Template
	const template = templates[id]
	if template == nil then
		const available = {}
		for other in templates do
			table.insert(available, other)
		end
		table.sort(available)
		error(`[Modux] "{id}" is not a registered Component. Registered: {table.concat(available, ", ")}`)
	end
	return template
end

-- Builds before tagging, which is the whole point of having this rather than
-- calling AddTag yourself. With SignalBehavior set to Deferred, AddTag does not
-- reach GetInstanceAddedSignal until the next resumption point, so tagging and
-- then reading the object back needs a wait, a Promise, or a guess. Building
-- first makes the object available on this line, and the signal that arrives
-- later finds it already there and does nothing.
function ComponentManager.create(id: string, instance: Instance): any
	const template = templateFor(id)
	const object = construct(template, instance)
	if not CollectionService:HasTag(instance, template.Tag) then
		CollectionService:AddTag(instance, template.Tag)
	end
	return object
end

function ComponentManager.get(id: string, instance: Instance): any?
	const entry = slot(templateFor(id).ID)[instance]
	return if entry ~= nil then entry.object else nil
end

function ComponentManager.all(id: string): { any }
	const out = {}
	for _, entry in slot(templateFor(id).ID) do
		table.insert(out, entry.object)
	end
	return out
end

function ComponentManager.destroy(id: string, instance: Instance)
	const template = templateFor(id)
	teardown(template, instance)
	if CollectionService:HasTag(instance, template.Tag) then
		CollectionService:RemoveTag(instance, template.Tag)
	end
end

function ComponentManager.stop()
	for _, connection in connections do
		connection:Disconnect()
	end
	table.clear(connections)

	for id, bucket in live do
		const template = templates[id]
		if template ~= nil then
			for instance in bucket do
				teardown(template, instance)
			end
		end
	end
	table.clear(live)

	templates = {}
	prepared = false
end

return ComponentManager
