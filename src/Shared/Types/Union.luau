--!strict
-- Operacoes sobre uniao, e as pontes de tabela para uniao.
--
-- Mesmas duas regras do Struct: `types` so existe dentro do corpo da type
-- function, e cada exportada precisa da ancora no fim do arquivo.

type Exemplo = { nome: string, hp: number, arma: string? }
type Cor = "vermelho" | "verde" | "azul"

-- Tira de U tudo que aparece em E.
export type function Exclude(u: type, e: type): type
	if u:is("any") or u:is("unknown") or u:is("never") then
		return types.any
	end

	local fora = {}
	local function marca(t: type)
		if t:is("singleton") then
			fora[tostring(t:value())] = true
		else
			fora[t.tag] = true
		end
	end
	if e:is("union") then
		for _, parte in e:components() do
			marca(parte)
		end
	else
		marca(e)
	end

	local function cortado(t: type): boolean
		if t:is("singleton") then
			return fora[tostring(t:value())] == true
		end
		return fora[t.tag] == true
	end

	if not u:is("union") then
		return if cortado(u) then types.never else u
	end
	local restantes = {}
	for _, parte in u:components() do
		if not cortado(parte) then
			table.insert(restantes, parte)
		end
	end
	if #restantes == 0 then
		return types.never
	end
	if #restantes == 1 then
		return restantes[1]
	end
	return types.unionof(table.unpack(restantes))
end

-- O oposto: fica so o que aparece nos dois.
export type function Extract(u: type, e: type): type
	if u:is("any") or u:is("unknown") or u:is("never") then
		return types.any
	end

	local dentro = {}
	local function marca(t: type)
		if t:is("singleton") then
			dentro[tostring(t:value())] = true
		else
			dentro[t.tag] = true
		end
	end
	if e:is("union") then
		for _, parte in e:components() do
			marca(parte)
		end
	else
		marca(e)
	end

	local function mantem(t: type): boolean
		if t:is("singleton") then
			return dentro[tostring(t:value())] == true
		end
		return dentro[t.tag] == true
	end

	if not u:is("union") then
		return if mantem(u) then u else types.never
	end
	local restantes = {}
	for _, parte in u:components() do
		if mantem(parte) then
			table.insert(restantes, parte)
		end
	end
	if #restantes == 0 then
		return types.never
	end
	if #restantes == 1 then
		return restantes[1]
	end
	return types.unionof(table.unpack(restantes))
end

-- Tira o nil.
export type function NonNullable(t: type): type
	if t:is("any") or t:is("unknown") or t:is("never") then
		return types.any
	end
	if not t:is("union") then
		return t
	end
	local restantes = {}
	for _, parte in t:components() do
		if parte.tag ~= "nil" then
			table.insert(restantes, parte)
		end
	end
	if #restantes == 0 then
		return types.never
	end
	if #restantes == 1 then
		return restantes[1]
	end
	return types.unionof(table.unpack(restantes))
end

-- As chaves como array: { "arma" | "hp" | "nome" }. Diferente do `keyof`
-- nativo, que devolve a uniao solta; aqui ja vem no formato que uma funcao
-- `keys()` retorna.
export type function KeyList(t: type): type
	if t:is("any") or t:is("unknown") or t:is("never") then
		return types.any
	end
	if not t:is("table") then
		error(`[KeyList] esperava table, recebi {t.tag}`)
	end
	local chaves = {}
	for chave in t:properties() do
		table.insert(chaves, chave)
	end
	local saida = types.newtable()
	if #chaves == 0 then
		saida:setindexer(types.number, types.never)
	elseif #chaves == 1 then
		saida:setindexer(types.number, chaves[1])
	else
		saida:setindexer(types.number, types.unionof(table.unpack(chaves)))
	end
	return saida
end

-- Os valores como array: { string | number | nil }.
export type function ValueList(t: type): type
	if t:is("any") or t:is("unknown") or t:is("never") then
		return types.any
	end
	if not t:is("table") then
		error(`[ValueList] esperava table, recebi {t.tag}`)
	end
	-- Deduplica por assinatura, senao dois campos string viram
	-- `string | string` no resultado - correto, mas ilegivel no hover.
	local valores = {}
	local vistos = {}
	for _, prop in t:properties() do
		local valor = prop.read or prop.write
		if valor ~= nil then
			local assinatura = if valor:is("singleton")
				then `singleton:{tostring(valor:value())}`
				else valor.tag
			if not vistos[assinatura] then
				vistos[assinatura] = true
				table.insert(valores, valor)
			end
		end
	end
	local saida = types.newtable()
	if #valores == 0 then
		saida:setindexer(types.number, types.never)
	elseif #valores == 1 then
		saida:setindexer(types.number, valores[1])
	else
		saida:setindexer(types.number, types.unionof(table.unpack(valores)))
	end
	return saida
end

-- Cada par vira { key, value } com o tipo certo dos dois lados, e o array e a
-- uniao desses pares. E o que permite iterar entries() sem perder o vinculo
-- entre a chave e o tipo do valor dela.
export type function Entries(t: type): type
	if t:is("any") or t:is("unknown") or t:is("never") then
		return types.any
	end
	if not t:is("table") then
		error(`[Entries] esperava table, recebi {t.tag}`)
	end
	local pares = {}
	for chave, prop in t:properties() do
		local valor = prop.read or prop.write
		if valor ~= nil then
			local par = types.newtable()
			par:setreadproperty(types.singleton("key"), chave)
			par:setreadproperty(types.singleton("value"), valor)
			table.insert(pares, par)
		end
	end
	local saida = types.newtable()
	if #pares == 0 then
		saida:setindexer(types.number, types.never)
	elseif #pares == 1 then
		saida:setindexer(types.number, pares[1])
	else
		saida:setindexer(types.number, types.unionof(table.unpack(pares)))
	end
	return saida
end

type _ancoraExclude = Exclude<Cor, "verde">
type _ancoraExtract = Extract<Cor, "verde" | "azul">
type _ancoraNonNullable = NonNullable<string?>
type _ancoraKeyList = KeyList<Exemplo>
type _ancoraValueList = ValueList<Exemplo>
type _ancoraEntries = Entries<Exemplo>

return {}
