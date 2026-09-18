# Introdução

Modux é um framework de módulos para Roblox em que o `self` já vem tipado, sem
você anotar nada.

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

O truque: um gerador lê os seus módulos e escreve uma folha de tipo por módulo.
O framework junta essas folhas com type functions do Luau. Como isso funciona
por dentro está em [Como a tipagem funciona](/tipos/).

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

O framework não é o gargalo em nada que deu para medir.

## As três espécies

| | roda em | existe | alcança |
|---|---|---|---|
| **Controller** | client | um por jogo | outros Controllers |
| **Service** | server | um por jogo | outros Services |
| **Component** | os dois | um por `Instance` tagueada | Controllers no client, Services no server |

Lado não atravessa, e não é convenção: um Controller que declara `Require` de um
Service **interrompe a geração**, com uma mensagem dizendo quem está de que lado.

## Limites conhecidos

**Teto de escala.** O custo de tipagem é superlinear: cada módulo resolve o
Manifest do seu lado. Entre 100 e 150 módulos **por lado** o solver começa a
responder `Code is too complex to typecheck`. Como Controller e Service ficam em
Manifests separados, dividir por lado quase triplica a folga. Cinco formas de
reorganizar os tipos foram medidas e nenhuma ganhou do desenho atual.

**Sem rede embutida.** O framework impede a travessia de lado, mas não oferece a
ponte. Rede entra como lib em [`src/Libs`](/guia/libs), não como parte do core.

**Anotação onde o gerador não adivinha.** Literal e função ele lê sozinho; o
resto pede `::`.

```lua
self.Vida = 100                          -- vira number
self.Orientacao = CFrame.new() :: CFrame -- precisa da anotação
```
