<h1 align="center">Modux</h1>

<p align="center">Framework com tipagem automática para Roblox que potencializa os seus types e te incentiva a manter sempre boas práticas.

---

<h3 align="center">
    Documentação: <a href="https://victorcarmo2003.github.io/ModuxV3/">Modux</a>
</h3>


---

Modux é um framework de módulos para Roblox cujo objetivo é trazer mais poder à sua tipagem e que também retorna alertas/erros fazendo com que você não tenha que ficar executando constantemente os seus códigos para achar erros.

Como por exemplo, se inserirmos o self com algum valor básico, ele vem com um type autogerado:


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

Bom se a tipagem automático, bootstrap tipado, requires "ciclicos" resolvidos com DI (Dependency Injection) 
tipados ainda não te convenceu, apenas pense no trabalho que seria escrever métodos, parâmetros valores do self 
tudo à mão, o tempo inteiro, condizentes com os valores e métodos em tempo real.

Esse é o motivo que fazem muitos desistirem de tipagem em luau e com isso essa ferramenta se torna perfeita para todos.

## Economia de tempo
Além do strict e o apoio de typefunctions, o modux possui generic types para controllers criados além de uma tool que converte as próprias funções, parâmetros de funcões e valores simples no self para tipagem em um arquivo de Types.luau que é gerado dentro do module

Então por exemplo ao escrever um nome como string ou uma idade como number no self, ele vem tipado em qualquer outro lugar que utilize o self:

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
O mesmo vale também para os requires inseridos no head, como por exemplo ao fazer: Require = { "Skeleton" } 
ele tipa dentro de dependencias o module Skeleton e atribui as funções com autocomplete incluindo os parâmetros:
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
	self.Dependencies.Skeleton:ShotArrow(target) -- 100% tipado
end
```

O modux também funciona 100% com dependências mútuas ou seja, Zombie pode requerir skeleton e skeleton pode requerir Zombie

A vantagem maior vantagem é, você não escreveu nenhum tipo. Dentro de Dependencies > Skeleton ele mostra para você exatamente 
quais métodos tem e quais parâmetros precisa. Caso tente requerir algo que não existe, ele também acusa erro!

O truque: um gerador lê os seus módulos e escreve uma folha de tipo por módulo. O framework junta essas folhas com type functions do Luau.

## Modelos

| | roda em | existe | alcança |
|---|---|---|---|
| **Controller** | client | um por jogo | outros Controllers |
| **Service** | server | um por jogo | outros Services |
| **Component** | os dois | um por `Instance` tagueada | Controllers no client, Services no server |

Não há como misturar Controllers e Services, e não é convenção: um Controller que declara `Require` de um
Service **interrompe a geração de tipagem**, com uma mensagem dizendo quem está de que lado.
Comunicação entre lados é rede, e rede é explícita.

No modux:
Controllers vivem no Client-side
Services vivem no Server-side
Componentes existem para o client-side e para o server-side, porém não interagem cross-side

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
Esse script por exemplo faz com que, o que tiver a tag "Highlight" receba um Highlight
E seja destruído após 5 segundos. Isso funciona tanto para quando a instância já começar
o game com aquela tag quanto para com a tag sendo adicionada ao longo do game.

## Ciclo de vida

`OnInit` → `OnStart` → `OnTick` → `OnDestroy (componentes apenas)`.

A injeção acontece antes de qualquer OnInit, o que faz dependência mútua A↔B funcionar: quando o teu código roda, tudo já existe.

O loader completa todos os OnInit antes de começar qualquer OnStart, e ordena as duas fases por Priority decrescente. 
Isso é o que permite dizer "registre no OnInit, dispare no OnStart" e ter certeza da ordem.

```lua
X:OnTick(callback, tickRate, priority)   -- sem os dois: 1 Hz, priority 1
```

O TickRate e o Priority são opcionais, o default é 1hz e prioridade 1,
priority maior roda primeiro, e o empate desempata pela ordem de registro — determinístico, não muda quando outro módulo entra.
O priority do tick é independente do Priority do módulo.

Componente tagueado pelo Studio sobe depois que todos os singletons startaram.
`Create` é o oposto: constrói e devolve **na mesma linha**, porque `AddTag` só
avisa no próximo frame por isso ao invés de fazer CollectionService:AddTag() e depois tentar puxar
a instância, deve-se na verdade utilizar o método CreateComponent() que então te retorna aquele componente.

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
