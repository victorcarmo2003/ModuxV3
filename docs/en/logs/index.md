# Logs

What changed in the tools you install, and why. Newest version at the top.

This isn't a generated changelog: versions that only bump appear as a block,
and the ones that actually change something get the reason. If you want the
raw diff, every heading links to its release.

## ModuxWatcher

The type generator, installed as `modux` by Rokit.

### 0.7.3 {#modux-0-7-3}

[release](https://github.com/victorcarmo2003/ModuxWatcher/releases/tag/v0.7.3)
· Sep 20

**`modux watch` stopped dying on the cold start.** On a project that didn't
have the leaves folder yet, it wrote the leaves, found that the project file
didn't know them and **exited** — the first pass runs outside the loop and
propagated the error. Anyone hitting `CTRL + SHIFT + B` watched the panel
close on its own, with no hint that running it again was enough.

Now the first pass treats that as waiting, the way the loop already did:
`rogen` next door rewrites the project file, `modux` reloads the map and it
closes. See [Setup](/en/setup/#rokit) for what happens underneath.

### 0.7.2 {#modux-0-7-2}

[release](https://github.com/victorcarmo2003/ModuxWatcher/releases/tag/v0.7.2)
· Sep 20

**The generated folder became `ModuxTypes/`, and that's not a naming
preference.** `src/Types/shared` landed on `ReplicatedStorage.shared.Types` —
exactly where the framework's `src/Shared/Types/` lives, with `Atomic`,
`Occlude`, `Struct` and `Union`.

Rogen doesn't complain: it merges the two folders. And if a name repeats, one
of them **vanishes from the project file with no warning**. A shared Service
named `Union` made the framework's type function disappear, and every
`require(ReplicatedStorage.shared.Types.Union)` started receiving a generated
leaf.

A guard came with it, for the collisions nobody saw coming: the generator
refuses to write if any leaf folder shares an instance with another file in
the project.

### 0.7.0 and 0.7.1 {#modux-0-7-0}

[0.7.0](https://github.com/victorcarmo2003/ModuxWatcher/releases/tag/v0.7.0)
· [0.7.1](https://github.com/victorcarmo2003/ModuxWatcher/releases/tag/v0.7.1)
· Sep 20

**A module became a file.** Until here every module needed a folder of its
own, and the reason was concrete: `Type.luau` was written next to it, and two
loose modules in the same folder would collide on that name. Addressing the
leaf by the module's ID removed the collision, and the folder lost its reason
to exist.

`modux fix` inverted along with it: it now **flattens** `Foo/init.luau` into
`Foo.luau`, and it's the migration command. A folder holding files of its own
stays a folder.

What the bench caught and the design on paper hadn't predicted: the leaf was
**not position-independent**. It carried requires relative to its neighbour,
and moving it broke all of them. Requires became absolute, anchored on the
module's own DataModel path.

**0.7.1** is a performance fix that only showed up at 121 modules: a sweep was
redoing `canonicalize` on every target once per file. Generation went from
1,186 ms to 531 ms — faster than before the layout change.

::: tip Migrating from 0.6.x
`modux fix`, then `modux generate` and `rogen build` **again**. Those last two
steps aren't optional the first time — see [Setup](/en/setup/#rokit).
:::

### 0.6.7 to 0.6.11 {#modux-0-6-7}

Sep 19

The **Azul** block. The `--sourcemap` flag arrived, so the generator can run
on a project with no project file, along with `--source` and a mirrored layout
to match. The mitigation for the
[`rojo sourcemap --watch` crash](/en/setup/Rojo#crash) on folder deletion came
with it.

### 0.6.0 to 0.6.6 {#modux-0-6-0}

Sep 18–19

The **take a beating** block. The generator started typing whatever it can
read even with the file incomplete — while you type, `watch` summarizes broken
syntax in one line instead of dumping the parser. `modux fix` and
`watch --fix` were born, and a project with no modules at all started
generating instead of complaining.

### 0.1.0 to 0.5.0 {#modux-0-1-0}

Sep 17–18

The beginning. The generator became a binary distributed by Rokit, gained a
per-side Manifest, the module list the Loader consumes, `ComponentAccess` and
`Libs`. In **0.2.0** the Luau parser became embedded (`full_moon`) and the
`luau-ast` dependency was dropped — Rokit ships one binary per tool, and
counting on it being on PATH wasn't an option.

## SyncTeam

Two-way sync between VS Code and Studio. See [SyncTeam](/en/setup/SyncTeam).

### 0.2.5 {#syncteam-0-2-5}

[release](https://github.com/victorcarmo2003/SyncTeam/releases/tag/v0.2.5)
· Sep 20

Six real bugs, found in a battery against two actual Studios in Team Create.
The one that hurts most:

**Each dev saw themselves alone, forever.** Both Studios announced the
collaborator had left, and cursor and selection died with it. Cleaning up a
stale session is the protocol's normal path — the leader deletes any session
idle for over 20 s. One false positive was enough (a Studio in the background,
and with two on one machine one always is) for the leader to kill a live
colleague, who kept incrementing its own pulse on an orphaned Instance. The
session now recreates itself every pulse: measured, it comes back in 2.08 s.

**Three variations of one cache bug.** A claim about the world written before
the world confirmed it. A folder operation never reached Studio; a file whose
send failed became invisible forever; an edit refused by a lease could never
leave again. The symptom was always silent.

The **Individual / Teams** selector also landed in the plugin panel — UI only
for now, nothing in the sync flow reads the mode yet.

### 0.2.0 to 0.2.4 {#syncteam-0-2-0}

Aug 03–11

The CLI was born and became a Rokit tool, with `plugin install` and
`extension install` embedding both artifacts inside the binary itself. Then
came fixes for `writeSource` echo, performance bottlenecks in the extension,
and the `init.*` sitting at the root of a named mount that turned into a
Folder forever instead of the mount itself.
