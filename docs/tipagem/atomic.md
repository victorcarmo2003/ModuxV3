# Atomic

`src/Shared/Types/Atomic.luau`

Transforma cada campo de uma tabela num par getter/setter — a forma que o
`source` do Vide e o `atom` do Charm usam. Serve para derivar o tipo de um
estado reativo a partir do schema que você já tem, sem escrever o schema duas
vezes.

## Of()

```lua
export type function Of(value: type): type
```

Um campo só.

```lua
type T = Atomic.Of<number>
-- (() -> number) & ((number) -> number)
```

## Table()

```lua
export type function Table(t: type): type
```

Cada campo da tabela vira o seu par.

```lua
type Template = { Coins: number, Level: number }
type Profile = Atomic.Table<Template>
-- {
--   Coins: (() -> number) & ((number) -> number),
--   Level: (() -> number) & ((number) -> number),
-- }
```

```lua
profile.Coins(100)      -- escreve
print(profile.Coins())  -- le, tipado como number

profile.Coins("texto")  -- Expected 'number', but got 'string'
profile.Inexistente     -- Key not found
```

## Por que interseção e não variádico

A assinatura real de um atom do Charm é `(...Update<T>) -> T`, que aceita
também uma função de atualização. Construir um pack variádico dentro de uma
type function é trabalhoso, e a interseção de duas funções cobre as duas
chamadas que importam — é a mesma forma que o `Source<T>` do Vide usa.

Se você precisar do overload de updater, acrescente um terceiro ramo:

```lua
local updater = types.newfunction(
	{ head = { types.newfunction({ head = { value } }, { head = { value } }) } },
	{ head = { value } }
)
return types.intersectionof(getter, setter, updater)
```

## O caso que motivou

Um perfil persistido, onde o schema da persistência é a fonte de verdade:

```lua
export type Data = typeof(Template)
export type Profile = Atomic.Table<Data>
```

Campo novo em `Template.luau` vira campo reativo tipado sem tocar em mais
nada, e o tipo não tem como sair de sincronia com o que é salvo. Escrever o
tipo à mão custaria cinco linhas — e um dia de divergência silenciosa quando
alguém acrescentasse um campo só num dos lados.

::: tip
`Atomic` só descreve a **forma**. Quem cria os atoms de verdade é a tua lib
reativa; o framework não depende de nenhuma.
:::
