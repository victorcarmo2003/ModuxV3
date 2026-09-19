# Pick

`src/Modux/shared/Types/Pick.luau`

Slices a big table — in practice the Manifest — by the keys you ask for. It's
what turns `Require = { "A", "B" }` into a `self.Dependencies` holding exactly
A and B.

## Table()

```lua
export type function Table(list: type, id: type): type
```

**Details**

`id` takes four shapes:

| shape | result |
|---|---|
| singleton (`"A"`) | the **value** of that key, not a table |
| union (`"A" \| "B"`) | a table with both |
| array of singletons (`{ "A", "B" }`) | a table with both |
| `never` | `any` |

The difference between a bare singleton and a one-element array is
intentional: `Table<M, "A">` returns module A, `Table<M, { "A" }>` returns
`{ A: <module A> }`.

A key that doesn't exist in the Manifest is an error, with the list of what
does:

```
[Manifest] "Invetory" does not exist. Available: Camera, Input, Inventory
```

**Example**

```lua
type Manifest = {
	Currency: { Add: () -> (), Sub: () -> () },
	Data: { Fetch: () -> () },
	Player: { Respawn: () -> () },
}

type One = Pick.Table<Manifest, "Currency">
-- { Add: () -> (), Sub: () -> () }

type Two = Pick.Table<Manifest, "Player" | "Data">
-- { Player: {...}, Data: {...} }
```

## When the keys widen

If the literal loses its type and becomes `{string}`, the function refuses
instead of silently handing back something wrong:

```
[Manifest] WIDENED: the keys became `string`.
Use `:: { "A" | "B" }` on the literal, or pass the union directly
```

This happens when an array of strings is passed with no expected type holding
it in place. The fix is annotating the literal.

## Map()

```lua
export type function Map(list: type, id: type): type
```

Same as `Table`, but it always returns a table — a bare singleton also becomes
`{ Key: value }` — and `never` returns `{}` instead of `any`.

::: warning
`Map` has no anchor in the file and isn't used by the framework. It's there as
reading material; if you're going to use it, instantiate it in its own file
first, or it won't reduce in the editor.
:::
