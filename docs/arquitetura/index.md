# Arquitetura

Um módulo é uma pasta com `init.luau` que declara a sua espécie e devolve a
si mesmo. São três espécies, e a diferença entre elas é onde rodam e o que
alcançam.

| | roda em | existe | alcança |
|---|---|---|---|
| **Controller** | client | um por jogo | outros Controllers |
| **Service** | server | um por jogo | outros Services |
| **Component** | os dois | um por `Instance` tagueada | Controllers no client, Services no server |

Lado não atravessa, e não é convenção: um Controller que declara `Require` de um
Service **interrompe a geração**, com uma mensagem dizendo quem está de que lado.


Cada uma tem a sua página: [Controllers](/arquitetura/controllers),
[Services](/arquitetura/services) e [Componentes](/arquitetura/componentes).
O que vale para as três está abaixo.

## Onde declarar campo

O gerador só enxerga `self.X = ...` dentro de um **método declarado**. Estas
três formas contam:

```lua
function M:Nome() end
function M.Nome() end
M.Nome = function() end
```

`M:OnInit(function(self) ... end)` **não** é uma delas — é uma chamada de
função, e campo atribuído ali dentro não entra no tipo, em silêncio.

O padrão que funciona é declarar num método e chamá-lo do `OnInit`:

```lua
function PlayerService:Setup()
	self.Players = {} :: { Player }
	self.Joined = self.Libs.Signal.new() :: SignalLib.Signal<Player>
end

PlayerService:OnInit(function(self)
	self:Setup()
end)
```

::: tip Dica:
Campo que não aparece no autocomplete quase sempre foi atribuído fora de um
método declarado.
:::

## Arquivo auxiliar

Arquivo `.luau` que não contém `.Service("`, `.Controller("` ou `.Component("`
é ignorado pelo gerador. Um `Template.luau` ao lado do módulo é seguro.
