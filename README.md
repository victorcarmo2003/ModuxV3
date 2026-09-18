# Modux

Framework de módulos para Roblox em que o `self` já vem tipado, sem você anotar
nada.

```lua
--!strict
const Zombie = Modux.Controller("Zombie", { Require = { "Skeleton" } })

function Zombie:Heal(amount: number, target: Instance)
	self.Dependencies.Skeleton:ShotArrow()    -- tipado
	self.Components.Highlight:Create(target)  -- tipado
	self.Libs.Signal.new()                    -- tipado
end
```

Você não escreveu nenhum tipo. `Skeleton` sabe quais métodos tem, `Highlight`
devolve o componente certo, e trocar `"Skeleton"` por um nome que não existe
quebra a análise antes de rodar.

O truque: um gerador lê os teus módulos e escreve uma folha de tipo por módulo.
O framework junta essas folhas com type functions do Luau. Você escreve Luau
normal; o tipo aparece.

---

## Por que não só escrever na mão

Porque a alternativa é declarar a mesma superfície duas vezes e mantê-la em
sincronia para sempre. A abordagem anterior deste projeto expandia o `self`
inteiro em cada arquivo, e o autocomplete ficava **4 a 6× mais lento** que hoje
— o custo de manutenção virava custo de digitação.

Números medidos neste repositório, não estimados:

| | |
|---|---|
| autocomplete, 18 módulos | 18 ms depois de cada tecla |
| overhead do framework por componente, por frame | 0,21 µs |
| 1000 componentes com `OnTick` a cada frame | 1,3% do orçamento de 60 fps |
| atravessar `self.Dependencies.X` numa chamada | +8,8 ns, ~0 se içar para um local |
| trabalho próprio do Modux no boot | 0,36 ms (o `require` dos módulos é ~88%) |

O framework não é o gargalo em nada que deu para medir. O que pesa é o corpo
que **você** escreve.

---

## As três espécies

| | roda em | existe | alcança |
|---|---|---|---|
| **Controller** | client | um por jogo | outros Controllers |
| **Service** | server | um por jogo | outros Services |
| **Component** | os dois | um por `Instance` tagueada | Controllers no client, Services no server |

Lado não atravessa, e não é convenção: um Controller que declara `Require` de um
Service **interrompe a geração**, com uma mensagem dizendo quem está de que lado.
Comunicação entre lados é rede, e rede é explícita.

Componente é ligado a `Instance` via CollectionService. Sem `Tag` declarada, a
tag é o próprio ID.

```lua
const Highlight = Modux.Component("Highlight", { Require = { "Render" } })

function Highlight:TurnOn()
	self.Instance.Color = Color3.new(1, 1, 0)   -- Instance sempre existe
end

Highlight:OnDestroy(function(self)
	self:Destroy()      -- ou de fora: self.Components.Highlight:Destroy(inst)
end)
```

## Ciclo de vida

`OnInit` → `OnStart` → `OnTick` → `OnDestroy` (só componente).

A injeção acontece **antes** de qualquer `OnInit`, o que faz dependência mútua
A↔B funcionar: quando o teu código roda, tudo já existe.

```lua
X:OnTick(callback, tickRate, priority)   -- sem os dois: 1 Hz, priority 1
```

`priority` maior roda primeiro, e o empate desempata pela ordem de registro —
determinístico, não muda quando outro módulo entra.

Componente tagueado pelo Studio sobe depois que todos os singletons startaram.
`Create` é o oposto: constrói e devolve **na mesma linha**, porque `AddTag` só
avisa no próximo frame e esperar isso é gambiarra.

## Configuração

```lua
Modux.Start({ DebugLevel = "High", Profiling = true })
```

| `DebugLevel` | mostra | avisa lento acima de |
|---|---|---|
| `Low` | tempo total de boot | 100 ms |
| `Medium` | + singletons e módulos requeridos | 16,7 ms |
| `High` | + tempo de cada `require` | 1 ms |

`Profiling` marca as fases no MicroProfiler **e** categoriza a memória por
módulo, então a aba de memória mostra quem alocou o quê.

---

## Libs: dependência de dados, não de código

O core não requer Promise, Signal nem rede. Ele requer um arquivo que o
gerador escreve varrendo `src/Libs`, e injeta o resultado em `self.Libs`:

```lua
self.Libs.Signal.new()      -- tipado, sem require no teu arquivo
self.Libs.Inexistente       -- Key 'Inexistente' not found
```

A lib não precisa aderir a contrato nenhum — o tipo sai de `typeof(require(...))`.
Apagar uma lib da pasta não quebra o framework: a entrada some do tipo e quem
usava falha no lugar certo. É o que torna o Modux publicável sem arrastar
biblioteca de terceiro junto.

## Estrutura

```
src/Modux/      framework    client, server e shared
src/Shared/     framework    Types (SelfOf, Pick, Occlude, Struct, Union) e tablejs
src/Libs/       suas libs    Signal, Promise, FSM — injetadas em self.Libs
```

Não há exemplo no repositório. Os teus Controllers, Services e Components
entram em qualquer pasta sob `src/`, e o lado sai do caminho: pasta `client`
vai para StarterPlayerScripts, `server` para ServerScriptService, e o resto é
shared.

```
src/Entity/client/Zombie/init.luau      -> Controller de client
src/Systems/server/Data/init.luau       -> Service de server
src/Components/client/Highlight/init.luau
```

## Gerado, não editar

`Type.luau` de cada módulo, `Manifest/` e `Modules.luau` de cada lado são saída
do gerador. Editar é perder na próxima geração.

```sh
modux generate    # escreve tudo uma vez
modux watch       # regera o que mudar
modux check       # falha se algo está desatualizado (use no CI)
modux list        # mostra os módulos, espécie e dependências
```

## Rodando

```sh
rokit install                     # rojo, rogen, modux
rogen build                       # gera o default.project.json a partir das pastas
modux generate                    # gera folhas e Manifest
rojo serve                        # conecta no Studio
```

**`rogen build` vem antes do `modux generate`.** O `default.project.json` é
gerado a partir da estrutura de pastas; rodando fora de ordem, o gerador resolve
caminho por um arquivo velho e o sintoma é `Unknown require` em código correto.

`tools/analyze.ps1` roda o mesmo motor do editor sobre o projeto inteiro, fora
do Studio.

### `LuauSolverV2` é obrigatório

Type function não existe no solver antigo. Sem a flag, `self` fica sem tipo e o
autocomplete devolve **zero item** — sem erro, sem aviso, só nada. O
`.vscode/settings.json` deste repositório já liga
`luau-lsp.fflags.enableNewSolver`.

---

## Limites conhecidos

**Teto de escala.** O custo de tipagem é superlinear: cada módulo resolve o
Manifest do seu lado. Entre 100 e 150 módulos **por lado** o solver começa a
responder `Code is too complex to typecheck`. Como Controller e Service ficam em
Manifests separados, dividir por lado quase triplica a folga. Cinco formas de
reorganizar os tipos foram medidas e nenhuma ganhou do desenho atual.

**Sem rede.** Comunicação client/server ainda não existe. Hoje o framework
impede a travessia, mas não oferece a ponte. Quando existir, entra como lib em
`src/Libs`, não como parte do core.

**Anotação onde o gerador não adivinha.** Literal e função ele lê sozinho; o
resto pede `::`.

```lua
self.Vida = 100                          -- vira number
self.Orientacao = CFrame.new() :: CFrame -- precisa da anotação
```
