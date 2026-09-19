# Rojo
O sourcemap é o que faz o luau-lsp resolver `require(game.X.Y)`. Sem ele, os
tipos não atravessam os requires.

```sh
rojo serve                                              # conecta no Studio
rojo sourcemap default.project.json -o sourcemap.json   # para o luau-lsp
```

E para manter em modo watch seria:
```sh
rojo sourcemap --watch default.project.json --output sourcemap.json
```

::: tip Dica:
O modo watch já é incluido em tasks.json do template padrão
uso no vscode: 

`CTRL + SHIT + P` e `Tasks: Run Task` e por fim `dev`
:::

