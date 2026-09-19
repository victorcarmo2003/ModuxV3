# Installation

The short path is cloning [ModuxTemplate](https://github.com/victorcarmo2003/ModuxTemplate),
which already ships with the tools pinned, the dependencies declared and the
framework inside.

## Template
Start by cloning the GitHub repository into a folder of yours. For example,
inside Documents, create a folder called `RobloxGames` and inside it `MyGame`.
Open VS Code on that folder and open the terminal with:

<div class="shortcut">
	<kbd>CTRL</kbd> + <kbd>SHIFT</kbd> + <kbd>`</kbd>
</div>

Or through the command palette:

<div class="shortcut">
	<kbd>CTRL</kbd> + <kbd>SHIFT</kbd> + <kbd>P</kbd>
</div>

And searching for: `Terminal: Create New Terminal`

### Cloning
In your new terminal, clone the GitHub repository with:
```sh
git clone https://github.com/victorcarmo2003/ModuxTemplate .
```
::: warning Heads up
If this command fails saying the folder has content even after you deleted every
file, it probably has a hidden file such as `.git`. Below I explain how to get
rid of it.
:::


### Configuring
The clone brings the template's history and remote along. To make the project
yours:
```sh
rm -rf .git                      # drops the template's history
git init && git add -A
git commit -m "first commit"
```
::: tip Tip
The `rm` command may ask for administrator permission. One way around it is
running VS Code as administrator, or deleting it by hand through the explorer.
:::


### Installing
Three lines, one per step:
```sh
rokit install          # downloads the tools pinned in rokit.toml
./tools/packages.ps1   # Wally dependencies, and their typing
modux generate         # type leaves and Manifest
```
### By hand
To put everything together manually, without the GitHub template, follow the
steps in [Setup](/en/setup/).

## Developing
### Shortcut
Nothing else to run by hand. Inside VS Code:

<div class="shortcut">
	<kbd>CTRL</kbd> + <kbd>SHIFT</kbd> + <kbd>B</kbd>
</div>

That fires up the `dev` task, which brings all three processes up at once, each
in its own panel:

| | |
|---|---|
| `rogen watch` | regenerates the project file when you create or move a folder |
| `modux watch --fix` | regenerates leaves and Manifest, and moves a new module into its own folder |
| `rojo serve` | connects to Studio |

Generating the sourcemap isn't in there on purpose: luau-lsp already keeps its
own, and a second source leaves the editor behind — see
[VS Code](/en/setup/Vscode#tasks-json).

From there it's just writing: saving a file already rebuilds the types and
Studio gets them.

::: tip If the shortcut does nothing
It depends on `dev` being marked as the default build task, which the template
already ships.

The long way around:
`CTRL + SHIFT + P`, then `Tasks: Run Task`, then `dev`

Details on each task in [VS Code](/en/setup/Vscode).
:::

And that's it! You can start writing.

### Heads up
::: warning New packages
After adding new packages to wally and installing them, always run:

`wally-package-types --sourcemap sourcemap.json Packages/ ServerPackages/ DevPackages/`

More on this in the [Wally](/en/setup/Wally) section.
:::

## What's inside

<FileTree title="modux template" :paths="[
  'src/Modux/ # the framework',
  'src/Libs/ # injected into self.Libs',
  'src/Shared/Types/ # Struct, Union, Occlude, Atomic',
  'src/Net/ # Lync: definitions, start and flush',
  'src/Player/ # players joining and leaving',
  'src/Profile/ # ProfileStore with reactive fields',
  'src/Vital/ # Health, Armor, Stamina',
  'src/Round/ # round cycle in Charm atoms',
  'src/Input/ # ContextActionService with context',
  'src/Interface/ # Vide components and UI Labs stories',
]" />

## Framework

The `framework` branch has exactly the contents of `src/Modux` at its root, so
you can pull it straight into a project of yours:

```sh
git clone -b framework https://github.com/victorcarmo2003/ModuxV3 src/Modux
```

The first command after the clone is `modux generate`. Without it the Manifest
is still the one from the source repository, and the editor complains about
modules that don't exist here.

That way you get only the framework — the tools, the dependencies and the type
utilities are on you. See [Setup](/en/setup/).

## Warnings
### `LuauSolverV2`

Type functions don't exist in the old solver. Without the flag, `self` ends up
untyped and autocomplete returns **zero items** — no error, no warning, just
nothing.

```json
{
	"luau-lsp.fflags.enableNewSolver": true
}
```

::: warning WARNING:
This is the most expensive thing to diagnose in the whole framework, because it
produces no message at all. If autocomplete is empty, check the flag before
anything else.
:::

The template already ships this and the rest of `.vscode` ready to go — see
[VS Code](/en/setup/Vscode).

### Where your modules go

In any folder under `src/`, and the side comes out of the path: a `client`
folder goes to StarterPlayerScripts, `server` to ServerScriptService, and
everything else is shared.

<FileTree title="one feature" :paths="[
  'src/Vital/client/VitalController/init.luau',
  'src/Vital/server/VitalService/init.luau',
  'src/Vital/server/Vital/init.luau # component',
]" />

A module is a folder with an `init.luau`, never a loose file: the generator
writes `Type.luau` next to the module, and two modules in the same folder would
collide on that name.

## Generated, don't edit

Four files are generator output and get rewritten on every `modux generate`:

<FileTree title="generator output" :paths="[
  'src/Modux/client/Manifest/init.luau # generated',
  'src/Modux/client/Modules.luau # generated',
  'src/Modux/server/Manifest/init.luau # generated',
  'src/Modux/server/Modules.luau # generated',
  'src/Modux/shared/Libs.luau # generated',
  'src/Vital/server/VitalService/init.luau # yours',
  'src/Vital/server/VitalService/Type.luau # generated',
]" />

One `Type.luau` per module of yours, right beside it.

::: tip Why a script for the packages
`wally install` rewrites the `Packages/` shims from scratch, and in doing so
wipes what `wally-package-types` had written. The packages' typing disappears
silently: `Charm.atom` keeps resolving and `Charm.Atom` becomes `Unknown type`.

Running the second tool after the first isn't enough, because the order has four
steps — `wally-package-types` needs the sourcemap, which needs
`default.project.json`, which comes out of `rogen`. The script chains all four
and counts how many shims ended up re-exporting types.

Run it again **after every `wally install`**, or use
`./tools/packages.ps1 -SkipInstall` when only the shims need redoing.
:::
