--!strict
export type Entry = {
	ID: string,
	Class: any,
	Dependency: { string },
	Priority: number,
}

export type Store = { Entry }

const Registry = {}

function Registry.normalizeRequire(value: any): { string }
	if value == nil then
		return {}
	end
	if type(value) == "string" then
		return { value }
	end
	if type(value) == "table" then
		return value
	end
	error(`[Modux] Require must be a string or an array of strings, got {type(value)}`)
end

function Registry.register(kind: string, Base: any, store: Store, id: string, props: any): any
	for _, entry in store do
		if entry.ID == id then
			error(`[Modux - {kind}] Duplicated ID: {id}`)
		end
	end

	const p = (props or {}) :: { Require: any, Priority: number? }
	const instance = Base.New()

	table.insert(store, {
		ID = id,
		Class = instance :: any,
		Dependency = Registry.normalizeRequire(p.Require),
		Priority = p.Priority or 1,
	})

	return instance
end

return Registry
