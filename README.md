<h1 align="center">Modux</h1>

<p align="center">Framework com tipagem automática para Roblox que potencializa os seus types e te incentiva a manter sempre boas práticas.

---

<h3 align="center">
    Documentação: <a href="https://victorcarmo2003.github.io/ModuxV3/">Modux</a>
</h3>


---

Modux é um framework de módulos para Roblox cujo objetivo é trazer mais poder à
sua tipagem, e que devolve alertas e erros em tempo de análise — você não precisa
ficar rodando o jogo para achar um erro que o editor já sabia apontar.

Por exemplo: um valor simples atribuído ao `self` já volta com tipo gerado.


```lua
--!strict
const Zombie = Modux.Controller("Zombie")

function Zombie:Heal(amount: number)
	self.Health = amount
end

Zombie.Health --> number
```

O truque: um gerador lê os teus módulos e escreve uma folha de tipo por módulo.
O framework junta essas folhas com type functions do Luau. Você escreve Luau
normal; o tipo aparece.

## Por que não só escrever na mão

Se tipagem automática, bootstrap tipado e requires cíclicos resolvidos com DI
(Dependency Injection) ainda não te convenceram, pense no trabalho que seria
escrever métodos, parâmetros e valores do `self` à mão, o tempo inteiro, mantendo
tudo em dia com o que o código realmente faz.

É por isso que tanta gente desiste de tipagem em Luau — e é exatamente esse
trabalho que o Modux tira da frente.

## Economia de tempo
Além do `strict` e do apoio de type functions, o Modux tem tipos genéricos para
os controllers que você cria, e uma ferramenta que converte os seus métodos, os
parâmetros deles e os valores simples do `self` numa folha de tipo gerada para
cada módulo.

Escrevendo um nome como `string` ou uma idade como `number` no `self`, o campo
vem tipado em qualquer outro lugar que toque o `self`:

```lua
const Zombie = Modux.Controller("Zombie")

function Zombie:Heal(amount: number)
	self.Name = "Joaquim"
	self.Age = 197
end

function Zombie:Teste()
	self.Name --> string
	self.Age --> number
    self:Heal("Abc") --> Type Error: Expected number, got string
end
```

## Require
O mesmo vale para o que você declara em `Require`. Com `Require = { "Skeleton" }`,
o módulo Skeleton aparece tipado dentro de `self.Dependencies`, com autocomplete
nos métodos e nos parâmetros:
```lua
--!strict
const Skeleton = Modux.Controller("Skeleton")

function Skeleton:ShootArrow(Target: Instance)
end
```
E em outro controller utilizando ele:
```lua
--!strict
const Zombie = Modux.Controller("Zombie", { Require = { "Skeleton" } })

function Zombie:Heal(amount: number, target: Instance)
	self.Dependencies.Skeleton:ShootArrow(target) -- tipado, sem você anotar nada
end
```

O Modux suporta dependências mútuas: `Zombie` pode requerer `Skeleton` e
`Skeleton` pode requerer `Zombie`.

A maior vantagem é que você não escreveu tipo nenhum. Dentro de `Dependencies >
Skeleton` ele mostra exatamente quais métodos existem e quais parâmetros cada um
pede. Declarar em `Require` um módulo que não existe também acusa erro.

O truque: um gerador lê os seus módulos e escreve uma folha de tipo por módulo. O framework junta essas folhas com type functions do Luau.

## Modelos

| | roda em | existe | alcança |
|---|---|---|---|
| **Controller** | client | um por jogo | outros Controllers |
| **Service** | server | um por jogo | outros Services |
| **Component** | os dois | um por `Instance` tagueada | Controllers no client, Services no server |

Não há como misturar Controllers e Services, e não é convenção: um Controller que
declara `Require` de um Service **interrompe a geração de tipagem**, com uma
mensagem dizendo quem está de que lado. Comunicação entre lados é rede, e rede é
explícita.

No Modux:

- Controllers vivem no client.
- Services vivem no server.
- Componentes existem nos dois lados, mas não conversam entre lados.

## Componentes
Componente é ligado a `Instance` via CollectionService. Sem `Tag` declarada, a
tag é o próprio ID.

```lua
local ServerScriptService = game:GetService("ServerScriptService")
local Modux = require(ServerScriptService.server.Modux)

const Highlight = Modux.Component("Highlight")

Highlight:OnInit(function(self)
	local new = Instance.new("Highlight")
	new.Parent = self.Instance
	task.delay(5, function()
		self.Instance:Destroy()
	end)
end)

return Highlight
```
Esse script faz com que toda instância com a tag `Highlight` receba um Highlight
e seja destruída depois de 5 segundos. Vale tanto para a instância que já começa
o jogo com a tag quanto para a tag adicionada ao longo dele.

## Ciclo de vida

`OnInit` → `OnStart` → `OnTick` → `OnDestroy (componentes apenas)`.

A injeção acontece antes de qualquer `OnInit`, o que faz dependência mútua A↔B
funcionar: quando o teu código roda, tudo já existe.

O loader completa todos os `OnInit` antes de começar qualquer `OnStart`, e ordena
as duas fases por `Priority` decrescente. É isso que permite dizer "registre no
`OnInit`, dispare no `OnStart`" e ter certeza da ordem.

```lua
X:OnTick(callback, tickRate, priority)   -- sem os dois: 1 Hz, priority 1
```

O `tickRate` e o `priority` são opcionais: o padrão é 1 Hz e prioridade 1.
`priority` maior roda primeiro, e o empate desempata pela ordem de registro —
determinístico, não muda quando outro módulo entra. O `priority` do tick é
independente do `Priority` do módulo.

Componente tagueado pelo Studio sobe depois que todos os singletons startaram.

Quando uma tag entra por `CollectionService:AddTag()`, o componente só nasce no
frame seguinte — o sinal é assíncrono. Para ter o componente na hora, use
`CreateComponent()`: ele cria a instância e devolve o componente na mesma
chamada.

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
src/Entity/client/Zombie.luau           -> Controller de client
src/Systems/server/Data.luau            -> Service de server
src/Components/client/Highlight.luau
```

Um módulo é um arquivo. Se ele precisar de arquivos só dele, vira uma pasta
com `init.luau` e os irmãos dentro — as duas formas dão a mesma instância.

## Gerado, não editar

A folha de tipo de cada módulo (`src/ModuxTypes/<lado>/<Id>.luau`), o `Manifest/` e
o `Modules.luau` de cada lado são saída do gerador. Editar é perder na próxima
geração.

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

## Limitações atuais

**Teto de escala.** O custo de tipagem é superlinear: cada módulo resolve o
Manifest do seu lado. Entre 100 e 150 módulos **por lado** o solver começa a
responder `Code is too complex to typecheck`. Como Controller e Service ficam em
Manifests separados, dividir por lado quase triplica a folga — 100 módulos num
lado só custam 25,3 s de `analyze`, e os mesmos 100 divididos custam 9,1 s.
Cinco formas de reorganizar os tipos foram medidas; as duas que chegaram a ficar
mais baratas perdem `Dependencies` ou `Libs` no caminho, e a mais óbvia —
pré-computar o `self` no Manifest — não fica mais rápida, ela para de compilar.
Os números e o método estão em [Benchmarks](https://victorcarmo2003.github.io/ModuxV3/benchmarks).

**Anotação onde o gerador não adivinha.** Literal e função ele lê sozinho; o
resto pede `::`.

```lua
self.Vida = 100                          -- vira number
self.Orientacao = CFrame.new() :: CFrame -- precisa da anotação
```

**Nem toda lib entra em `self.Libs`.** Uma lib cujo tipo contenha type function
não reduzida derruba a tipagem do projeto inteiro. Vide e Lync caem nesse caso;
o contorno é requerê-las direto onde se usa.

## Decisões de design

Estas não são limitações — são escolhas, e existem por um motivo.

**Client e server são isolados.** Um Controller não alcança um Service, e a
tentativa interrompe a geração em vez de virar um erro de runtime. Comunicação
entre lados é rede, e rede é explícita.

**Rede fica fora do core.** O framework impede a travessia mas não oferece a
ponte, de propósito: quando existir, entra como lib em `src/Libs`, não como
parte do core. É o que mantém o Modux publicável sem arrastar uma stack de rede
junto.

**Libs entram por injeção, não por require.** O core não conhece Promise,
Signal nem rede — ele conhece um arquivo que o gerador escreve varrendo
`src/Libs`. Apagar uma lib da pasta não quebra o framework: a entrada some do
tipo e quem usava falha no lugar certo.
