# Módulos

Um módulo é uma pasta com `init.luau` que declara a sua espécie e devolve a si
mesmo.

## Modux.Controller()

Roda no client, um por jogo.

**Tipo**

```lua
function Modux.Controller<ID, P>(
	id: ID & ControllerKey,
	props: (P | ControllerProps)?
): ControllerReturn<ID, P>

type ControllerProps = {
	Require: { ControllerKey },
	Priority: number?,
}
```

**Exemplo**

```lua
--!strict
local StarterPlayer = game:GetService("StarterPlayer")
local Modux = require(StarterPlayer.StarterPlayerScripts.client.Modux)

const Camera = Modux.Controller("Camera", { Require = { "Input" } })

function Camera:Shake(power: number)
	self.Dependencies.Input:Rumble(power)
end

return Camera
```

## Modux.Service()

Roda no server, um por jogo. Mesma forma do Controller.

```lua
local ServerScriptService = game:GetService("ServerScriptService")
local Modux = require(ServerScriptService.server.Modux)

const Data = Modux.Service("Data", { Require = { "Player" }, Priority = 800 })
```

## Modux.Component()

Um por `Instance` tagueada, e roda dos dois lados. Ver
[Componentes](/guia/componentes).

```lua
type ComponentProps = {
	Require: { ControllerKey },   -- ou ServiceKey, no server
	Priority: number?,
	Tag: string?,
}
```

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

::: tip
Campo que não aparece no autocomplete quase sempre foi atribuído fora de um
método declarado.
:::

## Arquivo auxiliar

Arquivo `.luau` que não contém `.Service("`, `.Controller("` ou `.Component("`
é ignorado pelo gerador. Um `Template.luau` ao lado do módulo é seguro.
