# Occlude

`src/Shared/Types/Occlude.luau`

## Keys()

Drops fields from a table by name.

```lua
export type function Keys(t: type, k: type)
```

**Details**

`k` takes a singleton or a union of singletons. A field that doesn't exist is
silently ignored — unlike [`Rename`](/en/tipagem/struct#rename), which errors.

**Example**

```lua
type Example = { name: string, hp: number, mana: number }

type T = Occlude.Keys<Example, "mana">
-- { name: string, hp: number }

type U = Occlude.Keys<Example, "hp" | "mana">
-- { name: string }
```

## What it's for

The case that motivated it: hiding from a module's public surface the fields
that are internal detail, without keeping a second type by hand.

```lua
type Public = Occlude.Keys<typeof(Service), "_cache" | "_connections">
```

::: tip
If the criterion is a naming convention rather than a fixed list — "everything
starting with `_`" — it's worth writing a type function of your own that
filters by prefix. See [Writing your own](/en/tipagem/escrevendo).
:::
