# Dependencies

A module declares what it needs in `Require`, and receives it in
`self.Dependencies`, already typed.

```lua
const Zombie = Modux.Controller("Zombie", { Require = { "Skeleton", "Camera" } })

function Zombie:Attack()
	self.Dependencies.Skeleton:ShootArrow()
	self.Dependencies.Camera:Shake(2)
end
```

`self.Dependencies` holds **exactly** what was declared. Reaching for a module
that exists but wasn't declared is an analysis error:

```lua
self.Dependencies.Inventory:Add(item)
-- Key 'Inventory' not found in table '{ read Skeleton: ..., read Camera: ... }'
```

That comes out of [`Pick.Table`](/en/tipagem/pick), which slices the side's
Manifest by the declared keys.

## Injection before OnInit

Everything is injected before any `OnInit` runs, so a mutual dependency works:

```lua
const A = Modux.Controller("A", { Require = { "B" } })
const B = Modux.Controller("B", { Require = { "A" } })
```

What **doesn't** work is one using the other while the file is loading. From
`OnInit` onward, both exist.

:::tip Info
If you eventually need one to load before the other because some data has to be
generated or something like that, one of the props is the load priority —
higher goes first. For example:
```lua
const A = Modux.Controller("A", { Require = { "B" }, Priority = 100 })
const B = Modux.Controller("B", { Require = { "A" }, Priority = 50 })
```
In this case A loads first. There's more on this further down.
:::

## Sides don't cross
One of the things that let this version scale further was splitting the manifest
between client side and server side — that's why there's a copy on each — and as
a bonus Controllers can't require a Service and Services can't require a
Controller, since one lives on the server and the other on the client.

A Controller that declares a `Require` on a Service halts modux generation in
the CLI:

```
[Manifest] src/Ui/client/Hud/init.luau is client and requires "DataService",
which is server.
  client cannot see server — move one of them, or go through the network.
```

It isn't a convention and it isn't a lint: the generator stops. The side comes
out of the folder path, so moving the file to server or client and switching it
to controller or service is what fixes it.

## Priority

`Priority` decides the order of `OnInit` and `OnStart` — higher runs first. The
default is `1`.

Priority is **not** a dependency. Declaring `Require` guarantees the module
exists and is injected; `Priority` only controls who runs the phase first. Use
`Require` to reach, `Priority` to order.

```lua
const Net = Modux.Service("Net", { Priority = 1000 })     -- first
const Player = Modux.Service("Player", { Priority = 900 })
const Data = Modux.Service("Data", { Require = { "Player" }, Priority = 800 })
```
