type Example = { nome: string, hp: number, mana: number}

export type function Keys(t: type, k: type)
	if not t:is("table") then
		error(`it should be table`)
	end

	local ocludded = {}
	local function register(ty: type)
		local value = ty:value()
		if type(value) ~= "string" then
			error(`singleton needs to be string`)
		end
		ocludded[value] = true
	end

	if k:is("union") then
		for _, ty in k:components() do
			if ty:is("singleton") then
				register(ty)
			end
		end
	elseif k:is("singleton") then
		register(k)
	else
		error(`k must be union or singleton`)
	end

	local result = types.copy(t)
	local remover = {}

	for index in result:properties() do
		local name = index:value()
		if type(name) == "string" and ocludded[name] then
			table.insert(remover, index)
		end
	end

	for _, index in remover do
		result:setproperty(index, nil)
	end

	return result
end

type _E3_14 = Keys<Example, "mana"> --> { nome: string, hp: number }

return {}