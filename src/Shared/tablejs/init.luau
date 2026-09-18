--!strict
-- API no espirito do Object do JavaScript sobre tabela Lua, com o tipo do
-- retorno derivado do alvo em vez de `any`.
--
--     const cfg = tablejs.New({ nome = "x", hp = 10 })
--     cfg:keys()          -- { "hp" | "nome" }
--     cfg.hp              -- number, o campo original continua ali
--
-- O que NAO existe aqui, e por que: unfreeze, seal e unseal estavam no esboco
-- mas Lua nao tem equivalente. table.freeze e definitivo e nao ha selagem
-- separada. Metodo que mente e pior que metodo que falta.

local Tipos = require(script.Types)

export type Metodos<T> = Tipos.Metodos<T>
export type Objeto<T> = Tipos.Objeto<T>

const tablejs = {}

-- Os metodos operam sobre o proprio objeto: como New copia os campos do alvo
-- para dentro dele, `self` JA e a tabela de dados. Por isso cada um filtra os
-- proprios nomes de metodo antes de varrer.
const ehMetodo = {
	keys = true,
	values = true,
	entries = true,
	has = true,
	pick = true,
	partial = true,
	freeze = true,
	isFrozen = true,
}

local function campos(self: any): { [any]: any }
	const saida = {}
	for chave, valor in self :: { [any]: any } do
		if not ehMetodo[chave] then
			saida[chave] = valor
		end
	end
	return saida
end

const metodos = {}

function metodos.keys(self: any): any
	const saida = {}
	for chave in campos(self) do
		table.insert(saida, chave)
	end
	return saida
end

function metodos.values(self: any): any
	const saida = {}
	for _, valor in campos(self) do
		table.insert(saida, valor)
	end
	return saida
end

function metodos.entries(self: any): any
	const saida = {}
	for chave, valor in campos(self) do
		table.insert(saida, { key = chave, value = valor })
	end
	return saida
end

function metodos.has(self: any, chave: any): boolean
	return campos(self)[chave] ~= nil
end

-- Devolve os dados crus, sem os metodos. E o caminho de volta para quem
-- precisa passar a tabela adiante sem carregar a API junto.
function metodos.pick(self: any): any
	return campos(self)
end

function metodos.partial(self: any): any
	return campos(self)
end

function metodos.freeze(self: any): any
	return table.freeze(campos(self))
end

function metodos.isFrozen(self: any): boolean
	return table.isfrozen(self)
end

-- Copia os campos do alvo para dentro do objeto e poe os metodos junto. E por
-- isso que `cfg.hp` funciona ao lado de `cfg:keys()`.
--
-- Custo: uma copia rasa por New. Em laco quente, guarde o objeto em vez de
-- reconstruir.
function tablejs.New<T>(alvo: T): Tipos.Objeto<T>
	const objeto = {} :: { [any]: any }
	-- O cast fica aqui dentro de proposito. Restringir o parametro com
	-- `T & { [any]: any }` faz a intersection vazar para o T inferido, e o
	-- alvo passa a ser visto como `{ [any]: any, hp: number, ... }`.
	for chave, valor in (alvo :: { [any]: any }) do
		objeto[chave] = valor
	end
	for nome, fn in (metodos :: { [any]: any }) do
		objeto[nome] = fn
	end
	return objeto :: any
end

return tablejs
