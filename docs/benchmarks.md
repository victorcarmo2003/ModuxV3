# Benchmarks

Todo número citado na documentação sai daqui, e todos são medidos — nenhum é
estimado. O harness está em [`tools/bench/`](https://github.com/victorcarmo2003/ModuxV3/tree/master/tools/bench)
e roda o `luau-lsp` de verdade, não um modelo de custo.

Esta página existe porque um número com três casas significativas convida a
pergunta "medido como?". A resposta está toda aqui, inclusive a parte em que o
desenho atual **perde**.

## Como ler as tabelas

**Linha de base.** Carregar as definitions do Roblox custa entre 1,5 e 2
segundos, sempre, independente do que está sendo analisado. A coluna `líquido`
é o tempo total menos essa constante. Sem descontar, todos os estilos aparecem
empatados e a medição não diz nada.

**Mediana, não média.** Cada `analyze` é um processo novo, e o primeiro de uma
sequência paga cache frio de disco. A média anda com esse outlier; a mediana
não. O número de rodadas está escrito em cada tabela.

**Carga igualada.** Onde duas variantes de tipagem são comparadas entre si, os
projetos são sintéticos e recebem a **mesma** superfície compartilhada, a mesma
contagem de módulos, os mesmos métodos e as mesmas travessias entre módulos. O
que muda é só como o tipo chega em quem escreve.

**Sítios de declaração.** É a variável que mais importa e a mais fácil de
errar. Um projeto com N módulos tem N lugares onde o `self` é construído, não
um. Uma medição com um sítio só mede o custo errado por um fator de N.

### Ambiente

| | |
|---|---|
| CPU | Intel Xeon E5-2667 v4 @ 3.20 GHz |
| RAM | 12 GB |
| SO | Windows 11, build 26200 |
| analisador | `luau-lsp` 1.69.0, com `--flag:LuauSolverV2=true` |
| definitions | `globalTypes.PluginSecurity.d.luau` da extensão do VS Code |
| Python | 3.12.10 |
| data | 2026-09-20 |

## Por que o `analyze` demora

Medido no [template](https://github.com/victorcarmo2003/ModuxTemplate), que é
um projeto de verdade: 11 módulos, 61 arquivos `.luau`. Mediana de 3 rodadas,
tempo de relógio do processo inteiro.

| o que foi analisado | arquivos | tempo |
|---|---:|---:|
| um arquivo vazio | 1 | 1 601 ms |
| uma folha de tipo | 1 | 3 331 ms |
| um módulo | 1 | 3 439 ms |
| só as folhas | 21 | 3 474 ms |
| só os módulos | 22 | 5 443 ms |
| **o projeto inteiro** | **61** | **5 599 ms** |

Dá para separar os 5,6 s em quatro pedaços, e nenhum deles é o que se imagina:

| pedaço | custo | o que é |
|---|---:|---|
| definitions da Roblox | 1 601 ms | 29% — não tem nada a ver com o seu projeto |
| o primeiro arquivo | ~1 800 ms | 32% — montar o grafo de tipos do framework, uma vez |
| os outros 21 módulos | ~2 000 ms | 36% — ~95 ms cada |
| todo o resto | ~160 ms | 3% — 39 arquivos, ~4 ms cada |

**Quase um terço nunca foi o seu projeto.** Carregar o
`globalTypes.PluginSecurity.d.luau` custa 1,6 s num arquivo vazio, e custa os
mesmos 1,6 s num projeto de 200 módulos. Toda tabela desta página que fala em
"líquido" está com essa constante descontada; sem descontar, tudo parece
empatado.

**Outro terço é pago uma vez só.** Ir de um arquivo vazio para *qualquer* um
arquivo do projeto custa ~1,8 s. Isso é o analisador resolvendo o Manifest, as
folhas que ele requer e a cadeia do framework. O segundo módulo não paga isso
de novo.

**As folhas são quase de graça.** Vinte folhas a mais que a primeira custam
143 ms somadas, ~7 ms cada. É a evidência mais direta de que o custo da tipagem
do Modux **não** está no arquivo que o gerador escreve — está em quem o
consome.

### O editor nunca analisa o projeto inteiro

Esta é a parte que mais se lê errado nesta página, então vale direto: **o
`analyze` completo não é uma coisa que você espera.** Ele é o número do CI. O
editor nunca faz isso.

O `luau-lsp` verifica **o arquivo que você está editando**, e só. Ele não varre
as 21 folhas nem os outros 21 módulos porque você abriu um arquivo — não há
varredura nenhuma.

Mas o arquivo que você abriu requer o Manifest, e o Manifest requer todas as
folhas do lado dele. Então o custo chega por dentro, e é por isso que a tabela
acima tem a linha mais importante da página:

| | tempo |
|---|---:|
| um módulo, sozinho | 3 439 ms |
| o projeto inteiro, 61 arquivos | 5 599 ms |

**Abrir um arquivo já custa 61% do projeto inteiro.** Não porque o editor
analisou o resto, mas porque aquele um arquivo puxa a cadeia de tipos toda.

Isso soa ruim e é a melhor notícia da página, por um motivo: **é pago uma vez.**
O servidor sobe, resolve essa cadeia, e fica com ela em memória. Toda edição
seguinte reaproveita — e é por isso que o autocomplete responde abaixo de 1 ms
(ver abaixo) num projeto cujo `analyze` completo leva segundos.

O que você sente, na prática:

- **Ao abrir o projeto:** alguns segundos até a tipagem responder. Uma vez.
- **Digitando:** abaixo de 1 ms.
- **No CI:** o `analyze` completo, e esse é o único lugar onde os números
  grandes desta página aparecem.

::: tip No CI, analise tudo de uma vez
Um arquivo por processo pagaria os 1,6 s de definitions **61 vezes** — mais de
97 s só de linha de base, antes de qualquer trabalho útil. Em lote, paga-se
uma. Quebrar a análise em jobs multiplica a constante por job.
:::

### Onde isso vira problema

Os ~95 ms por módulo acima não são constantes: eles dependem de **quantas
entradas o Manifest tem**. Medido em duas árvores sintéticas, analisando só os
módulos e descontando a linha de base:

| Manifest | custo por módulo | total |
|---|---:|---:|
| 100 entradas | 223 ms | 22,3 s |
| 150 entradas | 533 ms | 80,0 s |

O N cresceu 1,5× e o custo **por módulo** cresceu 2,4×. Aí está o mecanismo
inteiro: cada `Modux.Controller("X")` resolve o Manifest do seu lado; Manifest
maior, sítio mais caro; e existem N sítios. **N × custo(N)**, com o custo já
crescendo mais que linear — por isso a curva fica perto de N³, não de N².

Na mesma árvore de 150, o acúmulo por arquivo é limpo:

| arquivos analisados | tempo | `too complex` |
|---:|---:|---:|
| 1 | 3 160 ms | 0 |
| 10 | 7 197 ms | 1 |
| 50 | 29 604 ms | 10 |
| 150 | 81 706 ms | 26 |

Linear no número de arquivos, a ~0,53 s cada. Não existe um arquivo
patológico: são 150 arquivos custando meio segundo cada.

::: warning Esses 81 s já são com o solver desistindo
26 dos 150 arquivos terminaram em `Code is too complex to typecheck`. O solver
bateu no limite interno e parou. Se fosse até o fim, custaria mais.
:::

### Autocomplete

Mediana quente de `textDocument/completion`, 7 chamadas, descartando a
primeira:

| N | V3 |
|---:|---:|
| 10 | 0,5 ms |
| 25 | 0,5 ms |
| 50 | 0,7 ms |
| 100 | 0,9 ms |

Muito abaixo do que se percebe digitando, e não cresce com N de forma
relevante. **O muro do V3 é o `analyze` em lote, não a digitação.** Quem sente
os segundos é o CI, não quem está escrevendo.

## Onde mora o custo

Se o problema é N sítios × Manifest de N entradas, a pergunta óbvia é se dá para
reorganizar os tipos e fugir dele. Cinco alternativas foram construídas e
medidas. Todas com N=100 e N sítios de declaração, mediana de 3 rodadas.

| variante | o que muda | líquido | erros |
|---|---|---:|---:|
| **`v3sites`** | **o desenho atual** | **18 248 ms** | 0 |
| `v3nobuild` | sem `SelfOf.Build` e sem `Pick` — só `index<AllControllers, ID>` | 16 784 ms | 0 |
| `v3nopick` | sem `Pick.Table`, `Dependencies` literal | 17 058 ms | 0 |
| `v3deps` | `Dependencies` literal por folha | 17 526 ms | 0 |
| `v3leaf` | `Build` dentro de cada folha | 16 754 ms | 2 |
| `v3pre` | `Build` pré-computado no Manifest | 227 ms | **209** |

E, para a escala, medidos na **mesma** rodada:

| referência | líquido |
|---|---:|
| Luau puro, plano | 106 ms |

::: warning Abaixo de ~500 ms, não leve a vírgula a sério
As duas tabelas acima vieram de rodadas diferentes, cada uma com a sua linha de
base. Uma mesma variante barata pode aparecer como 69 ms numa e 319 ms na
outra — não porque mudou, mas porque subtrair uma constante de 1,8 s de um
total de 1,9 s deixa um resto com erro relativo enorme.

Comparar números pequenos **entre** tabelas não vale; comparar dentro de uma
mesma tabela vale. E a conclusão desta seção não depende disso: 16,8 s contra
18,2 s é diferença grande o bastante para sobreviver ao ruído, e a diferença
entre 18 s e 0,5 s não é sutil.
:::

**A máquina de type function não é o custo.** O `v3nobuild` não tem `Build` nem
`Pick` — nenhuma type function no caminho — e ainda assim custa 16,8 s, 92% do
desenho completo. Tirar o `Pick` economiza 6%. Tirar o `Build` junto economiza
8%. O resto, os outros 92%, é a travessia do Manifest, que nenhuma das variantes
elimina porque ela é inerente a `Modux.Controller("Nome")` resolver um nome para
um tipo: isso pede uma tabela central, e todo módulo precisa dela.

**O conserto mais óbvio é o que quebra.** O `v3pre` pré-computa o `self` de cada
módulo dentro do Manifest — o gerador conhece a lista de `Require`, então poderia
escrever tudo resolvido e a declaração viraria só um índice. Ele aparece com 227
ms na tabela, e isso é ilusão: são **209 erros de análise**, um deles
`Code is too complex to typecheck`. Ele não é rápido, ele desiste. A N=50, onde
ainda compilava, media 3 200–3 500 ms, ou seja 60% **pior** que o desenho atual.

A armadilha é sempre a mesma: mover a instanciação de type function para um
arquivo que muitos requerem faz cada requerente resolver todas as N em vez de só
a sua.

## O teto por lado

Medido com [`tools/bench/bench_types.py`](https://github.com/victorcarmo2003/ModuxV3/tree/master/tools/bench),
que gera controllers e services **reais** dentro de `src/`, roda o `modux` para
produzir Manifest e folhas, e analisa o projeto inteiro. Seis métodos e quatro
dependências por módulo. Medido em 2026-09-18.

| configuração | arquivos | `analyze` | erros |
|---|---:|---:|---:|
| 75 controllers | 227 | 12,1 s | 0 |
| 100 controllers | 287 | 25,3 s | 0 |
| **50 controllers + 50 services** | 267 | **9,1 s** | 0 |
| 150 controllers | 407 | 83,5 s | 33 × `too complex` |

**O orçamento é por lado.** Cem módulos num lado só custam 25,3 s; os mesmos cem
divididos entre client e server custam 9,1 s. Quase 3× mais barato, porque
`AllControllers` e `AllServices` são tipos separados e o custo é superlinear no
N de **cada** lado, não no total.

**O muro fica entre 100 e 150 por lado**, com `Code is too complex to typecheck`.

::: tip Refeito no modux 0.7.0: o muro não andou
A 0.7.0 tirou a folha de tipo de junto do módulo e a levou para
`src/Types/<lado>/<Id>.luau`. A pergunta óbvia é se isso mexeu no custo. Não
mexeu — medido em A/B na mesma máquina e na mesma sessão, N=100 controllers:

| modux | `analyze` | erros |
|---|---:|---:|
| 0.6.11 | 33 742 ms | 0 |
| 0.7.0 | 33 260 ms | 0 |

Diferença dentro do ruído. E o muro segue no mesmo lugar: a N=150 a 0.7.0 dá
111 626 ms e 27 `too complex`, contra 0 erro a N=100.

Os números desta rodada saíram ~34% acima dos da tabela acima (33,3 s contra
25,3 s a N=100), e isso é estado de máquina, não regressão — o mesmo fator
aparece nas duas linhas, e o A/B contra a 0.6.11 no mesmo instante fecha a
questão. É por isso que a tabela acima não foi reescrita: os números dela são
de uma máquina descansada, e comparar entre rodadas é justamente o que esta
página avisa para não fazer.

O que a migração mexeu foi a **geração**, e para pior antes de melhorar: 622 ms
na 0.6.11 contra 1 186 ms na 0.7.0. A causa era uma varredura que refazia o
`canonicalize` de todos os alvos uma vez por arquivo, escondida até então
porque metade dos arquivos saía por um atalho que a folha centralizada
eliminou. Corrigido, a mesma medição dá **531 ms** — mais rápido que antes da
mudança de layout.
:::

O harness sintético chega no mesmo lugar por outro caminho: a N=150, com módulos
gerados e nenhuma das particularidades do projeto real, o `v3sites` leva 80,4 s e
acusa 26 erros `too complex`. Duas medições independentes, mesmo muro.

Passando dele o quadro só piora: a N=200 são 151 s e 105 erros. Não é um degrau
que se atravessa com paciência — o solver para de responder e o projeto deixa de
ter tipagem confiável.

**Não é contagem de módulo, é trabalho de inferência.** Seis arquivos densos,
cheios de closure aninhada, derrubaram um N=100 que passava limpo sem eles.
Poucos arquivos pesados custam mais que dezenas de módulos simples. A forma de
callback (`X:OnInit(function(self) ... end)`) custa só 7% a mais que um método
declarado — não é o vilão.

**Referência real.** Dos 27 jogos em disco usados como amostra, o maior tem 46
módulos de service e controller somando os dois lados, ou seja ~23 por lado.
Folga de 4 a 5×.

## Runtime

::: warning Estes números não têm script neste repositório
Foram medidos dentro do Studio, com módulos de benchmark que nunca foram
commitados. Estão aqui porque foram medidos, mas **não são reproduzíveis a
partir deste repositório** como os de cima. Tratar com mais reserva que o resto
da página.
:::

| | |
|---|---|
| overhead do framework por componente, por frame | 0,21 µs |
| 1 000 componentes com `OnTick` a cada frame | 1,3% do orçamento de 60 fps |
| atravessar `self.Dependencies.X` numa chamada | +8,8 ns, ~0 se içado para um local |
| trabalho próprio do Modux no boot | 0,36 ms (o `require` dos módulos é ~88%) |

Type function é custo de **análise** e vale zero em execução — os dois
frameworks fazem `setmetatable` mais lookup, e nada na tipagem sobrevive ao
compilador.

## Reproduzindo

```sh
python tools/bench/bench_estilos.py 10 25 50 100
```

```sh
BENCH_REPS=5 BENCH_ESTILOS=v3sites python tools/bench/bench_estilos.py 200
```

Requisitos e o que cada variável de ambiente faz estão no
[README do harness](https://github.com/victorcarmo2003/ModuxV3/tree/master/tools/bench).

## O que não foi medido

- **O Studio.** Tudo aqui roda no `luau-lsp` de linha de comando. O editor tem o
  próprio cache e o próprio agendamento, e o veredito final é ele.
- **Memória.** Nem de análise nem de runtime.
- **N acima de 200.** O muro já aparece a N=150, então medir além disso diria
  pouco: o solver para de responder e o projeto deixa de ter tipagem confiável
  muito antes.
- **Outros frameworks.** Esta página mede o Modux V3 contra ele mesmo — o custo
  de cada peça da tipagem e o que acontece quando o projeto cresce. Comparar com
  outro framework exigiria igualar não só a carga, mas o quanto cada um se
  propõe a verificar, e isso é uma medição diferente.
