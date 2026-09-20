# VS Code
Se você puxou pelo template, essas etapas já estão configuradas!

São apenas 4 arquivos, se você montou o projeto à mão, são estes que faltam.

<FileTree title="configuracao do editor" :paths="[
  '.vscode/extensions.json # extensoes recomendadas',
  '.vscode/settings.json # flags do luau-lsp',
  '.vscode/tasks.json # os watchers',
  '.luaurc # modo estrito',
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

O VS Code sugere as duas ao abrir o projeto. A primeira é o analisador que faz
todo o trabalho de tipo; a segunda é o formatador.

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
    "files.autoSaveDelay": 300, // define o quão rápido o LSP atualiza
}
```

O que cada grupo faz:

| chave | |
|---|---|
| `fflags.enableNewSolver` | liga o `LuauSolverV2`. **Sem ela o Modux não tipa nada** |
| `fflags.sync` | puxa as outras flags do Roblox, para o editor bater com o runtime |
| `sourcemap.*` | onde está o sourcemap e se o editor o regenera sozinho |
| `studioPlugin.*` | recebe do Studio as instâncias que não existem no `src/`, como o que você monta na mão |
| `anonymousAutofilledFunction` | completa a assinatura inteira ao aceitar um callback |

::: danger enableNewSolver não é preferência
Type function não existe no solver antigo. Sem a flag, `self` fica sem tipo e o
autocomplete devolve **zero item** — sem erro, sem aviso, só nada.

É o erro mais caro de diagnosticar do framework, porque não produz mensagem
nenhuma. Autocomplete vazio? Confira esta linha antes de qualquer outra coisa.
:::

O `autogenerate` do sourcemap e a tarefa `sourcemap watch` fazem a mesma coisa.
Manter os dois não quebra nada, mas é trabalho duplicado — se você usa a tarefa
`dev`, pode deixar `autogenerate` em `false`.

## tasks.json

Dois conjuntos, um por forma de sincronizar. Você roda **um ou outro**, nunca
os dois ao mesmo tempo — os dois disputariam o mesmo `sourcemap.json`.

### `rojo` — o disco manda

É o fluxo padrão, e a tarefa de build, então `CTRL + SHIFT + B` sobe ela.

| tarefa | |
|---|---|
| `rogen watch` | regera o project file quando pasta muda |
| `modux watch --fix --nudge` | regera folhas e Manifest; move módulo novo para a própria pasta |
| `rojo serve` | serve para o Studio |

```json
{
	"label": "rojo",
	"dependsOn": ["rogen watch", "modux watch", "rojo serve"],
	"dependsOrder": "parallel",
	"group": { "kind": "build", "isDefault": true }
}
```

### `azul` — o Studio manda

Para quando você usa o [Azul](/setup/Azul), inclusive para editar a dois.

| tarefa | |
|---|---|
| `azul sync` | o daemon, que espera o plugin do Studio conectar |
| `modux watch --sourcemap` | lê o mapa do sourcemap do Azul, em vez do project file |

```json
{
	"label": "azul",
	"dependsOn": ["azul sync", "modux watch (sourcemap)"],
	"dependsOrder": "parallel",
	"group": "build"
}
```

Não há `rogen` nem `rojo serve` aqui: o Azul é o transporte e o sourcemap é
dele. A flag `--sourcemap` é o que impede o modux de reconstruir o mapa por
cima — ver [Azul](/setup/Azul#o-modux-com-o-azul).

### `syncteam` — os dois sentidos, mesmo project file

Para quando vocês são dois na mesma place e querem manter a arquitetura por
feature — ver [SyncTeam](/setup/SyncTeam).

| tarefa | |
|---|---|
| `rogen watch` | o **mesmo** do fluxo Rojo |
| `modux watch` | o **mesmo** do fluxo Rojo, sem flag nenhuma |
| `syncteam daemon` | `syncteam start --dir .`, no lugar do `rojo serve` |

```json
{
	"label": "syncteam",
	"dependsOn": ["rogen watch", "modux watch", "syncteam daemon"],
	"dependsOrder": "parallel",
	"group": "build"
}
```

Os dois watchers são reaproveitados de propósito: o SyncTeam fala a convenção
do Rojo (`default.project.json`, `init.luau`) em vez de uma própria, então os
comandos são idênticos e só o transporte muda. Diferente do Azul, aqui **não**
existe `--sourcemap` — o SyncTeam não gera mapa nenhum e o luau-lsp continua
dono do dele.

::: tip A tarefa `dev` continua existindo
Ela virou apelido de `rojo`, para não quebrar quem já tem o hábito.
:::

::: danger Não acrescente uma tarefa de sourcemap
`luau-lsp.sourcemap.autogenerate` já faz o servidor subir o **seu próprio**
`rojo sourcemap --watch`, e `useVSCodeWatcher: false` significa que ele confia
nesse processo para saber quando recarregar.

Uma tarefa fazendo o mesmo põe dois rojo escrevendo o mesmo `sourcemap.json`,
e o servidor só escuta as notificações do dele. O sintoma é o que mais custa a
diagnosticar: o `Type.luau` é reescrito na hora, mas o autocomplete continua
mostrando o estado anterior.

Se ficar atrasado mesmo assim: `CTRL + SHIFT + P` e **Luau: Reload Language
Server**.
:::

::: tip Dica
`CTRL + SHIFT + P` e `Tasks: Run Task` e por fim `rojo`, `azul` ou `syncteam`

Como `rojo` é a tarefa de build padrão, `CTRL + SHIFT + B` sobe ela direto.
:::

::: warning Watcher segura a versão antiga
O processo carrega o binário na hora que sobe. Depois de um `rokit update`, um
watcher que continua rodando ainda usa a versão antiga e vai **reescrever** os
arquivos gerados com o comportamento antigo, em silêncio, por cima do que você
acabou de gerar.

Reinicie a tarefa (`rojo`, `azul` ou `syncteam`) depois de atualizar qualquer
ferramenta.
:::

## .luaurc

```json
{
	"languageMode": "strict"
}
```

Deixa o projeto inteiro em modo estrito sem precisar de `--!strict` em cada
arquivo. Os arquivos do framework trazem a diretiva mesmo assim, para o caso de
serem copiados para um projeto que não tem este arquivo.

## .rogen.json

Fica documentado na página do [Rogen](/setup/Rogen), junto da ferramenta que o
lê.
