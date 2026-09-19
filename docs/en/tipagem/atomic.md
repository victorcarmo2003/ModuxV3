# Atomic

`src/Shared/Types/Atomic.luau`

Turns each field of a table into a getter/setter pair — the shape Vide's
`source` and Charm's `atom` use. It's for deriving the type of a reactive state
from the schema you already have, without writing the schema twice.

## Of()

```lua
export type function Of(value: type): type
```

A single field.

```lua
type T = Atomic.Of<number>
-- (() -> number) & ((number) -> number)
```

## Table()

```lua
export type function Table(t: type): type
```

Each field of the table becomes its own pair.

```lua
type Template = { Coins: number, Level: number }
type Profile = Atomic.Table<Template>
-- {
--   Coins: (() -> number) & ((number) -> number),
--   Level: (() -> number) & ((number) -> number),
-- }
```

```lua
profile.Coins(100)      -- writes
print(profile.Coins())  -- reads, typed as number

profile.Coins("text")   -- Expected 'number', but got 'string'
profile.DoesNotExist    -- Key not found
```

## Why an intersection and not a variadic

The real signature of a Charm atom is `(...Update<T>) -> T`, which also accepts
an update function. Building a variadic pack inside a type function is
laborious, and the intersection of two functions covers the two calls that
matter — it's the same shape Vide's `Source<T>` uses.

If you need the updater overload, add a third branch:

```lua
local updater = types.newfunction(
	{ head = { types.newfunction({ head = { value } }, { head = { value } }) } },
	{ head = { value } }
)
return types.intersectionof(getter, setter, updater)
```

## The case that motivated it

A persisted profile, where the persistence schema is the source of truth:

```lua
export type Data = typeof(Template)
export type Profile = Atomic.Table<Data>
```

A new field in `Template.luau` becomes a typed reactive field without touching
anything else, and the type has no way of drifting out of sync with what gets
saved. Writing the type by hand would cost five lines — and one day of silent
divergence when somebody added a field to only one of the two sides.

::: tip
`Atomic` only describes the **shape**. What actually creates the atoms is your
reactive lib; the framework doesn't depend on any of them.
:::
