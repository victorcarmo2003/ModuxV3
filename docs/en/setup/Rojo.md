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

`CTRL + SHIT + P`, then `Tasks: Run Task`, then `dev`
:::
