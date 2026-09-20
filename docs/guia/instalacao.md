# Instalação

O caminho curto é clonar o [ModuxTemplate](https://github.com/victorcarmo2003/ModuxTemplate),
que já vem com as ferramentas fixadas, as dependências declaradas e o framework
dentro.

## Template
Comece clonando o repositório do github em uma pasta sua, como por exemplo
dentro de Documentos, crie uma pasta chamada `RobloxGames` e dentro dela `MeuJogo`
abra o VSCode nessa pasta, abra o terminal com:

<div class="shortcut">
	<kbd>CTRL</kbd> + <kbd>SHIFT</kbd> + <kbd>`</kbd>
</div>

Ou abrindo o executar:

<div class="shortcut">
	<kbd>CTRL</kbd> + <kbd>SHIFT</kbd> + <kbd>P</kbd>
</div>

E pesquisando por: `Terminal: Create New Terminal`

### Clonando
Em seu novo terminal, clone o repositório do github com o comando:
```sh
git clone https://github.com/victorcarmo2003/ModuxTemplate .
```
::: warning Aviso
Caso esse comando falhe avisando que a pasta está com conteúdo mesmo deletando todos
os arquivos, ela provavelmente possui um arquivo oculto como o `.git`, abaixo explico como remover.
:::


### Configurando
O clone traz o histórico e o remote do template. Para o projeto ser teu:
```sh
rm -rf .git                      # descarta o historico do template
git init && git add -A
git commit -m "primeiro commit"
```
::: tip Dica
O comando de remover: `rm` pode pedir permissão de administrador, uma alternativa é
executar o vscode como administrador ou deletar manualmente pelo explorer.
:::


### Instalação
São apenas três linhas, uma por etapa:
```sh
rokit install          # baixa as ferramentas fixadas no rokit.toml
./tools/packages.ps1   # dependencias do Wally, e a tipagem delas
modux generate         # folhas de tipo e Manifest
```
### Manualmente
Para montar tudo à mão, sem o template do github, pode-se acompanhar
as etapas em: [Setup](/setup/).

## Para desenvolver
### Atalho
Não precisa rodar mais nada à mão. Dentro do VS Code:

<div class="shortcut">
	<kbd>CTRL</kbd> + <kbd>SHIFT</kbd> + <kbd>B</kbd>
</div>

Isso sobe a tarefa `dev`, que levanta os três processos de uma vez, cada um no
seu painel:

| | |
|---|---|
| `rogen watch` | regera o project file quando você cria ou move pasta |
| `modux watch --fix` | regera folhas e Manifest, e move módulo novo para a própria pasta |
| `rojo serve` | conecta no Studio |

O generate sourcemap não está aí de propósito: o luau-lsp já mantém o dele, e uma
segunda fonte deixa o editor atrasado — ver [VS Code](/setup/Vscode#tasks-json).

A partir daí é só escrever: salvar um arquivo já refaz os tipos e o Studio
recebe.

::: tip Se o atalho não fizer nada
Ele depende de `dev` estar marcada como tarefa de build padrão, o que o
template já traz. 

Pelo caminho longo:
`CTRL + SHIFT + P` e `Tasks: Run Task` e por fim `dev`

Detalhe de cada tarefa em [VS Code](/setup/Vscode).
:::

E pronto! Você já pode começar.

### Aviso
::: warning Novos pacotes
Ao inserir novos pacotes no wally e instalar, logo após, sempre execute:

`wally-package-types --sourcemap sourcemap.json Packages/ ServerPackages/ DevPackages/`

Confira mais informações na aba [Wally](/setup/Wally)
:::

## Conteúdo

<FileTree title="modux template" :paths="[
  'src/Modux/ # o framework',
  'src/Libs/ # injetadas em self.Libs',
  'src/Shared/Types/ # Struct, Union, Occlude, Atomic',
  'src/Net/ # Lync: definicoes, start e flush',
  'src/Player/ # entrada e saida de jogador',
  'src/Profile/ # ProfileStore com campos reativos',
  'src/Vital/ # Health, Armor, Stamina',
  'src/Round/ # ciclo de rodada em atoms do Charm',
  'src/Input/ # ContextActionService com contexto',
  'src/Interface/ # componentes Vide e stories do UI Labs',
]" />

## Framework

A branch `framework` tem exatamente o conteúdo de `src/Modux` na raiz, então dá
para puxá-la para dentro de um projeto seu:

```sh
git clone -b framework https://github.com/victorcarmo2003/ModuxV3 src/Modux
```

O primeiro comando depois do clone é `modux generate`. Sem ele o Manifest ainda
é o do repositório de origem, e o editor reclama de módulo que não existe aqui.

Assim você recebe só o framework — as ferramentas, as dependências e os
utilitários de tipo ficam por sua conta. Ver [Setup](/setup/).

## Avisos
### `LuauSolverV2`

Type function não existe no solver antigo. Sem a flag, `self` fica sem tipo e o
autocomplete devolve **zero item** — sem erro, sem aviso, só nada.

```json
{
	"luau-lsp.fflags.enableNewSolver": true
}
```

::: warning AVISO:
Esse é o erro mais caro de diagnosticar do framework inteiro, porque não produz
mensagem nenhuma. Se o autocomplete está vazio, confira a flag antes de
qualquer outra coisa.
:::

O template já traz isso e o resto do `.vscode` pronto — ver
[VS Code](/setup/Vscode).

### Onde os seus módulos entram

Em qualquer pasta sob `src/`, e o lado sai do caminho: pasta `client` vai para
StarterPlayerScripts, `server` para ServerScriptService, e o resto é shared.

<FileTree title="uma feature" :paths="[
  'src/Vital/client/VitalController/init.luau',
  'src/Vital/server/VitalService/init.luau',
  'src/Vital/server/Vital/init.luau # componente',
]" />

Um módulo é uma pasta com `init.luau`, nunca um arquivo solto: o gerador escreve
o `Type.luau` ao lado do módulo, e dois módulos na mesma pasta colidiriam nesse
nome.

## Gerado, não editar

Estes arquivos são saída do gerador e são reescritos a cada `modux generate`:

<FileTree title="saida do gerador" :paths="[
  'src/Modux/client/Manifest/init.luau # gerado',
  'src/Modux/client/Modules.luau # gerado',
  'src/Modux/server/Manifest/init.luau # gerado',
  'src/Modux/server/Modules.luau # gerado',
  'src/Modux/shared/Libs.luau # gerado',
  'src/Vital/server/VitalService/init.luau # seu',
  'src/Vital/server/VitalService/Type.luau # gerado',
]" />

Um `Type.luau` por módulo seu, ao lado dele.

::: tip Por que um script para os pacotes
`wally install` reescreve os shims de `Packages/` do zero, e com isso apaga o
que o `wally-package-types` tinha escrito. A tipagem dos pacotes some em
silêncio: `Charm.atom` continua resolvendo e `Charm.Atom` vira `Unknown type`.

Rodar a segunda ferramenta depois da primeira não basta, porque a ordem tem
quatro passos — o `wally-package-types` precisa do sourcemap, que precisa do
`default.project.json`, que sai do `rogen`. O script encadeia os quatro e conta
quantos shims ficaram reexportando tipos no fim.

Rode-o de novo **depois de cada `wally install`**, ou use
`./tools/packages.ps1 -SkipInstall` quando só os shims precisarem ser refeitos.
:::