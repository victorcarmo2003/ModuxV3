# Union

`src/Shared/Types/Union.luau`

Operations over a union and over a table's keys.

```lua
type Color = "red" | "green" | "blue"
type Example = { name: string, hp: number }
```

## Exclude()

Drops from a union the members that appear in the second one.

```lua
type T = Union.Exclude<Color, "green">
-- "red" | "blue"
```

## Extract()

The opposite: keeps only the ones that appear in both.

```lua
type T = Union.Extract<Color, "green" | "blue">
-- "green" | "blue"
```

## NonNullable()

Takes `nil` out of the union.

```lua
type T = Union.NonNullable<string?>
-- string
```

## KeyList()

A table's keys, as a union of singletons.

```lua
type T = Union.KeyList<Example>
-- "name" | "hp"
```

::: tip
For the simple case, Luau's own `keyof<T>` already does it and costs less
analysis. `KeyList` exists to compose with the others here.
:::

## ValueList()

The value types, as a union.

```lua
type T = Union.ValueList<Example>
-- string | number
```

## Entries()

Key-value pairs, as a union of two-tuples.

```lua
type T = Union.Entries<Example>
-- { "name", string } | { "hp", number }
```
