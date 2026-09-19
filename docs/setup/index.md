# Setup de tools e watcher

Montar o projeto à mão, ferramenta por ferramenta. Para começar clonando o
template pronto, ver [Instalação](/guia/instalacao).

Abaixo eu explico as duas formas de instalar tudo, a automática, puxando do github e só vinculando tudo.
## Fluxo manual:
No caso do setup manual, se faz necessário baixar o modux do repositório oficial na fork do [Framework](https://github.com/victorcarmo2003/ModuxV3/tree/framework) e inserir em src/

Sim é bem simples pois a arquitetura do rogen é feature-based 😎🥂

Rokit:
```sh
rokit init        				# inicializa o wally para baixar as tools
```
Em seguida abrir o arquivo rokit.toml, colar:
```toml
[tools]
wally = "UpliftGames/wally@0.3.2"
rojo = "rojo-rbx/rojo@7.7.0"
rogen = "ldgerrits/rogen@1.4.4"
modux = "victorcarmo2003/modux@0.6.8"
wally-package-types = "JohnnyMorganz/wally-package-types@1.6.2"
```
E por fim executar, se for necessário, atualizar o rokit e instalar:
```sh
rokit update                        # atualizar se necessário
rokit install        				# para instalar todas as ferramentas
```

Extras:
```sh
wally install     # se o projeto tem dependências
rogen build       # gera o default.project.json a partir das pastas
modux generate    # gera as folhas de tipo e o Manifest
rojo serve        # conecta no Studio
```

Durante o desenvolvimento, os dois watchers substituem os dois `build`/`generate`:

```sh
rogen watch
modux watch
```

E o Rojo, que também roda o tempo todo:

```sh
rojo serve
```

O sourcemap não entra aqui: o luau-lsp já o mantém sozinho, e uma segunda
fonte atrasa o editor — ver [VS Code](/setup/Vscode#tasks-json).

::: tip Dica
Os três já vêm prontos no `tasks.json` do template, numa tarefa só.

Uso no vscode:

`CTRL + SHIFT + P` e `Tasks: Run Task` e por fim `dev`

Como `dev` é a tarefa de build padrão, `CTRL + SHIFT + B` também sobe ela
direto. Cada watcher abre no seu próprio painel, então dá para ler a saída de um
sem perder a dos outros.

Detalhe de cada tarefa em [VS Code](/setup/Vscode).
:::

::: warning A ordem importa
`rogen build` vem **antes** de `modux generate`. O `default.project.json` é
gerado a partir da estrutura de pastas, e o gerador resolve os caminhos dos
requires a partir dele. Fora de ordem, o sintoma é `Unknown require` em código
correto.
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

## Rokit

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
