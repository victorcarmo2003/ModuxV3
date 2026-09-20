# How the typing works

Modux infers nothing at runtime. The whole typing is assembled at analysis
time, by three pieces that fit together.

## The three pieces

### 1. The generator reads the AST

`modux generate` parses each module and writes its **leaf** to
`src/Types/<side>/<Id>.luau`. The leaf exports only the public surface:

```lua
export type Public = {
	Players: { Player },
	Joined: SignalLib.Signal<Player>, --> Yes, it does the require
	Watch: (self: Public, player: Player) -> (),
}
```

No inference: the generator reads what you wrote. A literal becomes the
literal's type, a function becomes the declared signature, and everything else
asks for a `::`.

### 2. The Manifest gathers the leaves

One Manifest per side indexes every leaf on that side:

```lua
export type AllServices = {
	PlayerService: PlayerService.Public,
	DataService: DataService.Public,
}
```

The leaf doesn't know the Manifest, and the Manifest doesn't know the core.
That one-way direction is what avoids a require cycle.

### 3. Type functions assemble the `self`

The type of `self` comes out of [`SelfOf.Build`](/en/tipagem/selfof), which
combines the module's own leaf with what the framework injects:

```lua
export type ServiceSelf<ID, P> = SelfOf.Build<
	index<Manifest.AllServices, ID>,
	{
		Dependencies: Pick.Table<Manifest.AllServices, SelfOf.RequireOf<P>>,
		Libs: Libs.Api,
		Components: Manifest.ComponentAccess,
	}
>
```

`index<AllServices, ID>` grabs the leaf by ID. [`Pick.Table`](/en/tipagem/pick)
slices the Manifest by the keys declared in `Require`. The result is a `self`
that knows exactly what that module has and what it reaches.

:::tip Info
Honestly, the hardest part was turning the strings into singletons inside a
table — that's why I left the Pick type public
:::

## The type library

Two folders, with different purposes.

**`src/Modux/shared/Types/`** — what the framework needs in order to exist.

| | |
|---|---|
| [`SelfOf`](/en/tipagem/selfof) | assembles the `self` from the leaf plus the extras |
| [`Pick`](/en/tipagem/pick) | slices the Manifest by the declared keys |

**`src/Shared/Types/`** — utilities for you to use in your own code.

| | |
|---|---|
| [`Struct`](/en/tipagem/struct) | `Partial`, `Required`, `Readonly`, `Mutable`, `Assign`, `Merge`, `Record`, `Rename`, `DeepPartial`, `DeepReadonly` |
| [`Union`](/en/tipagem/union) | `Exclude`, `Extract`, `NonNullable`, `KeyList`, `ValueList`, `Entries` |
| [`Occlude`](/en/tipagem/occlude) | `Keys` — drops fields by name |
| [`Atomic`](/en/tipagem/atomic) | `Of`, `Table` — each field becomes a getter/setter pair |

Nothing in `src/Shared/Types/` is required by the framework. Deleting it breaks
nothing beyond whoever was using it.

## The four hard rules

A type function is Luau running on a real VM during analysis. The dominant risk
**is not an error, it's silence** — most of the bugs compile clean and hand back
a slightly wrong type that surfaces three files away.

### `LuauSolverV2` is mandatory

Without the flag, type functions don't exist. `SelfOf.Build` never reduces,
`self` ends up untyped, and autocomplete returns **zero items** — no error and
no warning.

### The type function has to be instantiated in its own file

luau-lsp only evaluates an exported type function if it's used at least once in
the file that defines it. Without that it becomes `*error-type*` **in the LSP
only** — command-line analysis passes, and the editor completes nothing.

That's why every type file here ends with anchors:

```lua
type _anchorPartial = Partial<Example>
type _anchorRequired = Required<Example>
```

They aren't tests and they aren't examples. They're what makes the function
exist.

:::tip Info
It didn't actually happen every single time, but since it happened a few times
and using them in the module itself fixed it, I decided to keep them
:::

### A type function applied to a free generic doesn't reduce

This is the one that costs the most time, because the symptom lands far from the
cause:

```
Cannot add property 'Method' to table 'setmetatable<Build<Public, {...}>, ...>'
```

`function X:Method()` stops compiling in a file that was fine. What happened is
that `Build<...>` didn't reduce, and the reason is in the others.
| in `Build`'s extras | reduces? |
|---|---|
| a **generic** function as a direct field | **doesn't reduce** |
| a non-generic function | reduces |
| a generic **nested** inside a referenced alias | reduces |
| a **type function applied to a free generic** (`index<Instances, Name>`) | **doesn't reduce** |

The rule isn't "generics break it". It's an **unresolved type function
application** reachable from the extras. That's why [not every lib can get into
`self.Libs`](/en/arquitetura/libs#limit).

::: tip Info
The AI explains this part better than I can, but to sum it up: there are some
libs I couldn't inject into `self.Libs` because of their typefunctions, which
ended up messing a lot of things up. So in some cases the right move is just
requiring them directly.
:::

### `types` only exists inside the body

There's no `require`, and no access to a script variable. A helper has to be
pasted inside every function that uses it — repeating yourself there is correct,
not lazy.

The practical consequence: type functions **can't see each other**. One can't
call another.

The details and the catalogue of silent failures are in
[Writing your own](/en/tipagem/escrevendo).
