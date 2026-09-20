# Controllers

Runs on the **client**, one per game. Reaches other Controllers and the client's
Components.

```lua
--!strict
local StarterPlayer = game:GetService("StarterPlayer")
local Modux = require(StarterPlayer.StarterPlayerScripts.client.Modux)

const Camera = Modux.Controller("Camera", { Require = { "Input" } })

function Camera:Shake(power: number)
	self.Dependencies.Input:Rumble(power)
end

Camera:OnInit(function(self)
	self.Shaking = false :: boolean
end)

return Camera
```

**Type**

```lua
function Modux.Controller<ID, P>(
	id: ID & ControllerKey,
	props: (P | ControllerProps)?
): ControllerReturn<ID, P>

type ControllerProps = {
	Require: { ControllerKey },
	Priority: number?,
}
```

For the require, `ID` has to be one of the Controllers that exist in the
project. A name that doesn't exist won't compile — the client Manifest is the
closed list.

## Where the file lives

Any folder under `src/` that has `client` in its path:

<FileTree :paths="[
  'src/Camera/client/Camera/init.luau',
  'src/Input/client/InputController.luau',
]" />

## What it reaches

| | |
|---|---|
| `self.Dependencies` | the Controllers declared in `Require` |
| `self.Components` | every Component visible on the client |
| `self.Libs` | whatever is in `src/Libs` |

A Controller that declares a `Require` on a Service **halts generation**. If the
client needs something only the server has, that's networking — see
[Dependencies](/en/arquitetura/dependencias#sides-don-t-cross).
