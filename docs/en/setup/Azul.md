# Azul

[Azul](https://github.com/Ransomwave/azul) is an alternative to Rojo where the
direction of the sync is inverted: **Studio is the source of truth** and the
filesystem mirrors what's there. You edit in VS Code or in Studio, and both
sides keep up.

The main reason to consider it isn't the sync itself — it's that **two people
can edit at the same time**.

```sh
npm install azul-sync -g
```

Besides the CLI you need to install the
[companion plugin](https://create.roblox.com/store/asset/79510309341601/Azul-Companion-Plugin)
in Studio — it doesn't ship in the npm package.

```sh
azul          # brings the daemon up and waits for Studio
azul build    # pushes the local project into Studio
azul pack     # serializes instance properties into the sourcemap
```

::: tip Tip
The template ships the `azul` task set ready to go:

`CTRL + SHIFT + P`, then `Tasks: Run Task`, then `azul`

It brings the daemon and `modux watch --sourcemap` up side by side. Details in
[VS Code](/en/setup/Vscode#tasks-json).
:::

## Two people at once

It works, and the path is this:

```
disk A -> azul A -> Studio A -> Team Create -> Studio B -> azul B -> disk B
```

Azul does **not** connect the two of you. Each person runs their own daemon, on
their own machine, with their own sync folder. What crosses over is **Team
Create**; Azul is just the endpoint on each side. Without Team Create, they're
two separate projects.

Measured with two Studio instances on the same place, each with its own daemon:

| | result |
|---|---|
| propagating one edit, full round trip | **1 second** |
| both editing **different files** | converges, identical hashes |
| both editing **the same file** | **diverges silently** |
| deleting a folder | the watcher survives |

::: danger The same file at the same time
Out of three attempts, two ended with each machine keeping its own version:

```
round 1 -> DIVERGED: A sees A, B sees B
round 2 -> converged on B
round 3 -> DIVERGED: A sees A, B sees B
```

After thirty seconds sitting still they were still different, and **neither log
recorded a warning** — I searched for `conflict`, `diverg`, `overwrite` and
`warn`, and there's nothing.

It isn't quite an Azul defect: Team Create resolves conflicts at the instance
level and Azul at the file level, and the two don't know about each other. The
practical result is that two editors in the same script is a minefield. Agree
on who touches what.
:::

## Two limits you'll hit on day one

**One daemon serves one Studio at a time.** It's in the code, not in the
configuration:

```js
if (this.client) {
    log.warn("Disconnecting previous client");
    this.client.close();
}
```

A second Studio on the same port disconnects the first. One daemon per person,
always.

**Disconnecting from the plugin kills the process.** Studio sends
`Studio requested daemon shutdown` and the daemon exits. Every reconnect means
running `azul` again in the terminal.

## Layout on disk

The sync directory mirrors the Studio tree. The default is `./sync`:

<FileTree title="azul layout" :paths="[
  'sync/ReplicatedStorage/Shared/ # whatever lives in ReplicatedStorage',
  'sync/ServerScriptService/Server/ # and so on',
  'sync/StarterPlayer/StarterPlayerScripts/',
  'sourcemap.json # written by azul, Rojo-compatible format',
]" />

Which means: **there is no `src/Feature/{client,server}`**. The feature-based
organization that [Rogen](/en/setup/Rogen) gives you doesn't survive here,
because the filesystem becomes the game tree. You can group by feature inside
each service, but then the feature is split across two roots.

::: warning `deleteOrphansOnConnect` is on by default
On connect, Azul deletes every file inside the syncDir that doesn't map to a
Studio instance:

```js
if (!mapped.has(path.resolve(fullPath))) {
    fs.unlinkSync(fullPath);
}
```

With the default configuration that only reaches `sync/`, so your source is
safe. The risk shows up if you point syncDir at the folder where your code
lives. Turn it off in `azul config` before doing that.
:::

## Modux with Azul

The generator needs to know where each file lands inside the game, and it
normally gets that from `default.project.json`. Azul produces no project file
at all — but it produces a sourcemap, and the sourcemap holds the same
information, in an even more direct form.

From **0.6.11** on there is a flag:

```sh
modux watch --sourcemap sourcemap.json --fix --nudge --interval 100
```

With it the generator reads the map from the sourcemap and **stops rebuilding
it**, because under Azul the sourcemap belongs to another process. Without the
flag, modux would overwrite Azul's map with one derived from a project file
that may not even exist.

Both paths produce the same map — there's a test comparing them file by file
across the whole template, 66 files, zero divergences.

### Where the framework lives

With no rogen there's no folder translation, so Modux has to be born at the
full path. From **0.6.11** on the generator assumes this layout on its own
when you pass `--sourcemap`:

<FileTree title="mirrored layout" :paths="[
  'sync/ServerScriptService/server/Modux/ # the framework, server side',
  'sync/StarterPlayer/StarterPlayerScripts/client/Modux/',
  'sync/ReplicatedStorage/shared/Modux/',
  'sync/ReplicatedStorage/shared/Libs/ # injected into self.Libs',
  'sync/ServerScriptService/server/Vital/VitalService/ # a module of yours',
]" />

It looks more verbose than `src/Modux/client`, and it is — but it lands on
exactly the same instances. The Manifest generated here requires
`ServerScriptService.server.Vital.VitalService.Type`, identical to the Rojo
flow. **None of your requires change.**

The scanned folder is `sync/` by default in this mode. If yours differs, use
`--source DIR`.

::: warning The two layouts don't coexist
`src/Feature/{client,server}` and `sync/ServerScriptService/...` are different
structures on disk. Both tasks sit side by side in `tasks.json`, but that
doesn't mean you can switch within one project: it's a per-project choice, and
changing later is a migration.
:::

### And the typing, with two people?

The natural question: if your teammate edits a module, does the `Type.luau`
arrive ready on your disk, or does your generator have to redo it?

**It arrives ready, and your generator agrees with it.** The generator is
deterministic — same input, same output, byte for byte — and it only writes
when the content differs from what's already there. So your modux recomputes,
reaches the same result, sees the file is already correct and writes nothing.
No loop, no write war.

::: warning The Manifest can flicker
`Type.luau` is per module, but the Manifest is **one file**, shared, listing
every module on that side.

If the other person's modux runs in the one-second window between your new
module existing and reaching them, it generates a Manifest **without** your
module, and that Manifest comes back and overwrites yours. Your modux
regenerates with the module, pushes back, and the two trade blows until the
disks agree.

It converges in seconds, but autocomplete oscillates during the window. If it
bothers you, only one person runs `modux watch` and the other receives the
types ready-made.
:::

## When to pick which

| | Rojo | Azul |
|---|---|---|
| source of truth | the filesystem | Studio |
| two people at once | no | yes, through Team Create |
| feature-based architecture | yes, via [Rogen](/en/setup/Rogen) | no, mirrors the DataModel |
| deleting a folder | [takes the watch down](/en/setup/Rojo#crash) | survives |
| project file | `default.project.json` | none |
| maturity | years of use | maintained by one person, recent |

Azul's own author says it's *"still a relatively new tool maintained by only
one person"*, and rougher than Rojo and Argon. Worth knowing before moving a
whole project.

### "What about a shared project?"

It depends on what shared means, and the two answers are opposites.

**The two of you typing at the same time, in the same session:** Azul. It's the
only path, and it works.

**A team working on the same code over time:** Rojo with git. The argument is
the measurement above: with Azul, two people in the same file lose work
silently. With git, a conflict is loud and blocks until someone resolves it.
You trade a silent loss for a visible interruption, and the second is far
better. You also keep the feature-based architecture and a mature tool.

Nothing stops you from using git with Azul — you version the `sync/` folder.
But then the repository becomes a mirror of the game tree, and the history gets
harder to read.
