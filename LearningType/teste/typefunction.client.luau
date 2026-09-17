--[[
NÍVEL 1 — Inspeção de tipos

Agora sim, type functions. Aqui você só lê tipos, não constrói.

E1.1 — EhString<T>

Escreva uma type function que retorna o tipo singleton true se o argumento for string, e false caso contrário.

```luau
type A = EhString<string>  -- true
type B = EhString<number>  -- false
```

Dica: t:is("string") e types.singleton(true).
]]
-- ANSWER:
type function IsString(param1: type)
	return if param1:is("string") then types.singleton(true) else types.singleton(false)
end

--[[
E1.2 — NomeDoTipo<T>

Retorne um singleton de string com a tag do tipo.

```luau
type A = NomeDoTipo<number>        -- "number"
type B = NomeDoTipo<{x: number}>   -- "table"
type C = NomeDoTipo<"oi">          -- "singleton"
```
]]
-- ANSWER:
type function typeName(param1: type)
	return types.singleton(param1.tag)
end

--[[E1.3 — Erro customizado

Escreva SoTabela<T> que devolve T se for uma table, e chama error() com mensagem útil caso contrário. A mensagem deve incluir qual tag foi recebida.

```luau
type A = SoTabela<{x: number}>  -- ok
type B = SoTabela<number>       -- erro: "esperava table, recebi number"]
```
]]
--ANSWER
type function isATabela(maybeTabela: type)
	if maybeTabela:is("table") then
		return maybeTabela
	end
	return error(`Expected: table | Got: {maybeTabela.tag}`)
end

--[[
E1.4 — Valor do singleton

Escreva Dobrar<T> que recebe um singleton de string e devolve um singleton com a string repetida duas vezes.

```luau
type A = Dobrar<"ab">  -- "abab"
```
Dica: t:value() te dá o valor real, e você está em Lua normal — .. funciona.
]]

type function DoubleString(targetString: type)
	if not targetString:is("singleton") then
		error(`Expected: singleton | Got: {targetString.tag}`)
	end
	local value = targetString:value()
	assert(type(value) == "string", `Expected: string | Got: {typeof(value)}`)
	return types.singleton(value .. value)
end

type A = DoubleString<"ab">

--[[
E1.5 — Contar membros de union

Escreva TamanhoUnion<T> que devolve um singleton de número com quantos componentes a union tem. Se não for union, devolve 1.

```luau
type A = TamanhoUnion<string | number | boolean>  -- 3
type B = TamanhoUnion<string>                     -- 1
```
Atenção: types.singleton() aceita string, boolean ou nil — não number. Pense em como devolver um número. (Isso é intencional: é pra você descobrir uma limitação real da API.)
]]

type function UnionSize(targetUnion: type)
	if targetUnion:is("union") then
		return types.singleton(tostring((#targetUnion:components())))
	end
	return types.singleton("1")
end

type B = UnionSize<string | number | boolean | "table">
