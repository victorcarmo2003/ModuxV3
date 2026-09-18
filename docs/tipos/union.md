# Union

`src/Shared/Types/Union.luau`

Operações sobre união e sobre as chaves de uma tabela.

```lua
type Color = "red" | "green" | "blue"
type Example = { name: string, hp: number }
```

## Exclude()

Remove de uma união os membros que aparecem na segunda.

```lua
type T = Union.Exclude<Color, "green">
-- "red" | "blue"
```

## Extract()

O contrário: fica só com os que aparecem nas duas.

```lua
type T = Union.Extract<Color, "green" | "blue">
-- "green" | "blue"
```

## NonNullable()

Tira `nil` da união.

```lua
type T = Union.NonNullable<string?>
-- string
```

## KeyList()

As chaves de uma tabela, como união de singletons.

```lua
type T = Union.KeyList<Example>
-- "name" | "hp"
```

::: tip
Para o caso simples, `keyof<T>` do próprio Luau já resolve e custa menos
análise. `KeyList` existe para compor com as outras daqui.
:::

## ValueList()

Os tipos dos valores, como união.

```lua
type T = Union.ValueList<Example>
-- string | number
```

## Entries()

Pares chave-valor, como união de tuplas de dois.

```lua
type T = Union.Entries<Example>
-- { "name", string } | { "hp", number }
```
