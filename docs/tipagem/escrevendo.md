# Escrevendo a sua

Type function é Luau normal rodando numa VM real durante a análise. Você tem
loop, closure, recursão, `string`, `table`, `math`. O que ela devolve é um
tipo, e o que ela pode fazer de mais poderoso é `error()` — porque isso vira
erro de análise com a mensagem que você escreveu.

## Antes de escrever: os built-ins resolvem?

Se `keyof<T>`, `index<T, K>`, `rawget<T, K>` ou `setmetatable` dão conta, use
eles. Toda type function custa tempo de análise em **todo** lugar onde o tipo
aparece, e não tem debugger.

A ordem é: anotação à mão → built-in → type function.

Type function paga em dois casos:

- o tipo precisa **acompanhar** outro e nunca sair de sincronia
- você precisa **reprovar** por um critério que a linguagem não expressa

:::tip Informação
Para a maioria das coisas os built-ins já resolvem o seu problema, keyof
com intersection e tipagem genérica já cobre a maioria dos casos — inclusive
é o que eu uso para converter as strings em singleton dentro das tabelas.
:::

## O esqueleto

```lua
export type function Nome(t: type, k: type)   -- SEMPRE TIPE ISSO!!!
	if t:is("any") or t:is("unknown") or t:is("never") then
		return types.any
	end
	if not t:is("table") then
		error(`[Nome] expected a table, got {t.tag}`)
	end

	local out = types.newtable()      -- subconjunto novo
	-- local out = types.copy(t)      -- modificar o que veio

	for key, prop in t:properties() do
		local value = prop.read or prop.write
		if value ~= nil then
			-- a receita: a única coisa que muda entre as funções
			out:setproperty(key, value)
		end
	end

	return out
end

type _anchor = Nome<Sample, "x">   -- obrigatório, ver abaixo
```

## A âncora não é opcional

O luau-lsp só avalia uma type function exportada se ela for instanciada ao
menos uma vez **no arquivo que a define**. Sem isso ela vira `*error-type*` só
no editor: a análise em linha de comando passa, o autocomplete não funciona, e
nada avisa.

Toda função daqui termina com `type _anchorX = X<...>`. Não são exemplos.

:::tip Informação
Ou talvez sejam: como às vezes ele não reconhece o tipo, melhor deixar a âncora
lá de qualquer jeito 🫠
:::

## O catálogo de falhas silenciosas

As quatro que mais custam, porque **não** produzem erro:

### 1. Faltou `: type`

Em parâmetro ou em closure helper interna. Essa pelo menos erra, mas com uma
mensagem gigante e ilegível:

```
t1 where t1 = { read value: (t1) -> ... }
```

### 2. `properties()` só enxerga a tabela própria

Tipo com metatable — `setmetatable<{}, {__index: X}>`, classe OOP — não tem
propriedade própria. O loop não entra, e a função devolve algo equivalente ao
que recebeu. Silêncio total.

### 3. `components()` é array, não dicionário

```lua
for _, c in uniao:components() do   -- certo
for c in uniao:components() do      -- itera índices e quebra no :value()
```

### 4. Userdata como chave compara por referência

Para perguntar **significado** ("esta chave está na lista?"), indexe por
`:value()`. Para perguntar **identidade** ("já visitei este objeto?"), userdata
é a ferramenta certa.

## Mutar o argumento corrompe o original

Os tipos chegam por referência. Se você modificar o argumento em vez de uma
cópia, corrompe o tipo original no script inteiro, e o sintoma aparece longe.

Depois de qualquer função que modifica, escreva um teste que **deve continuar
errando**:

```lua
local _sanidade: Config = { nome = "a" }   -- faltam campos: tem que errar
```

Se parar de errar, faltou o `types.copy`.

## Loop infinito aborta a análise

Um problema chato das type functions é que nem sempre o loop infinito é
detectado. Type function que não termina = análise abortada por timeout, e o LSP
passa a acusar `Type is too complex` ou a mostrar tudo como `any`.

Todo walker recursivo nasce com uma tabela `visitados`, e o registro acontece
**antes** de descer, não depois. Ou com um limite de profundidade, como o
[`Merge`](/tipagem/struct#merge) faz com 8.

Se o editor começou a mostrar tudo como `any` ou passou a acusar
`Type is too complex` logo depois de você mexer numa type function, procure
recursão ou loop que não faz sentido antes de olhar qualquer outra coisa.

## Ordem não é garantida

`properties()` não garante ordem. Qualquer coisa posicional — montar uma
interseção de overloads, derivar ordem de argumentos — precisa de `table.sort`
explícito, senão o bug só aparece quando a tabela cresce.

:::tip Informação
Você vai reparar que as tabelas costumam devolver os campos de trás para frente.
Não descobri o motivo — só não confie na ordem.
:::

## Limites do sandbox

Sem `require`, sem `game`, sem `os`, sem acesso a variável do script. Tem
`math`, `table`, `string`, `bit32`, `utf8`, `buffer`.

Três consequências:

- **Type functions não se enxergam.** Helper tem que ser colado dentro de cada
  função que usa.
- **Não existe higher-order.** Você não passa uma type function como argumento
  de outra. O contorno é despachar por singleton de string.
- **Não existe singleton numérico.** Para devolver número, use
  `types.singleton(tostring(n))`; caso contrário você perde o valor.

## Sondando

O truque mais útil: `error()` como print, sim, PARA PRINTAR.

```lua
error(`cheguei com {chave:value()}`)
```

O primeiro `error` aborta tudo, então para ver uma lista inteira, acumule num
array e erre uma vez só no fim. O lint `UnreachableCode` depois disso é
esperado.

Para saber o que um tipo realmente tem, só montar uma função que erra de propósito:

```lua
export type function Show(t: type)
	local nomes = {}
	for key in t:properties() do
		table.insert(nomes, tostring(key:value()))
	end
	table.sort(nomes)
	error(`SHOW props=[{table.concat(nomes, ",")}] tag={t.tag}`)
end
```

Quando uma type function devolve algo idêntico ao que entrou, `props=[]` é
quase sempre a resposta — e a causa costuma ser a falha nº2.

## Um exemplo completo

Este está pronto no repositório, como [`Atomic`](/tipagem/atomic). Derivar `{ Coins: number }` em campos reativos, onde cada um lê chamado sem
argumento e escreve chamado com um:

```lua
export type function Atomic(t: type): type
	if not t:is("table") then
		error(`[Atomic] expected a table, got {t.tag}`)
	end

	local out = types.newtable()
	for key, prop in t:properties() do
		local value = prop.read or prop.write
		if value ~= nil then
			local getter = types.newfunction({ head = {} }, { head = { value } })
			local setter = types.newfunction({ head = { value } }, { head = { value } })
			out:setproperty(key, types.intersectionof(getter, setter))
		end
	end
	return out
end

type _anchor = Atomic<{ Coins: number }>
```

```lua
type Profile = Atomic<typeof(Template)>

profile.Coins(100)     -- ok
print(profile.Coins()) -- number
profile.Coins("x")     -- Expected 'number', but got 'string'
```

A interseção de getter e setter evita construir um pack variádico, e o campo
novo no Template aparece sozinho.
