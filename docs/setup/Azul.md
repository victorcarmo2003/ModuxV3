# Azul

[Azul](https://github.com/Ransomwave/azul) é uma alternativa ao Rojo em que o
sentido do sync é invertido: **o Studio é a fonte da verdade** e o disco
espelha o que está lá. Você edita no VS Code ou no Studio, e os dois lados se
mantêm.

A principal razão para considerá-lo não é o sync em si, é que **duas pessoas
conseguem editar ao mesmo tempo**.

```sh
npm install azul-sync -g
```

Além do CLI, é preciso instalar o
[plugin companheiro](https://create.roblox.com/store/asset/79510309341601/Azul-Companion-Plugin)
no Studio — ele não vem no pacote npm.

```sh
azul          # sobe o daemon e espera o Studio
azul build    # empurra o projeto local para dentro do Studio
azul pack     # serializa as propriedades das instâncias no sourcemap
```

::: tip Dica
O template traz o conjunto de tasks `azul` pronto:

`CTRL + SHIFT + P` e `Tasks: Run Task` e por fim `azul`

Ele sobe o daemon e o `modux watch --sourcemap` lado a lado. Detalhe em
[VS Code](/setup/Vscode#tasks-json).
:::

## Duas pessoas ao mesmo tempo

Funciona, e o caminho é este:

```
disco A -> azul A -> Studio A -> Team Create -> Studio B -> azul B -> disco B
```

O Azul **não** liga vocês dois. Cada pessoa roda o próprio daemon, na própria
máquina, com a própria pasta de sync. Quem atravessa é o **Team Create**; o
Azul é só a ponta de cada lado. Sem Team Create, são dois projetos separados.

Medido com duas instâncias do Studio na mesma place, cada uma com seu daemon:

| | resultado |
|---|---|
| propagação de uma edição, volta completa | **1 segundo** |
| os dois editando **arquivos diferentes** | converge, hashes idênticos |
| os dois editando **o mesmo arquivo** | **diverge em silêncio** |
| apagar uma pasta | ver [abaixo](#apagar-pasta) |

::: danger O mesmo arquivo ao mesmo tempo
Em três tentativas, duas terminaram com cada máquina guardando a própria
versão:

```
volta 1 -> DIVERGENTE: A vê A, B vê B
volta 2 -> convergiu em B
volta 3 -> DIVERGENTE: A vê A, B vê B
```

Depois de trinta segundos parados, continuavam diferentes, e **nenhum dos dois
logs registrou aviso** — procurei por `conflict`, `diverg`, `overwrite` e
`warn`, não há nada.

Não é bem um defeito do Azul: o Team Create resolve conflito no nível da
instância e o Azul no nível do arquivo, e os dois não se conhecem. O resultado
prático é que dois editores no mesmo script é território minado. Combinem
quem mexe em quê.
:::

## Duas limitações que aparecem no primeiro dia

**Um daemon atende um Studio por vez.** Está no código, não é configuração:

```js
if (this.client) {
    log.warn("Disconnecting previous client");
    this.client.close();
}
```

Um segundo Studio na mesma porta desconecta o primeiro. Um daemon por pessoa,
sempre.

**Desconectar pelo plugin mata o processo.** O Studio manda
`Studio requested daemon shutdown` e o daemon encerra. Cada reconexão pede
rodar o `azul` de novo no terminal.

## Estrutura no disco

O diretório de sync é um espelho da árvore do Studio. O padrão é `./sync`:

<FileTree title="layout do azul" :paths="[
  'sync/ReplicatedStorage/Shared/ # o que estiver em ReplicatedStorage',
  'sync/ServerScriptService/Server/ # e assim por diante',
  'sync/StarterPlayer/StarterPlayerScripts/',
  'sourcemap.json # gerado pelo azul, formato compativel com o Rojo',
]" />

Ou seja: **não existe `src/Feature/{client,server}`**. A organização por
feature que o [Rogen](/setup/Rogen) entrega não sobrevive aqui, porque o disco
passa a ser a árvore do jogo. Dá para agrupar por feature dentro de cada
serviço, mas aí a feature fica partida entre duas raízes.

::: warning `deleteOrphansOnConnect` vem ligado
Ao conectar, o Azul apaga todo arquivo dentro do syncDir que não corresponda a
uma instância do Studio:

```js
if (!mapped.has(path.resolve(fullPath))) {
    fs.unlinkSync(fullPath);
}
```

Com a configuração padrão isso só alcança o `sync/`, então o seu código-fonte
está a salvo. O risco aparece se você apontar o syncDir para a pasta onde o
código mora. Desligue em `azul config` antes de fazer isso.
:::

## O Modux com o Azul

O gerador precisa saber onde cada arquivo cai dentro do jogo, e normalmente
tira isso do `default.project.json`. O Azul não produz project file nenhum —
mas produz um sourcemap, e o sourcemap tem a mesma informação, de forma até
mais direta.

A partir da **0.6.11** existe a flag:

```sh
modux watch --sourcemap sourcemap.json --fix --nudge --interval 100
```

Com ela o gerador lê o mapa do sourcemap e **para de reconstruí-lo**, porque
sob o Azul o dono do sourcemap é outro processo. Sem a flag, o modux
sobrescreveria o mapa do Azul com um derivado de um project file que talvez
nem exista.

Os dois caminhos produzem o mesmo mapa — há teste comparando arquivo por
arquivo no template inteiro, 66 arquivos, zero divergências.

### Onde o framework mora

Sem o rogen não há tradução de pastas, então o Modux precisa nascer já no
caminho completo. A partir da **0.6.11** o gerador assume esse layout sozinho
quando você passa `--sourcemap`:

<FileTree title="layout espelhado" :paths="[
  'sync/ServerScriptService/server/Modux/ # o framework, lado server',
  'sync/StarterPlayer/StarterPlayerScripts/client/Modux/',
  'sync/ReplicatedStorage/shared/Modux/',
  'sync/ReplicatedStorage/shared/Libs/ # injetadas em self.Libs',
  'sync/ServerScriptService/server/Vital/VitalService/ # um modulo seu',
]" />

Parece mais verboso que `src/Modux/client`, e é — mas chega exatamente nas
mesmas instâncias. O Manifest gerado aqui requer
`ServerScriptService.server.Vital.VitalService.Type`, idêntico ao do fluxo
Rojo. **Nenhum require do seu código muda.**

A pasta varrida é `sync/` por padrão nesse modo. Se a sua for outra,
`--source DIR`.

::: warning Os dois layouts não convivem
`src/Feature/{client,server}` e `sync/ServerScriptService/...` são estruturas
diferentes no disco. As duas tasks ficam lado a lado no `tasks.json`, mas isso
não quer dizer que dá para alternar no mesmo projeto: é escolha por projeto, e
mudar depois é migração.
:::

### E a tipagem, com duas pessoas?

A pergunta natural: se o seu amigo edita um módulo, a folha de tipo dele chega
pronta no seu disco, ou o seu gerador precisa refazer?

**Chega pronto, e o seu gerador concorda com ele.** O gerador é determinístico
— mesma entrada, mesma saída, byte a byte — e só escreve quando o conteúdo
difere do que já está lá. Então o seu modux recalcula, chega no mesmo
resultado, vê que o arquivo já está correto e não escreve nada. Sem loop, sem
guerra de escrita.

::: warning O Manifest pode piscar
A folha é por módulo, mas o Manifest é **um só**, compartilhado, e lista todos
os módulos do lado.

Se o modux da outra pessoa rodar na janela de um segundo entre o seu módulo
novo existir e chegar lá, ele gera um Manifest **sem** o seu módulo, e esse
Manifest volta e sobrescreve o seu. O seu modux regenera com o módulo, empurra
de volta, e os dois trocam figurinha até os discos se igualarem.

Converge em segundos, mas durante a janela o autocomplete oscila. Se
incomodar, só uma pessoa roda o `modux watch` e a outra recebe os tipos
prontos.
:::

## Quando escolher cada um

| | Rojo | Azul |
|---|---|---|
| fonte da verdade | o disco | o Studio |
| duas pessoas ao mesmo tempo | não | sim, via Team Create |
| arquitetura por feature | sim, via [Rogen](/setup/Rogen) | não, espelha o DataModel |
| apagar pasta com unlink | [derruba o watch](/setup/Rojo#crash) | a medir |
| project file | `default.project.json` | nenhum |
| maturidade | anos de uso | mantido por uma pessoa, recente |

O próprio autor do Azul diz que é *"still a relatively new tool maintained by
only one person"*, e mais áspero que Rojo e Argon. Vale saber antes de mover
um projeto inteiro.

### "E para um projeto compartilhado?"

Depende do que compartilhado quer dizer, e as duas respostas são opostas.

**Vocês dois digitando ao mesmo tempo, na mesma sessão:** Azul ou
[SyncTeam](/setup/SyncTeam). Os dois funcionam, e os dois atravessam pelo Team
Create. A escolha é de custo: o Azul pede o disco espelhado e abre mão do
`init.luau`; o SyncTeam mantém o `default.project.json` e a arquitetura por
feature, mas é mais novo. E no caso dos dois no mesmo arquivo, o Azul diverge
em silêncio e o SyncTeam converge na última escrita — perder uma edição
sabendo é melhor que ter duas verdades sem saber.

**Um time trabalhando no mesmo código ao longo do tempo:** Rojo com git. O
argumento é a medição acima: no Azul, dois no mesmo arquivo perdem trabalho em
silêncio. No git, conflito é barulhento e trava até alguém resolver. Você troca
uma perda silenciosa por uma interrupção visível, e a segunda é muito melhor.
De quebra você mantém a arquitetura por feature e uma ferramenta madura.

Nada impede usar git com o Azul — você versiona a pasta `sync/`. Mas aí o
repositório vira um espelho da árvore do jogo, e o histórico fica mais difícil
de ler.
