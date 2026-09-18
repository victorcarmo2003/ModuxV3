# Ferramentas e comandos

## Fluxo normal

```sh
rokit install     # baixa as ferramentas fixadas no rokit.toml
wally install     # se o projeto tem dependências
rogen build       # gera o default.project.json a partir das pastas
modux generate    # gera as folhas de tipo e o Manifest
rojo serve        # conecta no Studio
```

Em desenvolvimento, os dois watchers substituem os dois `build`/`generate`:

```sh
rogen watch
modux watch
```

::: warning A ordem importa
`rogen build` vem **antes** de `modux generate`. O `default.project.json` é
gerado a partir da estrutura de pastas, e o gerador resolve os caminhos dos
requires a partir dele. Fora de ordem, o sintoma é `Unknown require` em código
correto.
:::

## modux

O gerador. Lê os módulos, escreve as folhas de tipo e o Manifest. O parser é
embutido — não há nada para instalar ao lado do binário.

### modux generate

Escreve tudo uma vez e sai.

```sh
modux generate
```

```
[modux] leaf: src/Player/server/PlayerService/Type.luau
[modux] manifest server: src/Modux/server/Manifest/init.luau (6 modules)
[modux] modules server: src/Modux/server/Modules.luau
[modux] libs: src/Modux/shared/Libs.luau
[modux] 118 ms
```

Arquivo que já está correto não é reescrito, então rodar de novo imprime
`[modux] up to date`.

### modux watch

Regenera a cada mudança até você interromper. É o que a tarefa `dev` do VS Code
levanta.

```sh
modux watch
```

::: danger Watcher com versão velha
O processo carrega o binário na hora que sobe. Depois de um `rokit update`, um
watcher que continua rodando ainda usa a versão antiga e vai **reescrever** os
arquivos gerados com o comportamento antigo — em silêncio, por cima do que você
acabou de gerar. Reinicie o watcher depois de atualizar.
:::

### modux check

Falha se qualquer coisa no disco difere do que o `generate` escreveria. É o
comando para o CI.

```sh
modux check
```

```
stale: src/Player/server/PlayerService/Type.luau
modux: 1 file(s) out of date. Run `modux generate`.
```

### modux list

Lista os módulos encontrados, com espécie, caminho e as dependências
**declaradas**.

```sh
modux list
```

```
NetService    Service    src/Net/server/NetService/init.luau  deps: -
ProfileService Service   src/Profile/server/ProfileService/init.luau  deps: PlayerService, NetService
Vital         Component  src/Vital/server/Vital/init.luau  deps: VitalService
```

### modux extract

Despeja a forma extraída de um módulo como JSON. Serve para entender por que o
gerador leu algo diferente do que você esperava.

```sh
modux extract src/Player/server/PlayerService/init.luau
```

## rogen

Gera o `default.project.json` a partir da estrutura de pastas, com arquitetura
feature-based: `src/<Feature>/server/` chega como
`ServerScriptService.server.<Feature>`.

```sh
rogen build
rogen watch
```

A configuração fica em `.rogen.json`. Entradas escritas à mão em
`project.tree` são preservadas e mescladas com o que ele deriva — é assim que
`Packages` entra na árvore.

```json
{
	"source": ["src"],
	"luau": { "output": "default.project.json", "build": "src" },
	"globIgnorePaths": ["**/*.md"],
	"project": {
		"name": "MeuJogo",
		"tree": {
			"$className": "DataModel",
			"ReplicatedStorage": { "Packages": { "$path": "Packages" } }
		}
	}
}
```

`globIgnorePaths` evita que ele tente mapear `README.md` como objeto do
DataModel.

## rojo

```sh
rojo serve                                              # conecta no Studio
rojo sourcemap default.project.json -o sourcemap.json   # para o luau-lsp
```

O sourcemap é o que faz o luau-lsp resolver `require(game.X.Y)`. Sem ele, os
tipos não atravessam os requires.

## wally e wally-package-types

```sh
wally install
wally-package-types --sourcemap sourcemap.json Packages/ ServerPackages/ DevPackages/
```

::: danger wally-package-types não é opcional
O shim que o Wally escreve é `return require(_Index[...])`, e `export type`
**não atravessa** um require assim. Os valores resolvem, os tipos não:
`Vide.source` funciona e `Vide.Source` vira `Unknown type`.

Rode depois de **cada** `wally install`, e depois de gerar o sourcemap.
:::

## Análise fora do Studio

`tools/analyze.ps1` roda o mesmo motor do editor sobre o projeto inteiro.

```sh
./tools/analyze.ps1
./tools/analyze.ps1 -Detail        # imprime cada erro
./tools/analyze.ps1 -Filter "*Vital*"
```

```
engine: luau-lsp + Rojo sourcemap + Roblox definitions
total: 0 error(s), 0 cycle(s)
```

Ele roda `rogen build` e gera o sourcemap antes, então não precisa de
preparação.

::: warning O que a análise não pega
Passar não prova que os tipos existem — prova que nada errou. Para saber se o
`self` está mesmo tipado, escreva um acesso que **deveria** falhar
(`self.Dependencies.ServicoQueNaoDeclarei`) e confirme que ele falha.

Também não pega nada validado em runtime: schema de rede, ordem de ciclo de
vida, persistência. Isso só aparece rodando no Studio.
:::

## Tarefas do VS Code

O `.vscode/tasks.json` traz uma tarefa `dev` que sobe os quatro de uma vez:

| tarefa | |
|---|---|
| `rogen watch` | regera o project file |
| `modux watch` | regera folhas e Manifest |
| `sourcemap watch` | mantém o sourcemap atualizado |
| `rojo serve` | serve para o Studio |

## rokit

Fixa a versão de cada ferramenta no `rokit.toml`, uma por entrada.

```sh
rokit install
rokit add victorcarmo2003/modux
rokit update victorcarmo2003/modux
```

::: tip
`rokit install --force` reescreve **todos** os binários, e falha se algum
estiver em uso por um watcher. Prefira `rokit install` sem a flag.
:::
