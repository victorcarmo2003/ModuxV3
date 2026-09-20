# Components
Components are one-sided, for server and for client.

A Component is bound to an `Instance` through CollectionService, and there's one
per tagged instance. With no `Tag` declared, the tag is the ID itself.

```lua
const Highlight = Modux.Component("Highlight", { Require = { "Render" } })

function Highlight:TurnOn()
	self.Instance.Color = Color3.new(1, 1, 0)
end

Highlight:OnDestroy(function(self)
	self.Instance.Color = Color3.new(1, 1, 1)   -- release what TurnOn took
end)

return Highlight
```

`self.Instance` always exists and is always the instance the object was built
for.

## Reaching it from outside

Any module reaches components through `self.Components`, typed by ID:

```lua
self.Components.Highlight:Get(part)       -- the object, or nil
self.Components.Highlight:Create(part)    -- builds and returns right away
self.Components.Highlight:All()           -- every live one
self.Components.Highlight:Destroy(part)   -- tears it down and drops the tag
```

`Create` builds and returns **on the same line**, because `AddTag` only fires on
the next frame and waiting on that is a hack. It's also duplicate-safe: if the
object already exists for that instance, it hands back the existing one.

From inside the component itself, `self:Destroy()` does the same as
`self.Components.X:Destroy(self.Instance)`.

## When components come up

A component tagged in Studio comes up **after** every singleton has started.
`Create` called from an `OnInit` works too: the templates already received
`Dependencies`, `Libs` and `Components` before the loader ran.

## Lifecycle

Component is the only kind with `OnDestroy`. It fires when the tag goes away, or
when someone calls `Destroy`.

Creating and destroying in the same frame is safe: the manager checks the tag's
current state before building or tearing down, so a pending CollectionService
signal doesn't resurrect an object that's already dead.

## Networking, in a component

A component should **not** register a network responder. It comes up after the
networking lib has started, and a responder is usually unique by definition —
one per instance would be wrong anyway. It's just a convention.
