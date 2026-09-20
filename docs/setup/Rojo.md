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
O modo watch já vem no `tasks.json` do template padrão.
Uso no VS Code:

`CTRL + SHIFT + P` e `Tasks: Run Task` e por fim `rojo`
:::

## O watch morre quando uma pasta é desvinculada {#crash}

::: danger Medido no Rojo 7.7.0
Uma pasta observada que some **por unlink** — sem passar pela lixeira —
**derruba o processo** do `rojo sourcemap --watch`:

```
[ERROR rojo] Rojo crashed! You are running Rojo 7.7.0.
[ERROR rojo] Details: called `Result::unwrap()` on an `Err` value:
  Custom { kind: NotFound, error: Error { kind: Canonicalize, ... } }
[ERROR rojo] in file src\change_processor.rs on line 179
```

Ele morre calado: nenhuma janela de erro, nada no editor. O `sourcemap.json`
fica congelado no último estado, e **toda** edição seguinte fica invisível —
módulo novo não aparece, apagado não sai.
:::

O sintoma é o autocomplete apontando para um estado antigo sem motivo
aparente, e voltando ao normal só depois de rodar `./tools/analyze.ps1`, que
gera um sourcemap avulso. O avulso nasce correto; quem está quebrado é o
processo que ficou vigiando.

A fronteira não é "apagar". É **se a pasta foi movida ou desvinculada**. A
lixeira do Windows é um move, e é isso que separa os dois lados:

| gesto | o que é no Windows | o watch sobrevive? |
|---|---|---|
| <kbd>Delete</kbd> no explorer do VS Code | move para a lixeira | **sim**, e limpa o mapa |
| <kbd>Delete</kbd> no Explorer do Windows | move para a lixeira | **sim**, e limpa o mapa |
| renomear a pasta | move | **sim**, e acompanha |
| <kbd>Shift</kbd>+<kbd>Delete</kbd> | unlink | **não, o processo morre** |
| `rm -rf`, script, ferramenta | unlink | **não, o processo morre** |

Medido gesto a gesto, com o watcher observando e o usuário apagando à mão.

Isso importa na prática: se você apaga pastas pelo <kbd>Delete</kbd> normal,
provavelmente nunca vai encontrar esse bug. Quem encontra é quem usa
<kbd>Shift</kbd>+<kbd>Delete</kbd>, ou uma ferramenta que apaga direto — e aí
entram coisas como `wally install`, que reescreve `Packages/` do zero.

Quando ele morre, a entrada fica no sourcemap: ele nem chega a limpar.

::: tip O que o Modux faz a respeito
A partir da **0.6.8**, o `modux watch --nudge` refaz o sourcemap inteiro
sempre que o conjunto de arquivos muda — um nasceu ou um sumiu. O Rojo morre
igual, mas o mapa continua correto, porque quem passa a mantê-lo é o gerador.

Antes disso o rebuild só reagia a mudanças no `default.project.json`, e isso
não cobria o caso: o rogen mapeia cada pasta de lado de feature como `$path`,
então mexer num módulo dentro de uma feature que já existe não reescreve o
project file.

Medido, mesmo gesto nos dois:

| | apaga a pasta | cria um módulo depois |
|---|---|---|
| 0.6.7 | a entrada fica no mapa | **não aparece** |
| 0.6.8 | a entrada sai | aparece |
:::

::: warning Se você fechar o `modux watch`
A proteção vai junto. Com só o luau-lsp mantendo o sourcemap, o mapa volta a
congelar no primeiro unlink de pasta. O conserto definitivo é no Rojo, no
`unwrap()` de `change_processor.rs:179`.

Uma alternativa é o [Azul](/setup/Azul), que não tem esse problema: apagar
pasta não derruba o watcher dele.
:::
