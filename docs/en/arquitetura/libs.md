# Libs

The core doesn't require Promise, Signal or networking. It requires a file the
generator writes by sweeping `src/Libs`, and injects the result into
`self.Libs`:

```lua
self.Libs.Signal.new()      -- typed, no require in your file
self.Libs.DoesNotExist      -- Key 'DoesNotExist' not found
```

The lib doesn't have to satisfy any contract — the type comes out of
`typeof(require(...))`. Promise exports `PromiseAPI`, Signal exports `Api`, and
neither of them had to change to get in.

Deleting a lib from the folder doesn't break the framework: the entry drops out
of the type and whoever used it fails in the right place. That's basically what
unhooks Modux from fixed libs, unlike the first version where I baked Lync in as
part of it (and right after that the owner shipped a better version 🫠).

## What gets in

Each entry in `src/Libs` becomes a key:

```
src/Libs/Signal/init.luau   ->  self.Libs.Signal
src/Libs/Promise/init.luau  ->  self.Libs.Promise
src/Libs/FSM.luau           ->  self.Libs.FSM
```

A folder with an `init.luau` or a loose `.luau` file — both count.

A project with no `src/Libs` generates `Api = {}` and `self.Libs` comes up
empty, without breaking.

## Not every lib can get in {#limit}

The AI explains this part better than I can, but to sum it up: there are some
libs I couldn't inject into `self.Libs` because of their typefunctions, which
ended up messing a lot of things up. So in some cases the right move is just
requiring them directly.

::: danger The symptom doesn't point at the cause
A lib whose type contains an **unreduced type function** stops `SelfOf.Build`
from reducing, and the error shows up in **every** module in the project, on
methods that have nothing wrong with them:

```
Cannot add property 'Setup' to table 'setmetatable<Build<Public, {...}>, ...>'
```

The message never mentions the lib at fault.
:::

Cases measured, putting each lib into `self.Libs` on its own:

| lib | passes? | why |
|---|---|---|
| Signal, Promise, FSM | yes | ordinary types |
| Charm | yes | `Atom<T>` is a function, no type function inside |
| Vide | **no** | `Vide.create` is `<Name>(...) -> index<Instances, Name>` |
| Lync | **no** | nearly every key, because of `Codec<T>` |

`Lync.int` is just `(number, number) -> Codec<number>`, with no free generic at
all, and it still breaks: what counts is the pending type function **inside**
`Codec<T>`, not the shape of the signature.

The way out is requiring those directly where you use them:

```lua
local Vide = require(ReplicatedStorage.Packages.Vide)
```

What can't get in is the **whole module**, not each of its types. `Lync.Group`
and `Lync.Recipient` go through `Build` without trouble and can show up in a
method signature.

::: tip Diagnosis
Did the whole project start reporting `Cannot add property` after you touched
`src/Libs`? The suspect is the last lib that went in.
:::
