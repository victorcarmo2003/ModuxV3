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
modux = "victorcarmo2003/ModuxWatcher@0.7.3"
wally-package-types = "JohnnyMorganz/wally-package-types@1.6.2"
```

The `rojo` up there is the transport to Studio, and it's the default. If
there are two of you on the same place, swap it (or add to it) with one of
the alternatives:

```toml
syncteam = "victorcarmo2003/SyncTeam@0.2.6"   # two-way sync, with leases
```

[SyncTeam](/en/setup/SyncTeam) uses the same `default.project.json` and the
same `init.luau`, so nothing else on this page changes — only the command
left running in place of `rojo serve`. [Azul](/en/setup/Azul) also solves two
people, but asks for a different disk layout.
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
rogen build       # again, only the FIRST time — see below
modux generate
rojo serve        # connects to Studio
```

::: warning Only on the project's first generation
That repeated pair isn't a mistake. Since modux **0.7.0** the type leaves live
in `src/ModuxTypes/`, and `rogen` derives `default.project.json` from the folder
structure — it only sees a folder once that folder holds a `.luau`. In a
project where `src/ModuxTypes/` doesn't exist yet, the first `modux generate`
writes the leaves but finds no DataModel address for them:

```
modux: path outside default.project.json: src/ModuxTypes/client/MyController.luau
```

The next `rogen build` maps them, and the second `modux generate` closes it.
From the second time on, one pass is enough.

**Cloning the template never hits this** — the leaves are committed there, so
the first `rogen build` already sees the folder.

In the **watchers** (`CTRL + SHIFT + B`) the cold start resolves itself, but
it's worth knowing how: `rogen watch` and `modux watch` come up together, and
which one lands first is a race. If rogen's initial build runs after modux
writes the leaves, it closes right away. If it runs before, modux prints
`waiting for rogen to pick up the leaves folder` and waits — your first save
rebuilds the project file, modux reloads the map and it closes there.

In neither case does the watcher die. Up to **0.7.2** it did: the first pass
exited with `path outside default.project.json` before the loop began, and
the VS Code task closed on its own explaining nothing. Fixed in **0.7.3**.
:::

While developing, the two watchers replace the two `build`/`generate`:

```sh
rogen watch
modux watch
```

And the transport, which also runs the whole time — `rojo serve`, or the
daemon of whichever alternative you picked:

```sh
rojo serve                     # Rojo flow
syncteam start --dir .         # SyncTeam flow
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
rokit add victorcarmo2003/ModuxWatcher
rokit update victorcarmo2003/ModuxWatcher
```

::: warning Rokit asks for trust once per tool
The first time it refuses with `has not been marked as trusted`. Just run
`rokit add` again in an interactive terminal and accept, or
`rokit trust victorcarmo2003/ModuxWatcher` before `rokit install`.

If you're coming from **0.6.x**, this happens again even though you already
accepted once: the repository was called `victorcarmo2003/modux` up to 0.7.0,
and Rokit treats the new name as a **different** tool — it doesn't follow
GitHub's redirect.
:::

::: tip
`rokit install --force` rewrites **every** binary, and fails if one of them is
in use by a watcher. Prefer `rokit install` without the flag.
:::
