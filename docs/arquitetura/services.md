# Services

Roda no **server**, um por jogo. Alcança outros Services e os Components do
server. A forma é idêntica à do Controller; o que muda é o lado.

```lua
--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local Modux = require(ServerScriptService.server.Modux)

const Data = Modux.Service("Data", { Require = { "Player" }, Priority = 800 })

function Data:Save(player: Player)
	self.Dependencies.Player:Touch(player)
end

Data:OnInit(function(self)
	self.Sessions = {} :: { [Player]: any }
end)

return Data
```

**Tipo**

```lua
function Modux.Service<ID, P>(
	id: ID & ServiceKey,
	props: (P | ServiceProps)?
): ServiceReturn<ID, P>

type ServiceProps = {
	Require: { ServiceKey },
	Priority: number?,
}
```

## Onde o arquivo mora

Qualquer pasta sob `src/` que tenha `server` no caminho:

<FileTree :paths="[
  'src/Profile/server/ProfileService/init.luau',
  'src/Profile/server/ProfileService/Template.luau # auxiliar',
]" />

## Priority importa mais aqui

No server é comum ter ordem de partida: quem abre a sessão de dados precisa
existir antes de quem lê dela. `Priority` maior roda `OnInit` e `OnStart`
primeiro.

```lua
const Net = Modux.Service("Net", { Priority = 1000 })
const Player = Modux.Service("Player", { Priority = 900 })
const Data = Modux.Service("Data", { Require = { "Player" }, Priority = 800 })
```

`Priority` **não** não interfere na dependência. Declarar `Require` 
garante que o módulo existe e será injetado normalmente; `Priority` 
só controla quem roda a fase antes.

Ver [Ciclo de vida](/arquitetura/ciclo-de-vida).
