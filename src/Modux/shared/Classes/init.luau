--!strict
const Controller = require(script.Controller)
const Component = require(script.Component)
const Service = require(script.Service)
local Types = require(script.Parent.Types)

-- Require aceita nada, uma string, ou um array de strings.
local function normalizeRequire(value: any): { string }
	if value == nil then
		return {}
	end
	if type(value) == "string" then
		return { value }
	end
	if type(value) == "table" then
		return value
	end
	error(`[Modux - Classes] Require deve ser string ou array de strings, recebi {type(value)}`)
end

const Classes = {}
Classes._registry = {
	Controller = {},
	Service = {},
	Component = {},
} :: Types.ClassesRegistry

-- `id: ID & ControllerKey` prende a singleton do call-site. Com `|` o ID fica
-- livre e resolve para `unknown`; sem restricao alguma alarga para `string`.
-- `props` e generico e SEM restricao de proposito: campo opcional dentro de
-- uma restricao quebra a conversao quando o usuario omite o campo.
function Classes.Controller<ID, P>(id: ID & Types.ControllerKey, props: P?): Types.ControllerReturn<ID>
	const name = (id :: any) :: string
	for _, entry in Classes._registry.Controller do
		if entry.ID == name then
			error(`[Modux - Classes] ID Duplicated, {name}`)
		end
	end

	const p = ((props :: any) or {}) :: { Require: any, Priority: number? }
	const newController = Controller.New()
	table.insert(Classes._registry.Controller, {
		ID = name,
		Class = newController :: any,
		Dependency = normalizeRequire(p.Require),
		Priority = p.Priority or 1,
	})
	return newController :: any
end

function Classes.Service() end

function Classes.Component() end

return Classes
