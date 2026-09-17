--!strict
--[[
# Nível 5 — Generics

Este nível existe por causa da segunda RFC. Antes dela, QUALQUER
função genérica que atravessasse uma type function dava erro de
serialização, mesmo que você não quisesse mexer em generic nenhum.
]]


--[[
## Os três fatos que você precisa ter na cabeça

### 1. Um tipo só, com flag

Não existe "generic type" e "generic pack" como tags separadas. É a
tag `"generic"`, com `:ispack()` distinguindo.

```lua
types.generic("T")        -- T
types.generic("U", true)  -- U...
```

### 2. Identidade é por nome

Dois generics chamados `"T"` são o MESMO VALOR no type runtime,
mesmo representando tipos diferentes para o typechecker.

### 3. Escopo é quem dá o significado

Um generic só existe se estiver na lista de `setgenerics` de alguma
função em escopo. Declarar `"T"` numa função interna ESCONDE o `"T"`
externo. Shadowing, igual a variável no código normal.

Consequência prática do item 3: esquecer `setgenerics` é o erro nº 1
deste nível. O sintoma é erro de serialização, ou o generic
simplesmente sumir do tipo final.

## API deste nível

```lua
types.generic(nome, ehPack)
types.newfunction(params, returns, generics)  -- terceiro argumento

f:generics()          -- TIPOS primeiro, PACKS depois, sempre
f:setgenerics({})     -- tipos NÃO podem vir depois de packs

g:name()              -- string ou nil
g:ispack()            -- boolean
```
]]


-- tipos de apoio
type Generica = <T, U, V...>(T, U, V...) -> ()
type Jogador = { nome: string, hp: number }

type Api = {
	curar: (number) -> (),
	mover: (Vector3) -> boolean,
	nome: string,
}


--[[
## E5.1 · Identidade<>

**Meta** construir `<T>(T) -> T` do zero
**Nota** vem pronto. O valor está no experimento abaixo

### Experimento obrigatório

Comente a linha do `setgenerics` e rode. Anote o erro exato. Você
vai reencontrar esse erro várias vezes, e reconhecê-lo de cara
economiza horas.
]]
type function Identidade()
	local T = types.generic("T")
	local f = types.newfunction({ head = {T} }, { head = {T} })
	f:setgenerics({T}) -- sem esta linha, o T é órfão
	return f
end

type _E5_1 = Identidade<> --> <T>(T) -> T


--[[
## E5.2 · Constante<>

**Meta** construir `<T, U>(T, U) -> T`
**Novo** dois generics na mesma lista, e usar só um deles no retorno
]]
type function Constante()
	-- TODO
	return types.never
end

type _E5_2 = Constante<> --> <T, U>(T, U) -> T


--[[
## E5.3 · Par<>

**Meta** construir `<T>(T, T) -> {T}`
**Combina** generic com construção de tabela do E2.6. O mesmo `T`
aparece três vezes
]]
type function Par()
	-- TODO
	return types.never
end

type _E5_3 = Par<> --> <T>(T, T) -> {T}


--[[
## E5.4 · MapFn<>

**Meta** construir `<T, U>({T}, (T) -> U) -> {U}`
**Nota** vem quase pronto porque o comentário no meio é a lição

### Entenda o NOTE

`transformador` não é genérico. Ele USA `T` e `U`, que pertencem ao
escopo de `f`. Se você desse `setgenerics({T, U})` nele também,
teria criado um `<T, U>(T) -> U` aninhado. Tipo diferente e errado.

Esta é a distinção mais importante do nível:
USAR um generic não é DECLARAR um generic.
]]
type function MapFn()
	local T, U = types.generic("T"), types.generic("U")

	local listaT = types.newtable(nil, {
		index = types.number,
		readresult = T,
		writeresult = T,
	})

	local listaU = listaT -- TODO: mesma coisa com U

	local transformador = types.newfunction({ head = {T} }, { head = {U} })
	-- NOTE: transformador NÃO recebe setgenerics

	local f = types.newfunction(
		{ head = { listaT, transformador } },
		{ head = { listaU } }
	)
	f:setgenerics({T, U})

	return f
end

type _E5_4 = MapFn<> --> <T, U>({T}, (T) -> U) -> {U}


--[[
## E5.5 · EhGenerica<F>

**Meta** aquecimento antes de ler generics a sério
]]
type function EhGenerica(f)
	-- TODO
	return types.singleton(false)
end

type _E5_5a = EhGenerica<Generica>       --> true
type _E5_5b = EhGenerica<(number) -> ()> --> false


--[[
## E5.6 · ContarGenerics<F>

**Meta** singleton de string no formato `"tipos=N,packs=M"`
**Usa** `f:generics()` devolve tudo numa lista só, tipos primeiro e
packs depois, sempre nessa ordem. `:ispack()` separa
]]
type function ContarGenerics(f)
	-- TODO
	return types.singleton("tipos=0,packs=0")
end

type _E5_6 = ContarGenerics<Generica> --> "tipos=2,packs=1"


--[[
## E5.7 · NomesDosGenerics<F>

**Meta** nomes separados por vírgula. Generic sem nome vira `"?"`
**Armadilha** `:name()` devolve nil para generics vindos de
inferência automática do solver
**Teste extra** rode numa função cujos generics o Luau inferiu
sozinho, em vez de você ter escrito `<T>` à mão
]]
type function NomesDosGenerics(f)
	-- TODO
	return types.singleton("")
end

type _E5_7 = NomesDosGenerics<Generica> --> "T,U,V"


--[[
## E5.8 · Variadificar<F>

**Meta** adicionar um pack genérico no fim dos parâmetros
**Nota** vem pronto, mas tem um bug conhecido que é sua tarefa
consertar
**Regra que você tem que respeitar** na lista de `setgenerics`,
tipos não podem vir depois de packs. Appendar no fim funciona aqui
SÓ PORQUE você está adicionando um pack. Se fosse um tipo, teria que
inserir antes dos packs

### Bug

Se `f` já tem um tail variádico, o código abaixo descarta em
silêncio. Escreva a versão que erra nesse caso.
]]
type function Variadificar(f)
	if not f:is("function") then
		error("espera uma function")
	end

	local extra = types.generic("Extra", true)
	local p, r = f:parameters(), f:returns()

	local novo = types.newfunction(
		{ head = p.head, tail = extra },
		{ head = r.head, tail = r.tail }
	)

	local lista = {}
	for _, g in f:generics() do
		table.insert(lista, g)
	end
	table.insert(lista, extra) -- pack no FIM, sempre
	novo:setgenerics(lista)

	return novo
end

type _E5_8 = Variadificar<(number) -> ()>
--> <Extra...>(number, Extra...) -> ()


--[[
## E5.9 · Generificar<F>

**Meta** trocar TODOS os parâmetros posicionais por um único `T`
genérico
]]
type function Generificar(f)
	-- TODO
	return f
end

type _E5_9 = Generificar<(number, string) -> boolean>
--> <T>(T, T) -> boolean


--[[
## E5.10 · Shadowing  ·  exercício conceitual

**Meta** construir exatamente `<T>(T, <T>(T) -> string) -> string`
**Nota** vem pronto. O exercício são as perguntas

### Responda por escrito, sem rodar código

1. Você chamou `types.generic("T")` quantas vezes? Por que isso
   basta, se o `T` interno e o externo são tipos DIFERENTES para o
   typechecker?

2. O que muda no tipo resultante se você apagar
   `interna:setgenerics({T})`? Escreva o tipo exato que sairia.

3. Se você criasse `local T2 = types.generic("T")`, segunda chamada
   com o mesmo nome, e usasse `T2` na interna, o resultado mudaria?
   Por quê?

4. Por que o design escolheu identidade por NOME em vez de
   identidade por objeto? Dica: pense em como o typechecker precisa
   reconhecer o `T` que ELE MESMO te entregou quando você devolve o
   tipo modificado.

A pergunta 4 é a mais importante do caderno inteiro. Se você
responder ela bem, entendeu a segunda RFC.
]]
type function Aninhado()
	local T = types.generic("T") -- UM só valor, note bem

	local interna = types.newfunction({ head = {T} }, { head = { types.string } })
	interna:setgenerics({T}) -- declara T no escopo INTERNO

	local externa = types.newfunction(
		{ head = { T, interna } },
		{ head = { types.string } }
	)
	externa:setgenerics({T}) -- declara T no escopo EXTERNO

	return externa
end

type _E5_10 = Aninhado<> --> <T>(T, <T>(T) -> string) -> string

-- RESPOSTAS
-- 1.
-- 2.
-- 3.
-- 4.


--[[
## E5.11 · Projeto final: Metodizar<T, Self>

**Meta** numa tabela, converter todas as propriedades que são
funções em métodos
**Uso real em Roblox** você tem um tipo de API com funções soltas e
quer a versão em que todas recebem `self`

### Requisitos

- Só transforma propriedades cuja tag é `"function"`. `nome` fica intacto
- Preserva generics existentes das funções transformadas
- Preserva variádicos
- Não corrompe `Api`
- Erra com mensagem útil se `T` não for table

Isso usa validação do N1, `types.copy` do N3, iteração de
propriedades do N3, manipulação de `parameters` do N4 e preservação
de generics do N5.

Se você fizer este funcionando, você sabe type functions.
]]
type function Metodizar(t, self)
	-- TODO
	return t
end

type _E5_11 = Metodizar<Api, Jogador>
--> {
-->   curar: (Jogador, number) -> (),
-->   mover: (Jogador, Vector3) -> boolean,
-->   nome: string,
--> }


--[[
## Checklist do Nível 5

- [ ] 5.1  experimento do setgenerics comentado
- [ ] 5.2  Constante
- [ ] 5.3  Par
- [ ] 5.4  MapFn + entender usar != declarar
- [ ] 5.5  EhGenerica
- [ ] 5.6  ContarGenerics
- [ ] 5.7  NomesDosGenerics + teste com generic inferido
- [ ] 5.8  Variadificar + conserto do bug
- [ ] 5.9  Generificar
- [ ] 5.10 as quatro respostas de shadowing
- [ ] 5.11 Metodizar
]]


--[[
## Notas finais do caderno

### Sobre travar o Studio

A RFC assume explicitamente que não vai tentar detectar loops
infinitos, porque por Rice's theorem isso é indecidível, e delega
pros limites globais de tempo de análise e pro sistema de
cancelamento que o Luau já tem.

Na prática: type function em loop = análise abortada por timeout, e
a IDE fica sem informação de tipo. Se o Studio começar a mostrar
tudo como `any` depois que você mexeu numa type function, procure
recursão sem caso base ANTES de procurar qualquer outra coisa.

### Sobre o sandbox

Sem `require`, sem `game`, sem `os`, sem acesso a nenhuma variável
do seu script. Você tem `math`, `table`, `string`, `bit32`, `utf8`,
`buffer` e as funções básicas de Lua. `math.randomseed` é resetado
na entrada de cada type function, então não conte com aleatoriedade
persistente.

### Quando NÃO usar type function

Se `keyof<T>`, `index<T, K>` ou `rawget<T, K>` já resolvem, use os
built-ins. Cada type function que você escreve custa tempo de
análise em todo lugar onde o tipo for usado.
]]
