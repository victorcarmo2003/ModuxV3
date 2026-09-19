# VS Code
If you pulled from the template, these steps are already configured!

It's only 4 files. If you put the project together by hand, these are the ones
missing.

<FileTree title="editor configuration" :paths="[
  '.vscode/extensions.json # recommended extensions',
  '.vscode/settings.json # luau-lsp flags',
  '.vscode/tasks.json # the watchers',
  '.luaurc # strict mode',
]" />

## extensions.json

```json
{
	"recommendations": [
		"JohnnyMorganz.luau-lsp",
		"JohnnyMorganz.stylua"
	]
}
```

VS Code suggests both when you open the project. The first is the analyzer that
does all the type work; the second is the formatter.

## settings.json

```json
{
    "luau-lsp.studioPlugin.enabled": true,
    "luau-lsp.sourcemap.enabled": true,
    "luau-lsp.sourcemap.autogenerate": true,
    "luau-lsp.studioPlugin.port": 3668,
    "luau-lsp.sourcemap.sourcemapFile": "sourcemap.json",
    "luau-lsp.fflags.enableNewSolver": true,
    "luau-lsp.fflags.sync": true,
    "luau-lsp.completion.anonymousAutofilledFunction.enabled": true,
    "[lua]": {
        "editor.defaultFormatter": "JohnnyMorganz.stylua"
    },
    "[luau]": {
        "editor.defaultFormatter": "JohnnyMorganz.stylua"
    },
    "modux.studioBridge.port": 9001,
    "editor.formatOnSave": true,
    "files.autoSave": "afterDelay",
    "files.autoSaveDelay": 300, // sets how fast the LSP updates
}
```

What each group does:

| key | |
|---|---|
| `fflags.enableNewSolver` | turns on `LuauSolverV2`. **Without it Modux types nothing** |
| `fflags.sync` | pulls the other flags from Roblox, so the editor matches the runtime |
| `sourcemap.*` | where the sourcemap is and whether the editor regenerates it itself |
| `studioPlugin.*` | receives from Studio the instances that don't exist in `src/`, like whatever you build by hand |
| `anonymousAutofilledFunction` | fills in the whole signature when you accept a callback |

::: danger enableNewSolver isn't a preference
Type functions don't exist in the old solver. Without the flag, `self` ends up
untyped and autocomplete returns **zero items** — no error, no warning, just
nothing.

It's the most expensive thing to diagnose in the framework, because it produces
no message at all. Empty autocomplete? Check this line before anything else.
:::

The sourcemap's `autogenerate` and a `sourcemap watch` task do the same thing.
Keeping both breaks nothing, but it's duplicated work — if you use the `dev`
task, you can leave `autogenerate` at `false`.

## tasks.json

Two sets, one per way of syncing. You run **one or the other**, never both at
once — they would fight over the same `sourcemap.json`.

### `rojo` — the filesystem is in charge

This is the default flow, and the build task, so `CTRL + SHIFT + B` brings it
up.

| task | |
|---|---|
| `rogen watch` | regenerates the project file when a folder changes |
| `modux watch --fix --nudge` | regenerates leaves and Manifest; moves a new module into its own folder |
| `rojo serve` | serves to Studio |

```json
{
	"label": "rojo",
	"dependsOn": ["rogen watch", "modux watch", "rojo serve"],
	"dependsOrder": "parallel",
	"group": { "kind": "build", "isDefault": true }
}
```

### `azul` — Studio is in charge

For when you use [Azul](/en/setup/Azul), including editing as a pair.

| task | |
|---|---|
| `azul sync` | the daemon, waiting for the Studio plugin to connect |
| `modux watch --sourcemap` | reads the map from Azul's sourcemap instead of the project file |

```json
{
	"label": "azul",
	"dependsOn": ["azul sync", "modux watch (sourcemap)"],
	"dependsOrder": "parallel",
	"group": "build"
}
```

There's no `rogen` and no `rojo serve` here: Azul is the transport and the
sourcemap is its own. The `--sourcemap` flag is what stops modux from
rebuilding the map over it — see
[Azul](/en/setup/Azul#modux-with-azul).

::: tip The `dev` task still exists
It became an alias for `rojo`, so nobody's muscle memory breaks.
:::

::: danger Don't add a sourcemap task
`luau-lsp.sourcemap.autogenerate` already has the server bringing up **its own**
`rojo sourcemap --watch`, and `useVSCodeWatcher: false` means it trusts that
process to know when to reload.

A task doing the same thing puts two rojos writing the same `sourcemap.json`,
and the server only listens to notifications from its own. The symptom is the
one that costs the most to diagnose: `Type.luau` gets rewritten right away, but
autocomplete keeps showing the previous state.

If it lags behind anyway: `CTRL + SHIFT + P` and **Luau: Reload Language
Server**.
:::

::: tip Tip
`CTRL + SHIFT + P`, then `Tasks: Run Task`, then `rojo` or `azul`

Since `rojo` is the default build task, `CTRL + SHIFT + B` brings it up
directly.
:::

::: warning A watcher holds on to the old version
The process loads the binary the moment it comes up. After a `rokit update`, a
watcher still running is still on the old version and will **rewrite** the
generated files with the old behaviour, silently, over what you just generated.

Restart the task (`rojo` or `azul`) after updating any tool.
:::

## .luaurc

```json
{
	"languageMode": "strict"
}
```

Puts the whole project in strict mode without needing `--!strict` in every
file. The framework's files carry the directive anyway, in case they get copied
into a project that doesn't have this file.

## .rogen.json

Documented on the [Rogen](/en/setup/Rogen) page, next to the tool that reads it.
