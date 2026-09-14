export type function getList(list: type, id: type): type
	if not list:is("table") then
		error("It should be the manifest")
	end

	local fromArray = false
	if id:is("table") then
		fromArray = true
		local indexer = id:readindexer()
		if not indexer then
			error("Expected an array of keys")
		end
		id = indexer.result
	end

	if id:is("string") then
		error("WIDENED")
	end

	if id:is("singleton") and not fromArray then
		local choosen = id:value()
		for key, prop in list:properties() do
			if key:is("singleton") and key:value() == choosen then
				return if prop.read then prop.read elseif prop.write then prop.write else types.never
			end
		end
		error(`Key {choosen} doesn't belong to this Manifest.`)
	end

	local selected = {}
	if id:is("singleton") then
		selected[id:value()] = true
	elseif id:is("union") then
		for _, a0 in id:components() do
			if not a0:is("singleton") then
				error(`Subtypes of union should be singleton, got: {a0.tag}`)
			end
			selected[a0:value()] = true
		end
	else
		error(`id should be a singleton or a union of singletons, got: {id.tag}`)
	end

	local collected = types.newtable()
	local match = {}

	for key, prop in list:properties() do
		if key:is("singleton") then
			local rawValue = key:value()
			if selected[rawValue] then
				match[rawValue] = true
				if prop.read then
					collected:setreadproperty(key, prop.read)
				end
				if prop.write then
					collected:setwriteproperty(key, prop.write)
				end
			end
		end
	end

	for name in selected do
		if not match[name] then
			error(`Key {name} doesn't belong to this Manifest.`)
		end
	end

	return collected
end

return {}