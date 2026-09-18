--!strict
-- O tipo do objeto que tablejs.New devolve.
--
-- O esboco original pedia `NewTable<T> & T` - intersection entre os metodos e
-- os campos do alvo. Aqui e uma type function que funde os dois numa tabela so.
-- Mesmo resultado para quem escreve, e evita a intersection, que e a forma que
-- ja nos deu "No valid instantiation could be inferred" em outro ponto do
-- projeto. E o mesmo padrao que o SelfOf.Build usa.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Struct = require(ReplicatedStorage.shared.Types.Struct)
local Union = require(ReplicatedStorage.shared.Types.Union)

type Exemplo = { nome: string, hp: number }

-- Nao existe `get(chave)` devolvendo o tipo exato daquela chave. Exigiria
-- `<K>(chave: K) -> index<T, K>`, e o solver responde "Type functions do not
-- currently support types of the form index<..., K>". Pior: por ser funcao
-- generica como campo direto, ela impede o Wrap de reduzir, e o sintoma sai
-- como "does not have key" em TODOS os metodos.
--
-- Nao faz falta: o campo continua acessivel direto e ja vem tipado, que e
-- melhor do que passar o nome como string.
--
--     cfg.hp        -- number
--
-- Os metodos, com os tipos derivados do alvo.
export type Metodos<T> = {
	keys: (self: any) -> Union.KeyList<T>,
	values: (self: any) -> Union.ValueList<T>,
	entries: (self: any) -> Union.Entries<T>,
	has: (self: any, chave: keyof<T>) -> boolean,
	pick: (self: any) -> T,
	partial: (self: any) -> Struct.Partial<T>,
	freeze: (self: any) -> Struct.Readonly<T>,
	isFrozen: (self: any) -> boolean,
}

-- Funde os metodos com os campos do alvo, sem intersection.
export type function Wrap(metodos: type, alvo: type): type
	if metodos:is("any") or metodos:is("unknown") or metodos:is("never") then
		return types.any
	end
	if alvo:is("any") or alvo:is("unknown") or alvo:is("never") then
		return types.any
	end
	if not metodos:is("table") or not alvo:is("table") then
		error(`[Wrap] esperava duas tables, recebi {metodos.tag} e {alvo.tag}`)
	end

	local saida = types.newtable()
	for chave, prop in alvo:properties() do
		local valor = prop.read or prop.write
		if valor ~= nil then
			saida:setproperty(chave, valor)
		end
	end
	-- Metodo por ultimo e so-leitura: um campo chamado `keys` no alvo nao
	-- derruba o metodo, e ninguem sobrescreve metodo por acidente.
	for chave, prop in metodos:properties() do
		local valor = prop.read or prop.write
		if valor ~= nil then
			saida:setreadproperty(chave, valor)
		end
	end
	return saida
end

export type Objeto<T> = Wrap<Metodos<T>, T>

type _ancoraWrap = Wrap<Metodos<Exemplo>, Exemplo>

return {}
