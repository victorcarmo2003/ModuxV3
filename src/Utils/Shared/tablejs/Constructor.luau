local constructorType = require("./Types/ConstructorTypes")
local Constructor = {} :: constructorType.ConstructorMethods

function keys(self: {[any]: any}) end

function values() end

function entries() end

function has() end

function assign() end

function merge() end

function freeze() end

function unfreeze() end

function seal() end

function unseal() end

Constructor.New = function(Target: any): any
	local newTable = {
		keys = keys,
		values = values,
		entries = entries,
		has = has,
		assign = assign,
		merge = merge,
		freeze = freeze,
		unfreeze = unfreeze,
		seal = seal,
		unseal = unseal,
	}

	for k, v in Target do
		newTable[k] = v
	end

	return newTable
end


return Constructor
