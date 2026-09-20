# Introdução

Modux é um framework de módulos para Roblox cujo objetivo é trazer mais poder à sua tipagem
e que também retorna alertas/erros fazendo com que você não tenha que ficar executando 
constantemente os seus códigos para achar erros.

Como por exemplo, se inserirmos o self com algum valor básico, ele vem com um type autogerado:

:::demo
```lua
--!strict
const Zombie = Modux.Controller("Zombie")

function Zombie:Heal(amount: number)
	self.Health = amount
end

Zombie.Health --> number
```	
:::
:::tip Dica:
Algumas coisas você não precisa dar play para ver que vai dar erro, apenas tipe!
:::

### Economia de tempo
Além do `strict` e o apoio de `typefunctions`, o modux possui `generic types` para controllers criados
além de uma tool que converte as próprias funções, parâmetros de funções e valores simples no self para 
tipagem em um arquivo de `Types.luau` que é gerado dentro do module

Então por exemplo ao escrever um `nome como string` ou uma `idade como number` no `self`, ele vem tipado em qualquer outro 
lugar que utilize o self:
::: demo
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
:::
<Shot
  src="/typeExample.gif"
  alt="autocomplete resolvendo o self"
  title="Demonstração prática"
  caption="O self já vem tipado, sem você anotar nada!"
  width="700px"
/>

### Require
O mesmo vale também para os requires inseridos no head, como por exemplo ao fazer: `Require = { "Skeleton" }` ele tipa dentro de dependencias o module Skeleton e atribui as funções com autocomplete incluindo os parâmetros:
::: demo
```lua
--!strict
const Skeleton = Modux.Controller("Skeleton")

function Skeleton:ShootArrow(Target: Instance)
end
```
:::
Em outro module utilizando:
::: demo
```lua
--!strict
const Zombie = Modux.Controller("Zombie", { Require = { "Skeleton" } })

function Zombie:Heal(amount: number, target: Instance)
	self.Dependencies.Skeleton:ShootArrow(target) -- tipado, sem você anotar nada
end
```
:::
<Shot
  src="/requireExample.gif"
  alt="autocomplete resolvendo o self"
  title="Demonstração prática"
  caption="Sim! Os modules podem ter dependência mútua (Dependency Injection)"
  width="700px"
/>

A maior vantagem é que você não escreveu tipo nenhum. Dentro de `Dependencies >
Skeleton` ele mostra exatamente quais métodos existem e quais parâmetros cada um
pede. Declarar em `Require` um módulo que não existe também acusa erro.

#### Eles podem se requerer mutuamente

Isso é injeção de dependência de verdade, e a diferença aparece aqui: **A pode
requerer B enquanto B requer A**. Os dois continuam tipados, e não há ciclo.

```lua
const AService = Modux.Service("AService", { Require = { "BService" } })
function AService:Ping(n: number): number
	return self.Dependencies.BService:Pong(n)
end
```

```lua
const BService = Modux.Service("BService", { Require = { "AService" } })
function BService:Rebote(n: number): number
	return self.Dependencies.AService:Ping(n)
end
```

Com `require` comum isso seria um ciclo — cada arquivo pedindo o outro antes
de existir. Aqui não é, e por dois motivos distintos:

**No runtime**, você nunca requer o outro módulo. O loader sobe em duas fases
e entrega os módulos já construídos dentro de `self.Dependencies`. A lista de
módulos devolve Instances, nunca `require`. Ver
[Ciclo de vida](/arquitetura/ciclo-de-vida).

**Na tipagem**, cada módulo tem a própria folha de tipo, e a folha carrega só
a superfície pública daquele módulo — ela não conhece o Manifest. Quem junta
as folhas é o Manifest, e ninguém junta de volta. Ver
[Como a tipagem funciona](/tipagem/).

Medido no template: dois Services se requerendo, `luau-analyze` com **0 erro e
0 ciclo**.

O truque: um gerador lê os seus módulos e escreve uma folha de tipo por módulo.
O framework junta essas folhas com type functions do Luau. Como isso funciona
por dentro está em [Como a tipagem funciona](/tipagem/).

E para o caso de componentes, vamos para o exemplo prático com um `Highlight` como exemplo:
::: demo
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
:::
Com isso tudo o que tiver a tag Highlight no roblox automaticamente
é associado à essa classe e o `OnInit` é chamado de imediato.
<Shot
  src="/componentExample.gif"
  alt="autocomplete resolvendo o self"
  title="Demonstração prática"
  caption="O loader carrega o CollectionService puxando existente e novos"
  width="700px"
/>

No entanto caso queira criar um componente a partir de outra classe,
não adicione uma tag, utilize o método `CreateComponent`,
consulte a sessão de [Components](/arquitetura/componentes).

## Porque usar?
Se tipagem automática, bootstrap tipado e requires cíclicos resolvidos com DI
(Dependency Injection) ainda não te convenceram, pense no trabalho que seria
escrever métodos, parâmetros e valores do `self` à mão, o tempo inteiro, mantendo
tudo em dia com o que o código realmente faz.

É por isso que tanta gente desiste de tipagem em Luau — e é exatamente esse
trabalho que o Modux tira da frente.

## Arquitetura

As peças do framework — Controller, Service, Component, e como eles se ligam —
estão em [Arquitetura](/arquitetura/).

## Limitações conhecidas

**Teto de escala.** Entre 100 e 150 módulos **por lado** o solver começa a
responder `Code is too complex to typecheck`. Como Controller e Service ficam em
Manifests separados, dividir por lado quase triplica a folga. Cinco formas de
reorganizar os tipos foram medidas e nenhuma **utilizável** ganhou do desenho
atual — ver [Benchmarks](/benchmarks#onde-mora-o-custo).

**Sem rede embutida.** O framework impede a travessia de lado, mas não oferece a
ponte. Rede entra como lib em [`src/Libs`](/arquitetura/libs), não como parte do core.

### Benchmark
Números medidos, não estimados. O método, o ambiente e as tabelas completas
estão em [Benchmarks](/benchmarks) — inclusive a comparação com o Modux V2, em
que o desenho atual **perde** em tempo de análise.

| | |
|---|---|
| autocomplete, mediana quente a 100 módulos | 0,9 ms |
| `analyze` do projeto, 100 módulos num lado | 19,5 s |
| os mesmos 100 divididos entre client e server | 9,1 s |
| superfície gerada por módulo, contra o V2 | 3,9× menor |
| overhead por componente, por frame (runtime) | 0,21 µs |

O que pesa é o `analyze` em lote, que roda uma vez por commit. Digitando, nada
disso é sentido.

### Parser
O gerador não dá conta de toda lib, principalmente quando o valor vem de uma
chamada de função. Nesses casos basta um cast `::` para o campo entrar tipado no
`self`.

::: demo
```lua
self.Vida = 100                          -- vira number
self.Orientacao = CFrame.new() :: CFrame -- precisa da anotação
```
:::