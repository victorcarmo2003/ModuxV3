# Tools and watcher setup

Putting the project together by hand, tool by tool. To start from the ready-made
template instead, see [Installation](/en/guia/instalacao).

Below I go through both ways of installing everything: the automatic one,
pulling from GitHub and just wiring it all up.
## Manual flow:
For the manual setup you need to download modux from the official repository on
the [Framework](https://github.com/victorcarmo2003/ModuxV3/tree/framework) fork
and drop it into src/

Yeah, it's pretty simple, because rogen's architecture is feature-based 😎🥂

Rokit:
```sh
rokit init        				# initializes rokit to download the tools
```
Then open the rokit.toml file and paste:
```toml
[tools]
wally = "UpliftGames/wally@0.3.2"
rojo = "rojo-rbx/rojo@7.7.0"
rogen = "ldgerrits/rogen@1.4.4"
modux = "victorcarmo2003/modux@0.6.11"
wally-package-types = "JohnnyMorganz/wally-package-types@1.6.2"
```
And finally run — updating rokit first, if you need to — and install:
```sh
rokit update                        # update if needed
rokit install        				# installs every tool
```

Extras:
```sh
wally install     # if the project has dependencies
rogen build       # generates default.project.json from the folders
modux generate    # generates the type leaves and the Manifest
rojo serve        # connects to Studio
```

While developing, the two watchers replace the two `build`/`generate`:

```sh
rogen watch
modux watch
```

And Rojo, which also runs the whole time:

```sh
rojo serve
```

The sourcemap doesn't belong here: luau-lsp already keeps it on its own, and a
second source leaves the editor behind — see
[VS Code](/en/setup/Vscode#tasks-json).

::: tip Tip
All three already come ready in the template's `tasks.json`, as a single task.

Using it in VS Code:

`CTRL + SHIFT + P`, then `Tasks: Run Task`, then `dev`

Since `dev` is the default build task, `CTRL + SHIFT + B` brings it up directly
too. Each watcher opens in its own panel, so you can read one's output without
losing the others.

Details on each task in [VS Code](/en/setup/Vscode).
:::

::: warning Order matters
`rogen build` comes **before** `modux generate`. `default.project.json` is
generated from the folder structure, and the generator resolves the requires'
paths from it. Out of order, the symptom is `Unknown require` on correct code.
:::




## Analysis outside Studio

`tools/analyze.ps1` runs the same engine as the editor over the whole project.

```sh
./tools/analyze.ps1
./tools/analyze.ps1 -Detail        # prints each error
./tools/analyze.ps1 -Filter "*Vital*"
```

```
engine: luau-lsp + Rojo sourcemap + Roblox definitions
total: 0 error(s), 0 cycle(s)
```

It runs `rogen build` and generates the sourcemap first, so no prep is needed.

::: warning What the analysis doesn't catch
Passing doesn't prove the types exist — it proves nothing errored. To know
whether `self` is really typed, write an access that **should** fail
(`self.Dependencies.ServiceINeverDeclared`) and confirm that it does.

It also catches nothing that's validated at runtime: network schemas, lifecycle
order, persistence. Those only show up running in Studio.
:::

## Rokit

Pins each tool's version in `rokit.toml`, one per entry.

```sh
rokit install
rokit add victorcarmo2003/modux
rokit update victorcarmo2003/modux
```

::: tip
`rokit install --force` rewrites **every** binary, and fails if one of them is
in use by a watcher. Prefer `rokit install` without the flag.
:::
