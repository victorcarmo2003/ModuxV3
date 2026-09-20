# Modux
Below I explain how the file generator's structure works, how it fills things
in, and some commands you can use.

## Watcher:
The watcher reads the contents of each module and from them generates the whole
structure of functions, parameters and some simple self values, then writes the
type leaves into a structure:
<FileTree title="generated structure" :paths="[
  'src/Example/client/ExampleController.luau # yours',
  'src/ModuxTypes/client/ExampleController.luau #(auto-generated)',
]" />

The leaf doesn't sit next to the module: it goes to
`src/ModuxTypes/<side>/<Id>.luau`, addressed by ID. That's why a module can be a
loose file — up to **0.6.11** the folder was mandatory only so two neighbouring
modules wouldn't fight over the same `Type.luau`.

And it also fills in the Manifest. On the client side, for example:
```luau
local StarterScripts = game:GetService("StarterPlayer").StarterPlayerScripts
local Example = require(StarterScripts.client.Types.ExampleController)

export type AllControllers = {
	ExampleController: Example.Public,
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
[modux] leaf: src/ModuxTypes/server/PlayerService.luau
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
stale: src/ModuxTypes/server/PlayerService.luau
modux: 1 file(s) out of date. Run `modux generate`.
```
### > modux list

Lists the modules it found:

```sh
modux list
#[Module]      [Kind]     [Dependency]:
NetService     Service    src/Net/server/NetService.luau  deps: -
ProfileService Service    src/Profile/server/ProfileService/init.luau  deps: PlayerService, NetService
Vital          Component  src/Vital/server/Vital.luau  deps: VitalService
```

`ProfileService` shows up as a folder on purpose: it keeps a `Template.luau` of
its own. A module with a sibling stays a folder, a module on its own is a file,
and both shapes give the same instance.

### > modux fix

Flattens every module still living alone inside a folder: `Foo/init.luau`
becomes `Foo.luau`. This is the migration command for anyone coming from
**0.6.11**.

```sh
modux fix --dry-run    # lists what would move, touching nothing
modux fix
#OUTPUT:
[modux] src/Net/server/NetService/init.luau  ->  src/Net/server/NetService.luau
[modux] kept src/Profile/server/ProfileService/init.luau: ... still holds Template.luau — left as a folder on purpose
[modux] folha anterior a 0.7.0 removida: src/Profile/server/ProfileService/Type.luau
[modux] run `modux generate` to write the leaves in their new place,
[modux] then `rogen build` again so Types/ enters the project file
```

A folder holding another file is **not** flattened — that one is yours. And the
old `Type.luau` is removed even from a module that kept its folder: it would
otherwise become an outdated copy of the type that nobody writes any more.

::: warning The two steps after fix aren't optional
`rogen` derives the project file from the folder structure, and only sees
`src/ModuxTypes/` once there's a `.luau` inside it. So the first migration needs
`modux generate` (which writes the leaves) and `rogen build` **again** (which
maps them). Cloning the template skips all of this, because the leaves are
committed there.
:::

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
modux extract src/Round/client/RoundController.luau
#OUTPUT:
{
  "id": "RoundController",
  "kind": "Controller",
  "file": "C:/Users/hakor/Documents/GitHub/ModuxTemplate/src/Round/client/RoundController.luau",
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
