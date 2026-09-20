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

**Carga igualada.** Comparar o projeto V2 real com o V3 real seria comparar dois
jogos diferentes. Os projetos comparados aqui são sintéticos e recebem a
**mesma** superfície compartilhada, a mesma contagem de módulos, os mesmos
métodos e as mesmas travessias entre módulos. O que muda é só como o tipo chega
em quem escreve.

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

## V2 contra V3: como o custo de análise escala

Quatro estilos, todos com `--!strict`, todos com N sítios de declaração exceto
onde marcado. Mediana de 3 rodadas.

| N | Luau puro | V2, 1 sítio | V2, N sítios | V3, N sítios |
|---:|---:|---:|---:|---:|
| 10 | 31 ms | 94 ms | 42 ms | **193 ms** |
| 25 | 67 ms | 110 ms | 299 ms | **537 ms** |
| 50 | 53 ms | 166 ms | 239 ms | **2 079 ms** |
| 100 | 172 ms | 319 ms | 542 ms | **19 546 ms** |
| 150 † | — | — | 2 859 ms | **80 384 ms** |
| 200 † | — | — | 4 005 ms | **151 146 ms** |

Zero erro em todas as células até N=100, nas quatro colunas. Depois disso só o
V3 quebra:

| N | erros do V3 | erros do V2 |
|---:|---|---|
| 150 | 26, todos `Code is too complex to typecheck` | 0 |
| 200 | 105, todos `Code is too complex to typecheck` | 0 |

† rodada única, não mediana — cada célula dessas leva de um a três minutos.

**O V2 é mais barato de analisar, e por bastante.** A 100 módulos o V3 custa 36
vezes o V2 com o mesmo número de sítios. E a curva não é a mesma: dobrar N de 50
para 100 multiplica o V2 por 2,3 e o V3 por **9,4** — algo perto de N³.

A razão é estrutural e já estava documentada: cada sítio de declaração do V3
resolve o Manifest inteiro do seu lado. Com N módulos e um Manifest de N
entradas, isso é N × N por construção. O V2 não tem esse problema porque o tipo
dele não vem da chamada — vem de um alias que o gerador escreve, e um alias
resolve uma vez.

::: tip O que o V2 cobra em troca
No V2, `Modux.Controller(id)` é declarado como `(id: string, mode: Mode?) -> any`.
O tipo **não chega pela chamada**. Para o `self` ser tipado, o arquivo precisa
da anotação — é exatamente o que a coluna "V2, N sítios" mede: cada módulo faz
`local C: T.ModX = M.Controller("ModX")`.

A coluna "V2, 1 sítio" é o V2 sem essa anotação em lugar nenhum: 319 ms a 100
módulos, com o `self` valendo `any` na maioria dos arquivos.

Então a troca é essa, e é direta: **o V2 é barato de analisar porque você
escreve a anotação; o V3 é caro de analisar porque ele escreve por você.**
:::

### Em qual coluna o V2 real vive

A tabela acima compara duas colunas de V2, e vale saber qual delas descreve
código que existe. Medido num jogo V2 real em disco, 142 arquivos `.luau` sob
`src/`, dos quais 53 são do autor e 89 são o framework:

| | |
|---|---:|
| módulos declarados | 31 |
| declarações **com** anotação de tipo | **0** |
| arquivos do autor com `--!strict` | 8 de 53 |
| arquivos do autor sem modo nenhum | 45 de 53 |

Nenhuma anotação, em lugar nenhum. E `ControllerFn` é
`(id: string, mode: Mode?) -> any` (`src/shared/Modux/Types.luau`), então o
`self` vale `any` nos 31.

O teste que fecha a questão, numa cópia do projeto: troquei uma chamada por
`self.CampoQueNaoExiste:MetodoInventado()` e, junto, pus um erro de controle
que não depende de `self` nenhum — `local controle: number = "isso e string"`.

```
TypeError total: 2384   (antes: 2384)
HitController.luau: (nada)
```

Nenhum dos dois foi reportado, porque o arquivo não declara `--!strict`.

::: danger A comparação de 36× é generosa com o V2
O padrão que a coluna "V2, N sítios" mede — `local C: T.ModX = M.Controller("ModX")`
com `--!strict` — **não aparece uma única vez** nesse projeto. O V2 real está na
coluna "1 sítio", e mesmo essa é medida em strict, que o projeto quase não usa.

A frase acima ("o V2 é barato porque você anota") continua certa, mas a prática
é mais dura: **você não anota**. O V2 é barato porque não está verificando. O
projeto carrega 2 384 `TypeError` em pé e um `number = "string"` que ninguém vê.

Isso não absolve o V3. Os 19,5 s e o muro entre 100 e 150 são reais e
reproduzidos. Só delimita o que a comparação diz: é o V3 tipando tudo contra um
V2 que, como de fato é escrito, tipa quase nada.
:::

::: warning Não compare com os números sintéticos
Analisar esse projeto inteiro leva 9,8 s, e esse número **não** entra em
nenhuma tabela desta página. São 142 arquivos com stack de rede, tipos de
`Instance` e 89 arquivos de framework — carga diferente de tudo que está sendo
comparado aqui. Serve só para dizer que rodou e que os erros injetados não
apareceram.
:::

### Autocomplete: nenhum dos dois é sentido

Mediana quente de `textDocument/completion`, 7 chamadas, descartando a primeira:

| N | V2, N sítios | V3, N sítios |
|---:|---:|---:|
| 10 | 5,9 ms | 0,5 ms |
| 25 | 5,3 ms | 0,5 ms |
| 50 | 5,6 ms | 0,7 ms |
| 100 | 6,3 ms | 0,9 ms |

Os dois estão muito abaixo do que se percebe digitando, e nenhum dos dois cresce
com N de forma relevante.

::: warning Não leia isso como "o V3 é 7x mais rápido"
As duas superfícies têm tamanhos diferentes: o `self` do V2 devolve 17 membros
nesse ponto e o do V3 devolve 5, porque no V3 os métodos do framework chegam
pela metatable. Menos item para montar é menos trabalho.

O que a tabela sustenta é mais modesto e mais útil: **o muro do V3 é o `analyze`
em lote, não a digitação.** Quem sente 19 segundos é o CI, não quem está
escrevendo.
:::

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
| V2, 1 sítio | 69 ms |

::: warning Abaixo de ~500 ms, não leve a vírgula a sério
As duas tabelas acima vieram de rodadas diferentes, cada uma com a sua linha de
base. O mesmo `v2` a N=100 aparece como 69 ms numa e 319 ms na outra — não porque
mudou, mas porque subtrair uma constante de 1,8 s de um total de 1,9 s deixa um
resto com erro relativo enorme.

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

## O que o V3 compra com isso

O custo de análise é o lado ruim da troca. O lado bom é medível também.

### Superfície gerada

Projetos reais, cada um no seu repositório, contando só o que o gerador escreve:

| | módulos | arquivos gerados | linhas | bytes | por módulo |
|---|---:|---:|---:|---:|---:|
| Modux V2 | 13 | 9 | 1 142 | 38 967 | 2 998 B |
| Modux V3 (template) | 11 | 16 | 291 | 8 470 | **770 B** |

O V2 concentra tudo em poucos arquivos grandes: `CoreTypes.luau` com 351 linhas,
`ExtraTypes.luau` com 277, `ComponentTypes.luau` com 138. Cada um desses
re-declara a lista inteira de aliases no topo. O V3 espalha em uma folha pequena
por módulo, e a folha só carrega a superfície pública daquele módulo.

São **3,9× menos bytes gerados por módulo**, e é isso que aparece no diff quando
você renomeia um método.

### O loop de geração

O Watcher do V2 é TypeScript e regenera o projeto inteiro a cada mudança:
`generateTypes` com mediana de **967 ms** em 13 módulos, mais 400 ms de debounce,
ou seja **~1,37 s por save** até o tipo estar certo na tela. O `modux` do V3 é um
binário e escreve por módulo.

É a diferença entre "o tipo aparece" e "o tipo aparece daqui a um segundo e
meio", e é a que se sente o dia inteiro — ao contrário do `analyze`, que se paga
uma vez por commit.

### Ferramenta ausente

Apagando os tipos gerados e analisando o que sobra: V2 acusa **1 632**
`TypeError`, V3 acusa **15**. Número absoluto, não normalizado pelo tamanho do
projeto, então serve para ver a ordem de grandeza e nada mais: no V2 o código
escrito à mão depende dos tipos gerados para compilar; no V3, quase não.

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
BENCH_REPS=5 BENCH_ESTILOS=v2sites,v3sites python tools/bench/bench_estilos.py 200
```

Requisitos e o que cada variável de ambiente faz estão no
[README do harness](https://github.com/victorcarmo2003/ModuxV3/tree/master/tools/bench).

## O que não foi medido

- **O Studio.** Tudo aqui roda no `luau-lsp` de linha de comando. O editor tem o
  próprio cache e o próprio agendamento, e o veredito final é ele.
- **Projeto real contra projeto real.** O V2 em disco tem 13 módulos, uma stack
  de rede e tipos de `Instance`; o V3 tem outra carga. Comparar os dois
  diretamente mediria a diferença de conteúdo, não de estratégia. Por isso tudo
  que compara V2 e V3 nesta página é sintético e com a carga igualada.
- **Memória.** Nem de análise nem de runtime.
- **N acima de 200.** Existe uma medição antiga sugerindo que o V3 volta a ganhar
  perto de N=1000, quando a union de `Import` do V2 vira ela própria O(N²). Não
  foi refeita com este harness e não entra aqui — e, de todo modo, o V3 já não
  compila a N=150, então a comparação nessa faixa seria acadêmica.
