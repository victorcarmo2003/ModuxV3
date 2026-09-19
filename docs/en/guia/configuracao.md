# Configuration

```lua
Modux.Start({ DebugLevel = "High", Profiling = true })
```

Or split apart, when the bootstrap needs to configure things first:

```lua
Modux.Configure({ DebugLevel = "Medium" })
Modux.Start()
```

Passing settings in both places is an error: `settings came from both Configure
and Start; use one of them`.

## Settings

```lua
type Settings = {
	Profiling: boolean?,
	DebugLevel: ("None" | "Low" | "Medium" | "High")?,
}
```

### DebugLevel

| value | shows | warns slow above |
|---|---|---|
| `None` | nothing | — |
| `Low` | total boot time | 100 ms |
| `Medium` | + singletons and required modules | 16.7 ms |
| `High` | + time of each `require` | 1 ms |

The slow warning applies to every `OnInit` and `OnStart` callback, with the
module's name:

```
[Modux] OnStart of "DataService" took 42.1 ms
```

### Profiling

Marks the phases in the MicroProfiler **and** categorizes memory by module, so
the Studio memory tab shows who allocated what.

```lua
Modux.Start({ Profiling = true })
```

## Modux.Stop()

Shuts the clock down, clears the ticks and tears the components down. Handy in
tests; in a shipped game it usually isn't called.

::: warning
`Stop` does not undo what your modules did. Service and Controller have no
`OnDestroy`, so a globally scoped resource they created stays alive.
:::

## Bootstrap

The bootstrap is one `Script` per side, and it's yours:

```lua
--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local Modux = require(ServerScriptService.server.Modux)

Modux.Start({ DebugLevel = "Medium", Profiling = false })
```
