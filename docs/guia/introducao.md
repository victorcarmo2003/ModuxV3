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
além de uma tool que converte as próprias funções, parâmetros de funcões e valores simples no self para 
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
	self.Dependencies.Skeleton:ShotArrow(target) -- 100% tipado
end
```
:::
<Shot
  src="/requireExample.gif"
  alt="autocomplete resolvendo o self"
  title="Demonstração prática"
  caption="Sim! Um module pode requerir o outro (Dependency Injection)"
  width="700px"
/>

A vantagem maior vantagem é, você não escreveu nenhum tipo. Dentro de Dependencies >
`Skeleton` ele mostra para você exatamente quais métodos tem e quais parâmetros precisa
Caso tente requerir algo que não existe, ele também acusa erro!

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
Bom se a tipagem automático, bootstrap tipado, requires "ciclicos" resolvidos com DI 
(Dependency Injection) tipados ainda não te convenceu, apenas pense no trabalho que seria
escrever  métodos, parâmetros valores do self tudo à mão, o tempo inteiro, 
condizentes com os valores e métodos em tempo real.

Esse é o motivo que fazem muitos desistirem de tipagem em luau e com isso
essa ferramenta se torna perfeita para todos.

## Arquitetura

As peças do framework — Controller, Service, Component, e como eles se ligam —
estão em [Arquitetura](/arquitetura/).

## Limitações conhecidas
Entre 100 e 150 módulos **por lado** o solver começa a
responder `Code is too complex to typecheck`. Como Controller e Service ficam em
Manifests separados, dividir por lado quase triplica a folga. Cinco formas de
reorganizar os tipos foram medidas e nenhuma ganhou do desenho atual.

**Sem rede embutida.** O framework impede a travessia de lado, mas não oferece a
ponte. Rede entra como lib em [`src/Libs`](/arquitetura/libs), não como parte do core.

### Benchmark
Números medidos neste repositório, não estimados:

| | |
|---|---|
| autocomplete, 18 módulos | 18 ms depois de cada tecla |
| overhead do framework por componente, por frame | 0,21 µs |
| 1000 componentes com `OnTick` a cada frame | 1,3% do orçamento de 60 fps |
| atravessar `self.Dependencies.X` numa chamada | +8,8 ns, ~0 se içar para um local |
| trabalho próprio do Modux no boot | 0,36 ms (o `require` dos módulos é ~88%) |

O framework não é o gargalo em nada que deu para medir.

### Parser
o gerador não consegue parsear 100% das libs, principalmente em casos de função, 
nesses casos, basta um cast `::` para inserir de forma automática no self.

::: demo
```lua
self.Vida = 100                          -- vira number
self.Orientacao = CFrame.new() :: CFrame -- precisa da anotação
```
:::