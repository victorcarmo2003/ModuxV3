# Rojo
The sourcemap is what lets luau-lsp resolve `require(game.X.Y)`. Without it,
types don't travel through the requires.

```sh
rojo serve                                              # connects to Studio
rojo sourcemap default.project.json -o sourcemap.json   # for luau-lsp
```

And to keep it in watch mode:
```sh
rojo sourcemap --watch default.project.json --output sourcemap.json
```

::: tip Tip:
Watch mode already comes in the default template's tasks.json.
Using it in VS Code: 

`CTRL + SHIT + P`, then `Tasks: Run Task`, then `rojo`
:::

## The watch dies when you delete a folder {#crash}

::: danger Measured on Rojo 7.7.0
Deleting a folder that `rojo sourcemap --watch` is watching **takes the
process down**:

```
[ERROR rojo] Rojo crashed! You are running Rojo 7.7.0.
[ERROR rojo] Details: called `Result::unwrap()` on an `Err` value:
  Custom { kind: NotFound, error: Error { kind: Canonicalize, ... } }
[ERROR rojo] in file src\change_processor.rs on line 179
```

It dies quietly: no error window, nothing in the editor. `sourcemap.json`
freezes at its last state, and **every** later edit is invisible — a new
module doesn't appear, a deleted one doesn't leave.
:::

The symptom is autocomplete pointing at an old state for no apparent reason,
and going back to normal only after running `./tools/analyze.ps1`, which
generates a one-shot sourcemap. The one-shot is born correct; what's broken is
the process that was left watching.

Isolating gesture by gesture, only one kills it:

| gesture | does the watch survive? |
|---|---|
| creating a module folder | yes |
| editing a file | yes |
| deleting a **file** | yes, but the entry stays in the map |
| **deleting a folder** | **no, the process dies** |
| renaming a folder | yes |
| moving a module from server to client | yes |

Renaming survives because on Windows it's an atomic operation and doesn't
produce the `canonicalize` of a path that vanished. Deleting a folder is what
the <kbd>Delete</kbd> key does in the VS Code explorer, so it's a common
gesture.

::: tip What Modux does about it
From **0.6.8** on, `modux watch --nudge` rebuilds the whole sourcemap whenever
the set of files changes — one was born or one vanished. Rojo dies all the
same, but the map stays correct, because the generator takes over keeping it.

Before that the rebuild only reacted to changes in `default.project.json`, and
that didn't cover the case: rogen maps each feature side folder as a `$path`,
so touching a module inside a feature that already exists doesn't rewrite the
project file.

Measured, same gesture on both:

| | delete the folder | create a module afterwards |
|---|---|---|
| 0.6.7 | the entry stays in the map | **doesn't appear** |
| 0.6.8 | the entry leaves | appears |
:::

::: warning If you close `modux watch`
The protection goes with it. With only luau-lsp keeping the sourcemap, the map
freezes again on the first folder `rm`. The real fix is in Rojo, in the
`unwrap()` at `change_processor.rs:179`.

One alternative is [Azul](/en/setup/Azul), which doesn't have this problem:
deleting a folder doesn't take its watcher down.
:::
