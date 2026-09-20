# Services

Runs on the **server**, one per game. Reaches other Services and the server's
Components. The shape is identical to a Controller; what changes is the side.

```lua
--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local Modux = require(ServerScriptService.server.Modux)

const Data = Modux.Service("Data", { Require = { "Player" }, Priority = 800 })

function Data:Save(player: Player)
	self.Dependencies.Player:Touch(player)
end

Data:OnInit(function(self)
	self.Sessions = {} :: { [Player]: any }
end)

return Data
```

**Type**

```lua
function Modux.Service<ID, P>(
	id: ID & ServiceKey,
	props: (P | ServiceProps)?
): ServiceReturn<ID, P>

type ServiceProps = {
	Require: { ServiceKey },
	Priority: number?,
}
```

## Where the file lives

Any folder under `src/` that has `server` in its path:

<FileTree :paths="[
  'src/Profile/server/ProfileService.luau',
  'src/Profile/server/ProfileService/Template.luau # helper',
]" />

## Priority matters more here

On the server it's common to have a startup order: whoever opens the data
session needs to exist before whoever reads from it. A higher `Priority` runs
`OnInit` and `OnStart` first.

```lua
const Net = Modux.Service("Net", { Priority = 1000 })
const Player = Modux.Service("Player", { Priority = 900 })
const Data = Modux.Service("Data", { Require = { "Player" }, Priority = 800 })
```

`Priority` does **not** interfere with the dependency. Declaring `Require`
guarantees the module exists and will be injected normally; `Priority` only
controls who runs the phase first.

See [Lifecycle](/en/arquitetura/ciclo-de-vida).
