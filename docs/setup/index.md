# Setup de tools e watcher

Montar o projeto à mão, ferramenta por ferramenta. Para começar clonando o
template pronto, ver [Instalação](/guia/instalacao).

Abaixo eu explico as duas formas de montar o projeto: a automática, clonando o
template do GitHub, e a manual, ferramenta por ferramenta.
## Fluxo manual:
No setup manual, o primeiro passo é baixar o Modux da branch
[framework](https://github.com/victorcarmo2003/ModuxV3/tree/framework) do
repositório oficial e colocá-lo em `src/`.

É simples porque a arquitetura do rogen é feature-based 😎🥂

Rokit:
```sh
rokit init        				# cria o rokit.toml, que fixa as versões das tools
```
Em seguida abrir o arquivo rokit.toml, colar:
```toml
[tools]
wally = "UpliftGames/wally@0.3.2"
rojo = "rojo-rbx/rojo@7.7.0"
rogen = "ldgerrits/rogen@1.4.4"
modux = "victorcarmo2003/ModuxWatcher@0.7.3"
wally-package-types = "JohnnyMorganz/wally-package-types@1.6.2"
```

O `rojo` aí em cima é o transporte para o Studio, e é o padrão. Se vocês forem
dois na mesma place, troque-o (ou some-o) por uma das alternativas:

```toml
syncteam = "victorcarmo2003/SyncTeam@0.2.5"   # sync nos dois sentidos, com lease
```

O [SyncTeam](/setup/SyncTeam) usa o mesmo `default.project.json` e o mesmo
`init.luau`, então o resto desta página não muda — só o comando que fica
rodando no lugar do `rojo serve`. O [Azul](/setup/Azul) também resolve duas
pessoas, mas pede outra estrutura de disco.
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
rogen build       # de novo, só na PRIMEIRA vez — ver abaixo
modux generate
rojo serve        # conecta no Studio
```

::: warning Só na primeira geração do projeto
Aquele par repetido não é engano. Desde o modux **0.7.0** as folhas de tipo
moram em `src/ModuxTypes/`, e o `rogen` deriva o `default.project.json` da
estrutura de pastas — ele só enxerga uma pasta depois que ela tem `.luau`
dentro. Num projeto onde `src/ModuxTypes/` ainda não existe, o primeiro
`modux generate` escreve as folhas mas não acha endereço de DataModel para
elas:

```
modux: path outside default.project.json: src/ModuxTypes/client/MeuController.luau
```

O `rogen build` seguinte mapeia, e o segundo `modux generate` fecha. Da
segunda vez em diante uma passada basta.

**Clonando o template, isso nunca acontece** — lá as folhas já vêm
versionadas, então o primeiro `rogen build` já enxerga a pasta.

Nos **watchers** (`CTRL + SHIFT + B`) o cold start se resolve sozinho, mas
vale saber como: `rogen watch` e `modux watch` sobem juntos, e quem chega
primeiro é corrida. Se o build inicial do rogen rodar depois de o modux
escrever as folhas, fecha na largada. Se rodar antes, o modux imprime
`waiting for rogen to pick up the leaves folder` e fica esperando — o teu
primeiro save reconstrói o project file, o modux relê o mapa e fecha ali.

Em nenhum dos dois o watcher morre. Até a **0.7.2** morria: a primeira
passada saía com `path outside default.project.json` antes de o loop
começar, e a tarefa do VS Code fechava sozinha sem explicar nada. Corrigido
na **0.7.3**.
:::

Durante o desenvolvimento, os dois watchers substituem os dois `build`/`generate`:

```sh
rogen watch
modux watch
```

E o transporte, que também roda o tempo todo — `rojo serve`, ou o daemon da
alternativa que você escolheu:

```sh
rojo serve                     # fluxo Rojo
syncteam start --dir .         # fluxo SyncTeam
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
rokit add victorcarmo2003/ModuxWatcher
rokit update victorcarmo2003/ModuxWatcher
```

::: warning O Rokit pede confiança uma vez por ferramenta
Na primeira vez ele recusa e diz `has not been marked as trusted`. É só rodar
o `rokit add` de novo num terminal interativo e aceitar, ou
`rokit trust victorcarmo2003/ModuxWatcher` antes do `rokit install`.

Se você vinha da **0.6.x**, isso acontece de novo mesmo já tendo aceitado
antes: o repositório se chamava `victorcarmo2003/modux` até a 0.7.0, e o Rokit
trata o nome novo como uma ferramenta **diferente** — ele não segue o
redirecionamento do GitHub.
:::

::: tip
`rokit install --force` reescreve **todos** os binários, e falha se algum
estiver em uso por um watcher. Prefira `rokit install` sem a flag.
:::
