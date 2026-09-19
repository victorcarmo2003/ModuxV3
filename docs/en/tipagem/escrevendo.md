# Writing your own

A type function is ordinary Luau running on a real VM during analysis. You get
loops, closures, recursion, `string`, `table`, `math`. What it returns is a
type, and the most powerful thing it can do is `error()` — because that turns
into an analysis error carrying the message you wrote.

## Before writing: do the built-ins cover it?

If `keyof<T>`, `index<T, K>`, `rawget<T, K>` or `setmetatable` get the job done,
use them. Every type function costs analysis time in **every** place the type
shows up, and there's no debugger.

The order is: hand-written annotation → built-in → type function.

A type function pays off in two cases:

- the type has to **follow** another one and never drift out of sync
- you need to **reject** something by a criterion the language can't express

:::tip Info
For most things the built-ins already solve your problem. keyof with
intersections and generic typing already covers most of it — it's actually what
I use to turn the strings into singletons from inside the tables
:::

## The skeleton

```lua
export type function Name(t: type, k: type)   -- ALWAYS TYPE THIS!!!
	if t:is("any") or t:is("unknown") or t:is("never") then
		return types.any
	end
	if not t:is("table") then
		error(`[Name] expected a table, got {t.tag}`)
	end

	local out = types.newtable()      -- a brand new subset
	-- local out = types.copy(t)      -- modify what came in

	for key, prop in t:properties() do
		local value = prop.read or prop.write
		if value ~= nil then
			-- the recipe: the only thing that changes between functions
			out:setproperty(key, value)
		end
	end

	return out
end

type _anchor = Name<Sample, "x">   -- mandatory, see below
```

## The anchor isn't optional

luau-lsp only evaluates an exported type function if it's instantiated at least
once **in the file that defines it**. Without that it becomes `*error-type*` in
the editor only: command-line analysis passes, autocomplete doesn't work, and
nothing warns you.

Every function here ends with `type _anchorX = X<...>`. They aren't examples.

:::tip Info
Or maybe they are, since sometimes it doesn't recognize the type — better to
just put them in 🫠
:::

## The catalogue of silent failures

The four that cost the most, because they produce **no** error:

### 1. Missing `: type`

On a parameter or on an internal helper closure. This one at least errors, but
with a huge, unreadable message:

```
t1 where t1 = { read value: (t1) -> ... }
```

### 2. `properties()` only sees the table's own

A type with a metatable — `setmetatable<{}, {__index: X}>`, an OOP class — has
no properties of its own. The loop never runs, and the function returns
something equivalent to what it got. Total silence.

### 3. `components()` is an array, not a dictionary

```lua
for _, c in union:components() do   -- right
for c in union:components() do      -- iterates indices and breaks on :value()
```

### 4. Userdata as a key compares by reference

To ask about **meaning** ("is this key in the list?"), index by `:value()`. To
ask about **identity** ("have I visited this object?"), userdata is the right
tool.

## Mutating the argument corrupts the original

Types arrive by reference. If you modify the argument instead of a copy, you
corrupt the original type across the whole script, and the symptom shows up far
away.

After any function that modifies, write a test that **must keep erroring**:

```lua
type _sanity: Config = { name = "a" }   -- fields missing: this has to error
```

If it stops erroring, you forgot the `types.copy`.

## An infinite loop aborts the analysis

An annoying problem with typefunctions is that they don't always detect infinite
loops. So a type function that doesn't terminate basically means the analysis is
aborted by timeout, and the lsp starts reporting `Type is too complex` or starts
showing everything as `any`.

Every recursive walker is born with a `visited` table, and registration happens
**before** descending, not after. Or with a depth cap, the way
[`Merge`](/en/tipagem/struct#merge) does with 8.

If the editor started showing everything as `any` or threw
`Type is too Complex` right after you touched a type function, look for
recursion or loops inside it that don't make sense before looking at anything
else.

## Order isn't guaranteed

`properties()` guarantees no order. Anything positional — assembling an
intersection of overloads, deriving argument order — needs an explicit
`table.sort`, or the bug only shows up once the table grows.

:::tip Info
You'll also notice that tables always come back back-to-front. No idea why, but
that's just how life is.
:::

## Sandbox limits

No `require`, no `game`, no `os`, no access to a script variable. You do get
`math`, `table`, `string`, `bit32`, `utf8`, `buffer`.

Three consequences:

- **Type functions can't see each other.** A helper has to be pasted inside
  every function that uses it.
- **There's no higher-order.** You can't pass a type function as an argument to
  another. The workaround is dispatching on a string singleton.
- **There's no numeric singleton.** To return a number, use
  `types.singleton(tostring(n))`, otherwise you lose it.

## Probing

The most useful trick: `error()` as a print. Yes, TO PRINT.

```lua
error(`got here with {key:value()}`)
```

The first `error` aborts everything, so to see a whole list, accumulate into an
array and error once at the end. The `UnreachableCode` lint after that is
expected.

To find out what a type really has, just build a function that errors on
purpose:

```lua
export type function Show(t: type)
	local names = {}
	for key in t:properties() do
		table.insert(names, tostring(key:value()))
	end
	table.sort(names)
	error(`SHOW props=[{table.concat(names, ",")}] tag={t.tag}`)
end
```

When a type function returns something identical to what went in, `props=[]` is
almost always the answer — and the cause is usually failure #2.

## A complete example

This one is ready in the repository, as [`Atomic`](/en/tipagem/atomic). Deriving
`{ Coins: number }` into reactive fields, where each one reads when called with
no argument and writes when called with one:

```lua
export type function Atomic(t: type): type
	if not t:is("table") then
		error(`[Atomic] expected a table, got {t.tag}`)
	end

	local out = types.newtable()
	for key, prop in t:properties() do
		local value = prop.read or prop.write
		if value ~= nil then
			local getter = types.newfunction({ head = {} }, { head = { value } })
			local setter = types.newfunction({ head = { value } }, { head = { value } })
			out:setproperty(key, types.intersectionof(getter, setter))
		end
	end
	return out
end

type _anchor = Atomic<{ Coins: number }>
```

```lua
type Profile = Atomic<typeof(Template)>

profile.Coins(100)     -- ok
print(profile.Coins()) -- number
profile.Coins("x")     -- Expected 'number', but got 'string'
```

The intersection of getter and setter avoids building a variadic pack, and a new
field on the Template shows up on its own.
