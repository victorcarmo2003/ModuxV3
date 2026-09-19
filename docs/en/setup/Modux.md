# Modux
Below I explain how the file generator's structure works, how it fills things
in, and some commands you can use.

## Watcher:
The watcher reads the contents of each module and from them generates the whole
structure of functions, parameters and some simple self values, then writes the
type leaves into a structure:
<FileTree title="generated structure" :paths="[
  'client/Controller/init.luau ',
  'client/Controller/Type.luau #(auto-generated)',
]" />

And it also fills in the Manifest. On the client side, for example:
```luau
local StarterScripts = game:GetService("StarterPlayer").StarterPlayerScripts
local Example = require(StarterScripts.client.Example.Controller.Type)

export type AllControllers = {
	Example: Example.Public,
}

export type AllComponents = {}

export type ComponentAccess = {}

return {}
```

The parser, which is what identifies and types things according to their values,
is built in — there's nothing to install alongside the binary.

## Commands

### > modux generate

Parses through every module, controller and service registered and generates
its type:
```sh
modux generate
#OUTPUT:
[modux] leaf: src/Player/server/PlayerService/Type.luau
[modux] manifest server: src/Modux/server/Manifest/init.luau (6 modules)
[modux] modules server: src/Modux/server/Modules.luau
[modux] libs: src/Modux/shared/Libs.luau
[modux] 118 ms
```

A file that's already correct isn't rewritten, so running it again prints:
```sh
[modux] up to date.
```

### > modux watch

Regenerates on every change until you stop it. It's what makes up the `dev` task
of the main template run by VS Code, and it's what you'll normally use.

```sh
modux watch
```

::: danger A watcher on an old version:
The process loads the binary the moment it comes up. After a `rokit update`, a
watcher still running is still on the old version and will **rewrite** the
generated files with the old behaviour — silently, over what you just
generated. Restart the watcher after updating!
:::

### > modux check
Works as an integrity check. It fails if anything on disk differs from what
`generate` would write. This is the command for CI.

```sh
modux check
#OUTPUT:
stale: src/Player/server/PlayerService/Type.luau
modux: 1 file(s) out of date. Run `modux generate`.
```
### > modux list

Lists the modules it found:

```sh
modux list
#[Module]      [Kind]     [Dependency]:
NetService     Service    src/Net/server/NetService/init.luau  deps: -
ProfileService Service    src/Profile/server/ProfileService/init.luau  deps: PlayerService, NetService
Vital          Component  src/Vital/server/Vital/init.luau  deps: VitalService
```

### > modux extract

Dumps a module's extracted shape as JSON. It's there to help you understand why
the generator read something different from what you expected.

For example, here's a Round controller, meant to follow along on the client side
and create a source with Vide:
```luau
--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Vide = require(ReplicatedStorage.Packages.Vide)
local Modux = require(StarterPlayer.StarterPlayerScripts.client.Modux)

export type Status = "Waiting" | "Playing" | "Ending"

const RoundController = Modux.Controller("RoundController", { Priority = 800 })

function RoundController:Setup()
	self.Status = Vide.source("Waiting") :: Vide.Source<Status>
	self.Seconds = Vide.source(0) :: Vide.Source<number>
end

RoundController:OnInit(function(self)
	self:Setup()

	self.Libs.Net.Round:onClient(function(payload)
		self.Status(payload.Status)
		self.Seconds(payload.Seconds)
	end)
end)

return RoundController
```
Running extract:
```sh
modux extract src/Round/client/RoundController/init.luau
#OUTPUT:
{
  "id": "RoundController",
  "kind": "Controller",
  "file": "C:/Users/hakor/Documents/GitHub/ModuxTemplate/src/Round/client/RoundController/init.luau",
  "services": [
    {
      "alias": "ReplicatedStorage",
      "service": "ReplicatedStorage"
    },
    {
      "alias": "StarterPlayer",
      "service": "StarterPlayer"
    }
  ],
  "requires": [
    {
      "alias": "Vide",
      "expr": "ReplicatedStorage.Packages.Vide"
    },
    {
      "alias": "Modux",
      "expr": "StarterPlayer.StarterPlayerScripts.client.Modux"
    }
  ],
  "local_types": [
    {
      "name": "Status",
      "text": "export type Status = \"Waiting\" | \"Playing\" | \"Ending\""
    }
  ],
  "methods": [
    {
      "name": "Setup",
      "signature": "(self: Public) -> ()"
    }
  ],
  "fields": [
    {
      "name": "Seconds",
      "ty": "Vide.Source<number>"
    },
    {
      "name": "Status",
      "ty": "Vide.Source<Status>"
    }
  ],
  "dependencies": [],
  "declared_require": [],
  "issues": []
}
```
