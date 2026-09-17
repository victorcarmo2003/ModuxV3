type ManifestExample = {
	CurrencyService: { AddCash: () -> (), SubtractCash: () -> () },
	DataService: { FetchData: () -> (), ClearData: () -> () },
	PlayerService: { RespawnChar: () -> (), RemoveChar: () -> () },
}
export type function Table(list: type, id: type): type
	if not list:is("table") then
		error(`[Manifest] list deve ser a manifest table, recebi {list.tag}`)
	end

	if id:is("any") or id:is("unknown") or id:is("never") then
		return types.any
	end

	-- quantas opcoes um tipo descreve (para desempatar intersection)
	local function largura(t: type): number?
		local alvo = t
		if alvo:is("table") then
			local ix = alvo:readindexer()
			if not ix then
				return nil
			end
			alvo = ix.result
		end
		if alvo:is("singleton") then
			return 1
		end
		if alvo:is("union") then
			local n = 0
			for _ in alvo:components() do
				n += 1
			end
			return n
		end
		return nil
	end

	-- 1. INTERSECTION: fica o ramo mais estreito, sem depender de ordem
	if id:is("intersection") then
		local melhor, menor = nil, math.huge
		for _, parte in id:components() do
			local w = largura(parte)
			if w and w < menor then
				menor, melhor = w, parte
			end
		end
		if not melhor then
			error("[Manifest] intersection sem ramo utilizavel (nenhum singleton, union ou array deles)")
		end
		id = melhor
	end

	-- 2. ARRAY: desce no indexer
	local fromArray = false
	if id:is("table") then
		local indexer = id:readindexer()
		if not indexer then
			error("[Manifest] esperava array de chaves, recebi table sem indexer")
		end
		fromArray = true
		id = indexer.result
	end

	if id:is("string") then
		error(
			'[Manifest] WIDENED: as chaves viraram `string`. Use `:: { "A" | "B" }` no literal, ou passe a union direto'
		)
	end

	-- 3. CHAVE UNICA e nao veio de array: devolve o servico direto
	if id:is("singleton") and not fromArray then
		local alvo = id:value()
		local prop = list:readproperty(id)
		if prop then
			return prop
		end
		local disponiveis = {}
		for key in list:properties() do
			table.insert(disponiveis, tostring(key:value()))
		end
		table.sort(disponiveis)
		error(`[Manifest] "{alvo}" nao existe. Disponiveis: {table.concat(disponiveis, ", ")}`)
	end

	-- 4. coleta os pedidos
	local pedidos = {}
	if id:is("singleton") then
		pedidos[id:value()] = true
	elseif id:is("union") then
		for _, c in id:components() do
			if not c:is("singleton") then
				error(`[Manifest] componentes da union devem ser singleton, recebi {c.tag}`)
			end
			pedidos[c:value()] = true
		end
	else
		error(`[Manifest] id deve ser singleton, union de singletons, ou array deles. Recebi {id.tag}`)
	end

	-- 5. monta o subconjunto
	local resultado = types.newtable()
	for key, prop in list:properties() do
		local nome = key:value()
		if type(nome) == "string" and pedidos[nome] then
			pedidos[nome] = nil
			if prop.read then
				resultado:setreadproperty(key, prop.read)
			end
			if prop.write then
				resultado:setwriteproperty(key, prop.write)
			end
		end
	end

	-- 6. o que sobrou foi pedido e nao existe
	local faltando = {}
	for nome in pedidos do
		table.insert(faltando, nome)
	end
	if #faltando > 0 then
		table.sort(faltando)
		local disponiveis = {}
		for key in list:properties() do
			table.insert(disponiveis, tostring(key:value()))
		end
		table.sort(disponiveis)
		error(
			`[Manifest] nao existe(m): {table.concat(faltando, ", ")}. Disponiveis: {table.concat(disponiveis, ", ")}`
		)
	end

	return resultado
end

export type function Map(list: type, id: type): type
	if not list:is("table") then
		error(`[Manifest] list deve ser a manifest table, recebi {list.tag}`)
	end

	local pedidos = {}
	if id:is("singleton") then
		pedidos[id:value()] = true
	elseif id:is("union") then
		for _, c in id:components() do
			if not c:is("singleton") then
				error(`[Manifest] componentes da union devem ser singleton, recebi {c.tag}`)
			end
			pedidos[c:value()] = true
		end
	elseif id:is("never") then
		return types.newtable()
	else
		error(`[Manifest] id deve ser singleton ou union de singletons. Recebi {id.tag}`)
	end

	local resultado = types.newtable()
	for key, prop in list:properties() do
		local nome = key:value()
		if type(nome) == "string" and pedidos[nome] then
			pedidos[nome] = nil
			if prop.read then
				resultado:setreadproperty(key, prop.read)
			end
			if prop.write then
				resultado:setwriteproperty(key, prop.write)
			end
		end
	end

	local faltando = {}
	for nome in pedidos do
		table.insert(faltando, nome)
	end
	if #faltando > 0 then
		table.sort(faltando)
		local disponiveis = {}
		for key in list:properties() do
			table.insert(disponiveis, tostring(key:value()))
		end
		table.sort(disponiveis)
		error(
			`[Manifest] nao existe(m): {table.concat(faltando, ", ")}. Disponiveis: {table.concat(disponiveis, ", ")}`
		)
	end
	return resultado
end

type CurrencyService = Table<ManifestExample, "CurrencyService"> --> AddCash: () -> (), SubtractCash: () -> ()
type TwoServices = Table<ManifestExample, "PlayerService" | "DataService"> --> {RespawnChar: () -> (), RemoveChar: () -> ()}, {FetchData: () -> (), ClearData: () -> ()}

return {}
