# SelfOf

`src/Modux/shared/Types/SelfOf.luau`

Assembles the type of `self` from the module's leaf plus the extras the
framework injects. It's the centerpiece of the typing — nothing else in the
framework exists without it.

## Build()

```lua
export type function Build(leaf: type, extras: type): type
```

**Details**

Returns a table with everything from `leaf` and everything from `extras`. What
sets it apart from a plain intersection is the **methods**: a leaf method whose
signature starts with `self: Leaf` is rewritten to take the **complete** table,
extras included.

Without that, `self.Dependencies` wouldn't exist inside your own methods.

If `leaf` or `extras` is `any`, `unknown` or `never`, it returns `any` instead
of erroring — an empty Manifest shouldn't take the project down.

**Example**

```lua
type Leaf = {
	Health: number,
	Heal: (self: Leaf, amount: number) -> (),
}

type Self = SelfOf.Build<Leaf, { Dependencies: { Clock: Clock } }>

-- Self.Health        number
-- Self.Dependencies  { Clock: Clock }
-- Self.Heal          (self: <the whole table>, amount: number) -> ()
```

## RequireOf()

```lua
export type function RequireOf(props: type): type
```

**Details**

Reads the `Require` field off the module's props table and returns what's
there. Props with no `Require` returns `never`, which is what makes
`Pick.Table<Manifest, never>` yield an empty table.

**Example**

```lua
type P = { Require: { "Clock", "Camera" }, Priority: number }
type R = SelfOf.RequireOf<P>   -- { "Clock", "Camera" }
```

## How it shows up in the framework

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

## Careful when touching the extras

::: danger
Adding to the extras a type that contains a **type function applied to a free
generic** makes `Build` stop reducing, silently. The symptom never mentions the
extra that caused it:

```
Cannot add property 'Whatever' to table 'setmetatable<Build<Public, {...}>, ...>'
```
:::

When you touch the extras, probe before trusting:

```lua
local x: SelfOf.Build<L, { New: NewType }> = nil :: any
print(x.New)
```

If `Build<` shows up **literally** in the error text, it didn't reduce.

See [How the typing works](/en/tipagem/#the-four-hard-rules).
