# Harness de benchmark

Os números que a documentação cita saem daqui. Cada script mede uma coisa
diferente, e nenhum deles estima: todos rodam o `luau-lsp` de verdade.

## O que cada um mede

| script | pergunta que responde |
|---|---|
| `bench_estilos.py` | quanto custa **a forma** de tipar, com a carga igualada entre V2, V3 e Luau puro |
| `bench_types.py` | até onde o projeto **real** cresce antes de o solver desistir |
| `bench_lsp.py` | latência de `textDocument/completion` — é biblioteca, não roda sozinho |
| `bench_gen.py` | gera os módulos sintéticos — é biblioteca, não roda sozinho |

## Requisitos

- Python 3.10+
- A extensão `johnnymorganz.luau-lsp` do VS Code — o binário sai de
  `~/.vscode/extensions/johnnymorganz.luau-lsp-*/bin/server.exe`, sempre a
  versão mais nova. Para apontar outro, `LUAU_LSP_SERVER=/caminho/server.exe`.
- As definitions do Roblox, que a extensão baixa para
  `%APPDATA%/Code/User/globalStorage/johnnymorganz.luau-lsp/`. Sem elas, `game`
  e `task` viram globais desconhecidas e a saída enche de erro que não tem nada
  a ver com a carga medida.
- Só para o `bench_types.py`: `rojo`, `rogen` e `modux` no PATH (o `rokit
  install` da raiz já resolve).

## `bench_estilos.py` — o custo da forma

Gera projetos sintéticos equivalentes, um por estratégia de tipagem, todos com
a **mesma** superfície compartilhada e a mesma contagem de módulos, métodos e
travessias. O que muda é só como o tipo chega em quem escreve.

```sh
python tools/bench/bench_estilos.py 10 50 200
```

| variável de ambiente | efeito |
|---|---|
| `BENCH_REPS` | rodadas de `analyze` por célula; a tabela mostra a mediana (padrão 3) |
| `BENCH_ESTILOS` | roda só os estilos listados, por vírgula |
| `LUAU_LSP_SERVER` | caminho do binário do luau-lsp |

```sh
BENCH_REPS=5 BENCH_ESTILOS=puro-plano,v2,v3sites python tools/bench/bench_estilos.py 200
```

Os estilos:

| nome | o que é |
|---|---|
| `puro-plano`, `puro-cadeia` | Luau sem framework nenhum, a linha de base |
| `v2` | o formato que o Watcher do Modux V2 emitia: cada arquivo reimporta todos os aliases e a union de `Import` cresce com N |
| `v3sites` | **o desenho atual**: folha por módulo, Manifest por lado, `SelfOf.Build` no sítio de declaração |
| `v3ideia`, `v3real` | versões intermediárias do V3, mantidas para comparação |
| `v3pre` | `Build` pré-computado dentro do Manifest |
| `v3leaf` | `Build` dentro de cada folha |
| `v3deps` | `Dependencies` como tabela literal por folha |
| `v3nopick` | igual ao `v3sites`, sem `Pick.Table` — isola o custo do Pick |
| `v3nobuild` | só `index<AllControllers, ID>`, sem `Build` nem `Pick` — isola o custo do Build |

A coluna `liquido` é o `bruto` menos a linha de base. A linha de base é o custo
de carregar as definitions do Roblox, que é constante e maior que o próprio
trabalho medido em N pequeno — sem descontar, todos os estilos parecem
empatados.

`v3nopick` e `v3nobuild` **não são desenhos utilizáveis**. O `v3nopick` dá a
mesma dependência para todo módulo e o `v3nobuild` perde `Dependencies` e
`Libs`. Existem só para medir de onde vem o custo.

## `bench_types.py` — o teto de escala

Gera N controllers de client e S services de server **reais** dentro de
`src/Stress/`, roda o `modux` para produzir Manifest e folhas, e mede o
`analyze` do projeto inteiro mais a latência de uma completion.

```sh
python tools/bench/bench_types.py 75                  # 75 controllers
python tools/bench/bench_types.py 50 --services 50    # o orçamento é por lado?
```

::: warning
Ele escreve em `src/Stress/`, roda `rogen build` e `modux generate` no
repositório, e desfaz tudo no fim. Não rode com um `modux watch` aberto: o
watcher regenera por cima no meio da medição.
:::

`MODUX_BIN` aponta para outro binário do modux, se você estiver testando uma
build local.

## Por que a mediana, e não a média

O `analyze` é um processo novo a cada rodada, e o primeiro de uma sequência
paga cache frio de disco. A média move com esse outlier; a mediana não. Todas
as tabelas da documentação são medianas, e o número de rodadas está escrito
junto.

## O que estes scripts não medem

- **Runtime.** Type function é custo de análise e vale zero em execução. O
  overhead por componente por frame foi medido dentro do Studio, com módulos
  que não estão neste repositório.
- **Studio.** Tudo aqui roda no `luau-lsp` de linha de comando. O editor tem o
  próprio cache e o próprio agendamento, e o veredito final é ele.
