# Struct

`src/Shared/Types/Struct.luau`

Transformations over a table. None of them is used by the framework — they're
for your code.

They all return `any` when handed `any`, `unknown` or `never`, and error with a
message if handed something that isn't a table.

```lua
type Example = {
	name: string,
	hp: number,
	weapon: string?,
}
```

## Partial()

Makes every field optional.

```lua
type T = Struct.Partial<Example>
-- { name: string?, hp: number?, weapon: string? }
```

Handy for a patch: the function accepts any subset without you writing a second
type.

```lua
function Data:Update(player: Player, patch: Struct.Partial<Save>) end
```

## Required()

The inverse: strips the `?` off every field.

```lua
type T = Struct.Required<Example>
-- { name: string, hp: number, weapon: string }
```

## Readonly() / Mutable()

Marks every field read-only, or removes the mark.

```lua
type T = Struct.Readonly<Example>
-- { read name: string, read hp: number, read weapon: string? }
```

## Assign()

Joins two tables, shallow. On a conflict, **b** wins.

```lua
type T = Struct.Assign<Example, { hp: string }>
-- { name: string, hp: string, weapon: string? }
```

## Merge()

Joins two tables **deeply**: a field that is a table on both sides gets merged
instead of replaced.

```lua
type A = { owner: { id: number }, hp: number }
type B = { owner: { tag: string } }

type T = Struct.Merge<A, B>
-- { owner: { id: number, tag: string }, hp: number }
```

Depth is capped at 8 levels, to avoid any risk of infinite recursion — a type
function that doesn't terminate aborts the analysis and Studio starts showing
everything as `any`.

## Record()

Builds a table out of keys and a value type.

```lua
type T = Struct.Record<"a" | "b", number>
-- { a: number, b: number }
```

## Rename()

Changes a field's name, preserving its type. A field that doesn't exist is an
error.

```lua
type T = Struct.Rename<Example, "hp", "health">
-- { name: string, health: number, weapon: string? }
```

## DeepPartial() / DeepReadonly()

Like `Partial` and `Readonly`, descending into nested tables.

```lua
type Nested = { owner: { id: number }, hp: number }

type T = Struct.DeepPartial<Nested>
-- { owner: { id: number? }?, hp: number? }
```
