# SyncTeam

[SyncTeam](https://github.com/victorcarmo2003/SyncTeam) é sync **nos dois
sentidos** entre o VS Code e o Studio, feito para duas pessoas trabalharem na
mesma place ao mesmo tempo — sem abrir mão do `default.project.json`, do
`init.luau` nem da arquitetura por feature.

É esse último ponto que o separa do [Azul](/setup/Azul): os dois resolvem
"duas pessoas ao mesmo tempo", mas o Azul cobra a arquitetura inteira em
troca, e o SyncTeam não cobra nada.

```sh
rokit install                  # depois de adicionar ao rokit.toml
syncteam plugin install        # plugin do Studio
syncteam extension install     # extensão do VS Code
```

No `rokit.toml`:

```toml
syncteam = "victorcarmo2003/SyncTeam@0.2.5"
```

Depois é abrir o Studio, achar o painel **Sync Team** na aba Plugins e clicar
**CONNECT**.

```sh
syncteam port 1400             # porta usada por start/stop
syncteam start --dir .         # sobe o motor em segundo plano
syncteam stop
```

::: tip Dica
O template traz o conjunto de tasks `syncteam` pronto:

`CTRL + SHIFT + P` e `Tasks: Run Task` e por fim `syncteam`

Ele sobe `rogen watch`, `modux watch` e o daemon lado a lado — os mesmos dois
watchers do fluxo Rojo, só trocando o transporte. Detalhe em
[VS Code](/setup/Vscode#tasks-json).
:::

## O Modux com o SyncTeam

**Nada muda.** É o único dos três em que essa frase é literal.

```sh
rogen watch
modux watch --fix --nudge --interval 100
```

Sem `--sourcemap`, sem `--source`, sem layout espelhado. O motivo é que o
SyncTeam fala a convenção do Rojo, não uma própria — o mapeamento
instância ↔ disco dele é este, e é o mesmo que o `rogen` já escreve:

| instância | disco |
|---|---|
| ModuleScript sem filhos | `Nome.luau` |
| ModuleScript **com filhos** | `Nome/init.luau` |
| Script sem filhos | `Nome.server.luau` |
| Script com filhos | `Nome/init.server.luau` |
| LocalScript sem filhos | `Nome.client.luau` |
| LocalScript com filhos | `Nome/init.client.luau` |

Desde o modux **0.7.0** um módulo Modux é um arquivo solto, então cai na
primeira linha da tabela: `Nome.luau` no disco, `Nome` no DataModel, sem
normalização nenhuma no meio. O `src/Feature/{client,server}` continua
existindo, e o `default.project.json` do `rogen` continua sendo a fonte do
mapeamento.

::: tip A normalização deixou de ser um risco
A regra é sobre filhos, não sobre intenção: uma pasta cujo único conteúdo é
`init.luau` é normalizada para `Nome.luau`.

Até a 0.6.11 isso era uma dependência acidental desagradável — o módulo vivia
numa pasta, e essa pasta só sobrevivia porque o `Type.luau` gerado estava lá
do lado fazendo companhia. A forma no disco estava sendo sustentada por um
arquivo gerado. Com o tipo em `src/Types/`, o arquivo solto virou a forma
esperada, e a normalização do SyncTeam simplesmente concorda com ela.

Módulo que guarda arquivo próprio — o `ProfileService` do template, com o seu
`Template.luau` — continua sendo pasta e cai na linha "com filhos". Também sem
normalização, porque tem irmão de verdade.
:::

### O sourcemap continua sendo do luau-lsp

O SyncTeam **não** gera sourcemap, e de propósito: ele ignora o
`sourcemap.json` da raiz na hora de sincronizar, justamente porque
`rojo sourcemap --watch` reescreve esse arquivo em alta frequência e ele não
tem nada que fazer dentro do Studio.

Ou seja, o arranjo de tipagem é exatamente o do fluxo Rojo — inclusive o
[crash do `sourcemap --watch` ao apagar pasta com unlink](/setup/Rojo#crash),
que é do Rojo e continua valendo aqui.

## Duas pessoas ao mesmo tempo

O caminho é o mesmo do Azul, e vale repetir porque confunde: o SyncTeam **não
liga vocês dois**. Quem atravessa as máquinas é o Team Create.

```
disco A -> extensão A -> Studio A -> Team Create -> Studio B -> extensão B -> disco B
```

Cada pessoa roda a própria extensão, na própria porta, com o próprio Studio.
Sem Team Create, são dois projetos separados.

O que o SyncTeam acrescenta em cima disso é uma camada de coordenação que nem
o Rojo nem o Azul têm:

- **Lease por arquivo.** Enquanto você digita, o arquivo é seu. A escrita do
  outro é recusada pelo plugin com `writeAck ok=false, "lease negada"` — não é
  a extensão que decide, é o plugin, do lado do DataModel.
- **Presença.** Cursor e seleção do colega aparecem no seu editor.
- **Eleição de líder** entre os Studios, para que só um faça a limpeza de
  estado compartilhado.

::: danger O que a lease NÃO cobre
A lease morre 2 segundos depois de você parar de digitar
(`leaseStaleAfterSeconds`). Então esta sequência ainda perde trabalho:

> A escreve e termina. Meio segundo depois, B começa a escrever por cima.
> Tudo o que A escreveu é ignorado e sobrescrito por B.

Medido, não deduzido. A lease protege enquanto a mão está no teclado, não o
intervalo entre duas pessoas editando em sequência.

A diferença para o Azul é o **desfecho**, e ela importa: aqui os dois discos
terminam **iguais** (na versão de B). No Azul, cada máquina fica com a própria
versão e nenhum log avisa. Perder uma edição e saber disso é ruim; ter duas
verdades em duas máquinas sem saber é pior.
:::

## Quando escolher cada um

| | Rojo | Azul | SyncTeam |
|---|---|---|---|
| sentido do sync | disco → Studio | Studio ↔ disco | Studio ↔ disco |
| duas pessoas ao mesmo tempo | não | sim, via Team Create | sim, via Team Create |
| arquitetura por feature | sim, via [Rogen](/setup/Rogen) | não, espelha o DataModel | sim, via [Rogen](/setup/Rogen) |
| `init.luau` | sim | não | sim |
| project file | `default.project.json` | nenhum | `default.project.json` |
| flag extra no modux | nenhuma | `--sourcemap` | nenhuma |
| mesmo arquivo, duas pessoas | não se aplica | diverge em silêncio | converge, último ganha |
| cursor/seleção do colega | não | não | sim |
| maturidade | anos de uso | recente, um mantenedor | **mais recente ainda** |

### Por que ele, e não o Rojo

Para uma pessoa só, **não há motivo**. O Rojo faz o trabalho, tem anos de uso
e é uma peça a menos para dar errado. Use Rojo.

O argumento aparece quando são duas, e é curto: **o Rojo não resolve isso.**
Ele empurra o disco para o Studio e pronto. Dois devs na mesma place com Rojo
são dois `rojo serve` sobrescrevendo o mesmo DataModel sem se conhecerem — o
que chega no Studio é o que o último empurrou, e o disco do outro nem fica
sabendo.

A saída clássica é git: cada um no seu ramo, conflito resolvido no merge. Isso
continua sendo o melhor para um time ao longo do tempo, e o SyncTeam não
substitui — você continua commitando normalmente. O que ele resolve é a outra
escala: **vocês dois, na mesma place, agora**, mexendo em coisas diferentes e
querendo ver o resultado um do outro sem um ciclo de commit/pull.

Contra o Azul o argumento é diferente, e é o custo: o Azul resolve o mesmo
problema, mas exige espelhar o DataModel no disco, abandonar o `init.luau` e
com isso a arquitetura por feature — ou seja, o Modux passa a morar em
`sync/ServerScriptService/server/Modux/`. O SyncTeam chega no mesmo lugar sem
pedir nada disso.

::: warning Seja justo com a idade dele
O SyncTeam é mais novo que o Azul, que já é novo, e tem um mantenedor só. O
que está documentado aqui foi medido contra dois Studios reais em Team Create,
mas "medido" não é "anos de uso por muita gente". Para um projeto em produção
com prazo, Rojo + git continua sendo a escolha conservadora, e ela é
defensável.
:::
