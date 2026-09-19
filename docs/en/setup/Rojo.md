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

## The watch dies when a folder is unlinked {#crash}

::: danger Measured on Rojo 7.7.0
A watched folder that disappears **by unlink** — without going through the
recycle bin — **takes the `rojo sourcemap --watch` process down**:

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

The line isn't "deleting". It's **whether the folder was moved or unlinked**.
The Windows recycle bin is a move, and that's what separates the two sides:

| gesture | what it is on Windows | does the watch survive? |
|---|---|---|
| <kbd>Delete</kbd> in the VS Code explorer | move to the recycle bin | **yes**, and it cleans the map |
| <kbd>Delete</kbd> in Windows Explorer | move to the recycle bin | **yes**, and it cleans the map |
| renaming the folder | move | **yes**, and it follows |
| <kbd>Shift</kbd>+<kbd>Delete</kbd> | unlink | **no, the process dies** |
| `rm -rf`, a script, a tool | unlink | **no, the process dies** |

Measured gesture by gesture, with the watcher running and a human doing the
deleting.

This matters in practice: if you delete folders with the plain
<kbd>Delete</kbd> key, you will probably never hit this bug. Who hits it is
whoever uses <kbd>Shift</kbd>+<kbd>Delete</kbd>, or a tool that deletes
outright — which includes things like `wally install`, which rewrites
`Packages/` from scratch.

When it dies, the entry stays in the sourcemap: it doesn't even get to clean
up.

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
freezes again on the first folder unlink. The real fix is in Rojo, in the
`unwrap()` at `change_processor.rs:179`.

One alternative is [Azul](/en/setup/Azul), which doesn't have this problem:
deleting a folder doesn't take its watcher down.
:::
