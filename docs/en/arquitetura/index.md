# Architecture

A module is a folder with an `init.luau` that declares its kind and returns
itself. There are three kinds, and what tells them apart is where they run and
what they can reach.

| | runs on | exists | reaches |
|---|---|---|---|
| **Controller** | client | one per game | other Controllers |
| **Service** | server | one per game | other Services |
| **Component** | both | one per tagged `Instance` | Controllers on the client, Services on the server |

Sides don't cross, and that isn't a convention: a Controller that declares a
`Require` on a Service **halts generation**, with a message saying who is on
which side.


Each one has its own page: [Controllers](/en/arquitetura/controllers),
[Services](/en/arquitetura/services) and
[Components](/en/arquitetura/componentes). What holds for all three is below.

## Where to declare a field

The generator only sees `self.X = ...` inside a **declared method**. These three
forms count:

```lua
function M:Name() end
function M.Name() end
M.Name = function() end
```

`M:OnInit(function(self) ... end)` is **not** one of them — it's a function call,
and a field assigned in there doesn't make it into the type, silently.

The pattern that works is declaring it in a method and calling that from
`OnInit`:

```lua
function PlayerService:Setup()
	self.Players = {} :: { Player }
	self.Joined = self.Libs.Signal.new() :: SignalLib.Signal<Player>
end

PlayerService:OnInit(function(self)
	self:Setup()
end)
```

::: tip Tip:
A field that doesn't show up in autocomplete was almost always assigned outside
a declared method.
:::

## Helper file

A `.luau` file that doesn't contain `.Service("`, `.Controller("` or
`.Component("` is ignored by the generator. A `Template.luau` next to the module
is safe.
