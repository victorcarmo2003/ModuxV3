--!strict
-- Transformacoes estruturais de tipo-tabela, no espirito das utility types do
-- TypeScript. Usaveis em qualquer lugar do projeto, nao so pelo tablejs.
--
-- Duas coisas que a linguagem impoe aqui, e que nao sao estilo:
--
-- 1. `types` e o tipo `type` so existem DENTRO do corpo de uma type function.
--    Helper no escopo do modulo nao compila, entao a guarda e o auxiliar de
--    union aparecem repetidos. Nao tente fatorar para fora.
--
-- 2. Toda funcao exportada precisa de uma ancora de instanciacao neste mesmo
--    arquivo, no fim. O luau-lsp so avalia type function exportada que seja
--    instanciada ao menos uma vez onde foi definida; sem isso todo uso externo
--    vira *error-type* no editor enquanto o luau-analyze passa limpo.

type Exemplo = {
	nome: string,
	hp: number,
	arma: string?,
}

-- Todo campo vira opcional.
export type function Partial(t: type): type
	if t:is("any") or t:is("unknown") or t:is("never") then
		return types.any
	end
	if not t:is("table") then
		error(`[Partial] esperava table, recebi {t.tag}`)
	end
	local saida = types.newtable()
	for chave, prop in t:properties() do
		local valor = prop.read or prop.write
		if valor ~= nil then
			saida:setproperty(chave, types.optional(valor))
		end
	end
	return saida
end

-- O inverso: tira o nil de todo campo.
export type function Required(t: type): type
	if t:is("any") or t:is("unknown") or t:is("never") then
		return types.any
	end
	if not t:is("table") then
		error(`[Required] esperava table, recebi {t.tag}`)
	end
	local saida = types.newtable()
	for chave, prop in t:properties() do
		local valor = prop.read or prop.write
		if valor ~= nil then
			if valor:is("union") then
				local restantes = {}
				for _, parte in valor:components() do
					if parte.tag ~= "nil" then
						table.insert(restantes, parte)
					end
				end
				if #restantes == 1 then
					valor = restantes[1]
				elseif #restantes > 1 then
					valor = types.unionof(table.unpack(restantes))
				end
			end
			saida:setproperty(chave, valor)
		end
	end
	return saida
end

-- Todo campo so-leitura. Nao congela em runtime; impede a escrita na analise,
-- que e onde o bug ainda custa barato.
export type function Readonly(t: type): type
	if t:is("any") or t:is("unknown") or t:is("never") then
		return types.any
	end
	if not t:is("table") then
		error(`[Readonly] esperava table, recebi {t.tag}`)
	end
	local saida = types.newtable()
	for chave, prop in t:properties() do
		local valor = prop.read or prop.write
		if valor ~= nil then
			saida:setreadproperty(chave, valor)
		end
	end
	return saida
end

-- Devolve a escrita a todo campo.
export type function Mutable(t: type): type
	if t:is("any") or t:is("unknown") or t:is("never") then
		return types.any
	end
	if not t:is("table") then
		error(`[Mutable] esperava table, recebi {t.tag}`)
	end
	local saida = types.newtable()
	for chave, prop in t:properties() do
		local valor = prop.read or prop.write
		if valor ~= nil then
			saida:setproperty(chave, valor)
		end
	end
	return saida
end

type _ancoraPartial = Partial<Exemplo>
type _ancoraRequired = Required<Exemplo>
type _ancoraReadonly = Readonly<Exemplo>
type _ancoraMutable = Mutable<Exemplo>

-- B sobrescreve A. Campo que so existe em A sobrevive.
export type function Assign(a: type, b: type): type
	if a:is("any") or a:is("unknown") or a:is("never") then
		return types.any
	end
	if b:is("any") or b:is("unknown") or b:is("never") then
		return types.any
	end
	if not a:is("table") or not b:is("table") then
		error(`[Assign] esperava duas tables, recebi {a.tag} e {b.tag}`)
	end
	local saida = types.newtable()
	for chave, prop in a:properties() do
		local valor = prop.read or prop.write
		if valor ~= nil then
			saida:setproperty(chave, valor)
		end
	end
	for chave, prop in b:properties() do
		local valor = prop.read or prop.write
		if valor ~= nil then
			saida:setproperty(chave, valor)
		end
	end
	return saida
end

-- Como Assign, mas quando os dois lados tem o mesmo campo e os dois sao table,
-- desce em vez de sobrescrever. E a diferenca entre trocar um sub-objeto
-- inteiro e completar ele.
export type function Merge(a: type, b: type): type
	if a:is("any") or a:is("unknown") or a:is("never") then
		return types.any
	end
	if b:is("any") or b:is("unknown") or b:is("never") then
		return types.any
	end
	if not a:is("table") or not b:is("table") then
		error(`[Merge] esperava duas tables, recebi {a.tag} e {b.tag}`)
	end

	-- Teto de profundidade porque tipo pode se referenciar; sem ele um
	-- ciclo trava o solver em vez de dar erro legivel.
	local function fundir(x: type, y: type, resta: number): type
		if resta <= 0 or not x:is("table") or not y:is("table") then
			return y
		end
		local saida = types.newtable()
		for chave, prop in x:properties() do
			local valor = prop.read or prop.write
			if valor ~= nil then
				saida:setproperty(chave, valor)
			end
		end
		for chave, prop in y:properties() do
			local direita = prop.read or prop.write
			if direita ~= nil then
				local esquerda = nil
				for c, p in x:properties() do
					if c:value() == chave:value() then
						esquerda = p.read or p.write
					end
				end
				if esquerda ~= nil and esquerda:is("table") and direita:is("table") then
					saida:setproperty(chave, fundir(esquerda, direita, resta - 1))
				else
					saida:setproperty(chave, direita)
				end
			end
		end
		return saida
	end

	return fundir(a, b, 8)
end

-- Record<"a" | "b", number> vira { a: number, b: number }.
export type function Record(chaves: type, valor: type): type
	if chaves:is("any") or chaves:is("unknown") or chaves:is("never") then
		return types.any
	end
	local saida = types.newtable()
	local function poe(k: type)
		if not k:is("singleton") then
			error(`[Record] chave precisa ser singleton, recebi {k.tag}`)
		end
		saida:setproperty(k, valor)
	end
	if chaves:is("union") then
		for _, k in chaves:components() do
			poe(k)
		end
	else
		poe(chaves)
	end
	return saida
end

-- Troca o nome de um campo mantendo o tipo.
export type function Rename(t: type, de: type, para: type): type
	if t:is("any") or t:is("unknown") or t:is("never") then
		return types.any
	end
	if not t:is("table") then
		error(`[Rename] esperava table, recebi {t.tag}`)
	end
	if not de:is("singleton") or not para:is("singleton") then
		error("[Rename] de e para precisam ser singleton de string")
	end
	local alvo = de:value()
	local achou = false
	local saida = types.newtable()
	for chave, prop in t:properties() do
		local valor = prop.read or prop.write
		if valor ~= nil then
			if chave:value() == alvo then
				achou = true
				saida:setproperty(para, valor)
			else
				saida:setproperty(chave, valor)
			end
		end
	end
	if not achou then
		error(`[Rename] campo {tostring(alvo)} nao existe`)
	end
	return saida
end

-- Partial que desce nas tabelas aninhadas.
export type function DeepPartial(t: type): type
	if t:is("any") or t:is("unknown") or t:is("never") then
		return types.any
	end
	if not t:is("table") then
		error(`[DeepPartial] esperava table, recebi {t.tag}`)
	end
	local function desce(x: type, resta: number): type
		if resta <= 0 or not x:is("table") then
			return x
		end
		local saida = types.newtable()
		for chave, prop in x:properties() do
			local valor = prop.read or prop.write
			if valor ~= nil then
				saida:setproperty(chave, types.optional(desce(valor, resta - 1)))
			end
		end
		return saida
	end
	return desce(t, 8)
end

-- Readonly que desce nas tabelas aninhadas.
export type function DeepReadonly(t: type): type
	if t:is("any") or t:is("unknown") or t:is("never") then
		return types.any
	end
	if not t:is("table") then
		error(`[DeepReadonly] esperava table, recebi {t.tag}`)
	end
	local function desce(x: type, resta: number): type
		if resta <= 0 or not x:is("table") then
			return x
		end
		local saida = types.newtable()
		for chave, prop in x:properties() do
			local valor = prop.read or prop.write
			if valor ~= nil then
				saida:setreadproperty(chave, desce(valor, resta - 1))
			end
		end
		return saida
	end
	return desce(t, 8)
end

type Aninhado = { id: number, dono: { nome: string, tag: string? } }

type _ancoraAssign = Assign<Exemplo, { hp: string }>
type _ancoraMerge = Merge<Aninhado, { dono: { tag: string } }>
type _ancoraRecord = Record<"a" | "b", number>
type _ancoraRename = Rename<Exemplo, "hp", "vida">
type _ancoraDeepPartial = DeepPartial<Aninhado>
type _ancoraDeepReadonly = DeepReadonly<Aninhado>

return {}
