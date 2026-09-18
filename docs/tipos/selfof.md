# SelfOf

`src/Modux/shared/Types/SelfOf.luau`

Monta o tipo do `self` a partir da folha do módulo mais os extras que o
framework injeta. É a peça central da tipagem — nada mais do framework existe
sem ela.

## Build()

```lua
export type function Build(leaf: type, extras: type): type
```

**Detalhes**

Devolve uma tabela com tudo de `leaf` e tudo de `extras`. A diferença para uma
interseção simples está nos **métodos**: um método da folha cuja assinatura
começa com `self: Leaf` é reescrito para receber a tabela **completa**, com os
extras dentro.

Sem isso, `self.Dependencies` não existiria dentro dos teus próprios métodos.

Se `leaf` ou `extras` for `any`, `unknown` ou `never`, devolve `any` em vez de
errar — um Manifest vazio não deve derrubar o projeto.

**Exemplo**

```lua
type Leaf = {
	Health: number,
	Heal: (self: Leaf, amount: number) -> (),
}

type Self = SelfOf.Build<Leaf, { Dependencies: { Clock: Clock } }>

-- Self.Health        number
-- Self.Dependencies  { Clock: Clock }
-- Self.Heal          (self: <a tabela inteira>, amount: number) -> ()
```

## RequireOf()

```lua
export type function RequireOf(props: type): type
```

**Detalhes**

Lê o campo `Require` da tabela de props do módulo e devolve o que está lá.
Props sem `Require` devolve `never`, que é o que faz
`Pick.Table<Manifest, never>` render uma tabela vazia.

**Exemplo**

```lua
type P = { Require: { "Clock", "Camera" }, Priority: number }
type R = SelfOf.RequireOf<P>   -- { "Clock", "Camera" }
```

## Como aparece no framework

```lua
export type ControllerSelf<ID, P> = SelfOf.Build<
	index<Manifest.AllControllers, ID>,
	{
		Dependencies: Pick.Table<Manifest.AllControllers, SelfOf.RequireOf<P>>,
		Libs: Libs.Api,
		Components: Manifest.ComponentAccess,
	}
>
```

## Cuidado ao mexer nos extras

::: danger
Acrescentar nos extras um tipo que contenha **type function aplicada a genérico
livre** faz o `Build` parar de reduzir em silêncio. O sintoma não menciona o
extra que causou:

```
Cannot add property 'Whatever' to table 'setmetatable<Build<Public, {...}>, ...>'
```
:::

Ao mexer nos extras, sonde antes de confiar:

```lua
local x: SelfOf.Build<L, { Novo: TipoNovo }> = nil :: any
print(x.Novo)
```

Se `Build<` aparecer **literal** no texto do erro, não reduziu.

Ver [Como a tipagem funciona](/tipos/#as-quatro-regras-duras).
