# Lifecycle

`OnInit` → `OnStart` → `OnTick` → `OnDestroy (for components)` 

Injection happens **before** any `OnInit`, which is what makes a mutual
dependency A↔B work: by the time your code runs, everything already exists.

The loader finishes **every** `OnInit` before starting any `OnStart`, and orders
both phases by descending `Priority`. That's what lets you say "register in
`OnInit`, fire in `OnStart`" and be sure of the order.

## OnInit()

```lua
function M:OnInit(callback: (self) -> ())
```

Setup for the module itself. Registering a handler, creating a signal, building
state.

## OnStart()

```lua
function M:OnStart(callback: (self) -> ())
```

Runs once every `OnInit` has finished. This is where you can count on the rest
of the game existing.

::: tip A useful pattern
A module with a high `Priority` runs the **first** `OnInit` and `OnStart`.
That's the right way to guarantee data, like the `start()` of a networking lib.
:::

## OnTick()
OnTick works the same way as OnInit and OnStart, registering a callback to be
loaded later, except it can also carry a tickrate to work at whatever pace you
need.
```lua
function M:OnTick(callback: (self, deltaTime: number) -> (), tickRate: number?, priority: number?)
```
TickRate and Priority are optional; the default is 1 Hz and priority 1.

A higher `priority` runs first, and ties break by registration order —
deterministic, and it doesn't shift when another module shows up.

The tick's `priority` is independent of the module's `Priority`. A module can
want the first `OnStart` and the **last** tick of the frame:

```lua
const Net = Modux.Service("Net", { Priority = 1000 })

Net:OnTick(function(self)
	self:Flush()
end, 60, -1000)
```
That's an example of how the Lync lib uses it

## OnDestroy()

```lua
function M:OnDestroy(callback: (self) -> ())
```

**Only exists on Component.** Service and Controller are singletons and don't
have this phase, which means a reactive `effect`, for instance, has nowhere to
be released.

## Convention

Players already on the server when the game comes up should be swept in
`OnStart`, not in `OnInit`, if you want the guarantee:

```lua
PlayerService:OnInit(function(self)
	Players.PlayerAdded:Connect(function(p) self:Watch(p) end)
end)

PlayerService:OnStart(function(self)
	for _, p in Players:GetPlayers() do
		self:Watch(p)
	end
end)
```

Sweeping in `OnInit`, the lower-priority modules that haven't hooked up their
handlers and events yet will miss whoever is already connected to the game.
