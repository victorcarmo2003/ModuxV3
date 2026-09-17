--!strict
local RemoteCursorService = game:GetService("RemoteCursorService")
--[[
# Nível 2 — Construção de tipos

Você para de só inspecionar e começa a **fabricar** tipos.
Todo exercício aqui cabe em menos de 15 linhas.

## Como usar

1. Abra com o New Type Solver ativo
2. Preencha cada `-- TODO`
3. Passe o mouse nas linhas marcadas com `-->` e compare
4. Os stubs devolvem algo válido de propósito: o arquivo compila
   desde o início, um exercício não quebra o outro
]]

--[[
## Referência da API

### Construtores

```lua
types.string   types.number   types.boolean
types.unknown  types.never    types.any

types.singleton(v)          -- v: string | boolean | nil
                            -- NÃO aceita number
types.unionof(a, b, ...)    -- mínimo 2 argumentos
types.intersectionof(...)   -- mínimo 2 argumentos
types.negationof(a)         -- não aceita table nem function
types.newtable(props, indexer, metatable)
types.newfunction(params, returns, generics)
types.generic(nome, ehPack)
types.copy(t)
```

### Todo tipo tem

```lua
t.tag          -- PROPRIEDADE, não método
t:is("table")
```

### Métodos por tag

```lua
-- singleton
t:value()

-- union / intersection
t:components()

-- negation
t:inner()

-- table
t:properties()          -- { [tipo] = { read = tipo, write = tipo } }
t:readproperty(k)       -- k é um TIPO, não string
t:writeproperty(k)
t:setproperty(k, v)     -- define read E write. v = nil REMOVE
t:setreadproperty(k, v)
t:setwriteproperty(k, v)
t:indexer()
t:setindexer(index, result)
t:metatable()
t:setmetatable(mt)

-- function
t:parameters()
t:returns()
t:setparameters(head, tail)
t:setreturns(head, tail)
t:generics()
t:setgenerics({})

-- generic
t:name()
t:ispack()
```

### Formatos

```lua
-- indexer
local ix = { index = tipo, readresult = tipo, writeresult = tipo }

-- parâmetros e retornos
local p = { head = { tipo, tipo }, tail = tipo }
```

### Assimetria que pega todo mundo

```lua
types.newfunction({ head = {a}, tail = b })  -- UMA tabela nomeada
f:setparameters({a}, b)                      -- DOIS args posicionais
```

### Debug

`print()` funciona dentro de type function.
A saída aparece no Output do Studio durante a análise.

```lua
type function Investigar(t)
	print("tag:", t.tag)
	return t
end
```

### Cuidado com acento

Identificador Luau não aceita acento.
`local União = ...` **não compila**. Use `Unir`.
]]

-- tipos de apoio usados nos testes deste arquivo
type ComNome = { nome: string }
type ComHp = { hp: number }

--[[
## E2.1 · Opcional<T>

**Meta** devolver `T | nil`
**Usa** `types.unionof`, `types.singleton`
**Dica** releia a lista de valores que `types.singleton` aceita
**Porquê** `T?` não é feature mágica: é literalmente uma union com nil
]]
type function Opcional<T>(t: T)
	return types.unionof(t, types.singleton(nil))
end

type _E2_1a = Opcional<number> --> number?
type _E2_1b = Opcional<string> --> string?

--[[
## E2.2 · Nao<T>

**Meta** devolver `~T`
**Usa** `types.negationof`
**Porquê** negação aparece sozinha no narrowing: no `else` de um
`if type(x) == "string"`, o tipo de `x` é `~string`
**Extra** teste com table e com function, anote o erro, e responda:
por que negar uma table seria problemático pro solver?
]]
type function Nao(t)
	return types.negationof(t)
end

type _E2_2a = Nao<string> --> ~string
-- descomente: deve falhar
type _E2_2b = Nao<ComNome> -- TypeError: 'Nao' type function errored at runtime: [string "Nao"]:150: types.negationof: cannot perform negation on `table` type
type _E2_2C = Nao<() -> ()> -- TypeError: 'Nao' type function errored at runtime: [string "Nao"]:150: types.negationof: cannot perform negation on `function` type
-- Para falar a verdade eu não sei o pq exatamente dele não conseguir, acho que ele não consegue inferir os filhos da tabela ou filtrar os parâmetros da função?

--[[
## E2.3 · Concreto<T>

**Meta** singleton -> tipo base; se já for concreto, devolve igual
**Usa** `t:is`, `t:value`, `type()` (a função Lua, não a lib types)
**Cuidado** dois mundos parecidos e diferentes:

```lua
t.tag              -- tag do TIPO       -> "singleton"
type(t:value())    -- tipo do VALOR Lua -> "string"
```
]]
type function Concreto(t: type)
	if not t:is("singleton") then
		return t
	end
	local value = t:value()
	local allTypes = {
		string = types.string,
		number = types.number,
		boolean = types.boolean,
		unknown = types.unknown,
		never = types.never,
		any = types.any,
	}
	return allTypes[type(value)]
end

type _E2_3a = Concreto<"oi"> --> string
type _E2_3b = Concreto<true> --> boolean
type _E2_3c = Concreto<number> --> number

--[[
## E2.4 · Ou<A, B, C>

**Meta** union dos três
**Usa** `types.unionof`
**Repare** o teste `b` tem duplicata e funciona sem trabalho extra:
`unionof` normaliza sozinho
]]
type function Ou(a: type, b: type, c: type)
	return types.unionof(a, b, c)
end

type _E2_4a = Ou<string, number, boolean> --> string | number | boolean
type _E2_4b = Ou<string, string, number> --> string | number

--[[
## E2.5 · E<A, B>

**Meta** devolver `A & B`
**Usa** `types.intersectionof`
**Porquê** em tabelas compõe traits; em funções declara overloads
**Extra** teste `E<string, number>` e explique: um valor pode ser
string e number ao mesmo tempo? O que o solver devolve?
]]
type function E(a: type, b: type)
	-- TODO
	return types.intersectionof(a, b)
end

type _E2_5a = E<ComNome, ComHp> --> { nome: string } & { hp: number }
-- descomente e observe
type _E2_5b = E<string, number> --> WTF, como algo pode ser número e string ao mesmo tempo? Ou nem vc esperava isso, aqui não deu erro kkkk

--[[
## E2.6 · Lista<T> e ListaSoLeitura<T>

**Meta** construir o equivalente a `{T}`
**Usa** `types.newtable(props, indexer, metatable)`
**Nota** o primeiro vem pronto de propósito, o formato do indexer é
a parte não-óbvia. Sua tarefa é o segundo
**Tarefa** `ListaSoLeitura` usa o mesmo indexer SEM `writeresult`.
Depois tente escrever nela e veja o erro
]]
type function Lista(t)
	return types.newtable(nil, {
		index = types.number,
		readresult = t,
		writeresult = t,
	})
end

-- notei que o primeiro parâmetro foi  nil mas o correto não seria any ou number? já que ao iterar ele vem com o index == number, ?
type _E2_6a = Lista<string> --> {string}

type function ListaSoLeitura(t: type)
	return types.newtable(nil, {
		index = types.number,
		readresult = t,
		writeresult = types.never,
	})
end
type _E2_6b = ListaSoLeitura<string>
local teste: _E2_6b = { [1] = "123" }
teste[2] = "a" --> não cria erro, o solver é uma bosta mesmo

--[[
## E2.7 · Dicionario<K, V>

**Meta** construir `{[K]: V}`
**Usa** `types.newtable`
**Tarefa** valide `K`. Faz sentido `never` ou `any` como tipo de
chave? Decida e escreva o `error()` com mensagem útil
]]
type function Dicionario(k: type, v: type)
	if k:is("any") or k:is("never") then
		error(`[Dicionario] chave nao pode ser '{k.tag}'`)
	end

	return types.newtable(nil, {
		index = k,
		readresult = v,
		writeresult = v,
	})
end

type _E2_7a = Dicionario<string, number> --> {[string]: number}
type _E2_7b = Dicionario<any, number> --> isso aqui não tá acusando erro?

--[[
## E2.8 · Tupla<A, B>  ·  exercício de descoberta

**Meta** construir `{ [1]: A, [2]: B }`
**Aviso** isto VAI falhar. O ponto é descobrir por quê
**Pergunta** as chaves de `setproperty` são TIPOS. Como você
representa a chave literal `1`? Releia o que `types.singleton` aceita
**Entrega** escreva em comentário: (a) qual é a limitação exata,
(b) qual workaround você usaria

Exercício que falha por limitação da API vale tanto quanto os que
passam. Você não vai perder 40 minutos nisso em produção depois.
]]
type function Tupla(a: type, b: type)
	return types.newtable(nil, {
		index = types.number,
		readresult = types.unionof(a, b),
		writeresult = types.unionof(a, b),
	})
end

type test = Tupla<"apple", number>
local tabela: test = {
	[1] = "apple",
	[2] = 10,
}

local fruit = tabela[1] --> erro


-- RESPOSTA
-- (a)
-- (b)

--[[
## E2.9 · SemNil<T>

**Meta** remover `nil` de uma union, o `NonNullable` do TypeScript
**Usa** `t:components()`, `types.unionof`, `types.never`
**Uso real** campo `alvo: Player?` que, depois de um assert, você
quer sem o nil
**Cuidado 1** identifique o componente nil comparando com o mesmo
tipo do E2.1. `__eq` é igualdade SINTÁTICA, então funciona
**Cuidado 2** `unionof` exige 2+. Trate sobrar 1 e sobrar 0

O padrão de guarda (0 -> never, 1 -> direto, 2+ -> unionof) vai se
repetir umas cinco vezes. Isole no helper do E2.11.
]]
type function SemNil(t: type)
	if not t:is("union") then
		return t
	end

	local sobrou = {}
	for _, c: type in t:components() do
		if c:is("nil") then
			continue
		end
		table.insert(sobrou, c)
	end
	return types.unionof(table.unpack(sobrou))
end

type _E2_9a = SemNil<string?> --> string
type _E2_9b = SemNil<string | number | nil> --> string | number
type _E2_9c = SemNil<string> --> string

--[[
## E2.10 · Se<Cond, Entao, Senao>

**Meta** ternário no nível de tipo:
- `Cond` == singleton `true`  -> `Entao`
- `Cond` == singleton `false` -> `Senao`
- qualquer outra coisa       -> `error()`

**Porquê o caso C deve errar** `boolean` não é `true` nem `false`,
é a união dos dois. Numa type function não existe "não decidir",
então erro explícito é melhor que chute
]]
type function Se(cond: type, entao: type, senao: type)
	if not cond:is("singleton") then
		error(`[Se] Cond precisa ser 'true' ou 'false', recebi '{cond.tag}'`)
	end

	local v = cond:value()
	if type(v) ~= "boolean" then
		error(`[Se] Cond precisa ser boolean, recebi singleton de {type(v)}`)
	end

	return if v then entao else senao
end

type _E2_10a = Se<true, string, number> --> string
type _E2_10b = Se<false, string, number> --> number
-- descomente: deve errar
type _E2_10c = Se<boolean, string, number> --> ele retornou string kkkk
type _E2_10d = Se<"oi", string, number>     -- erra também

--[[
## E2.11 · Helpers de guarda

**Meta** funções auxiliares pra colar dentro das próximas
**Nota** `Unir` vem pronto. Escreva `Interseccionar`
**Pergunta** lista vazia numa intersecção deve devolver `never` ou
`unknown`? Pense no que significa "a intersecção de zero restrições"
]]
type function DemoHelpers(t)
	local function Unir(lista)
		if #lista == 0 then
			return types.never
		end
		if #lista == 1 then
			return lista[1]
		end
		return types.unionof(table.unpack(lista))
	end

	local function Interseccionar(lista)
		if #lista == 0 then
			return types.never
		end
		if #lista == 1 then
			return lista[1]
		end
		return types.intersectionof(table.unpack(lista))
	end

	return Unir({ t })
end

-- RESPOSTA (lista vazia na intersecção):

--[[
## Checklist do Nível 2

- [ ] 2.1  Opcional
- [ ] 2.2  Nao            + resposta sobre negar table
- [ ] 2.3  Concreto
- [ ] 2.4  Ou
- [ ] 2.5  E              + resposta sobre string & number
- [ ] 2.6  ListaSoLeitura
- [ ] 2.7  Dicionario     + validação de K
- [ ] 2.8  Tupla          + as duas respostas
- [ ] 2.9  SemNil
- [ ] 2.10 Se
- [ ] 2.11 Interseccionar + resposta sobre lista vazia

Fechou tudo? Nível 3 é o que você vai usar de verdade no projeto.
]]