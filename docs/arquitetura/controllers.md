# Controllers

Roda no **client**, um por jogo. Alcança outros Controllers e os Components do
client.

```lua
--!strict
local StarterPlayer = game:GetService("StarterPlayer")
local Modux = require(StarterPlayer.StarterPlayerScripts.client.Modux)

const Camera = Modux.Controller("Camera", { Require = { "Input" } })

function Camera:Shake(power: number)
	self.Dependencies.Input:Rumble(power)
end

Camera:OnInit(function(self)
	self.Shaking = false :: boolean
end)

return Camera
```

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

`ID` precisa ser um dos Controllers que existem no projeto. Um nome que não
existe não compila — o Manifest do client é a lista fechada.

## Onde o arquivo mora

Qualquer pasta sob `src/` que tenha `client` no caminho:

<FileTree :paths="[
  'src/Camera/client/Camera/init.luau',
  'src/Input/client/InputController/init.luau',
]" />

## O que ele alcança

| | |
|---|---|
| `self.Dependencies` | os Controllers declarados em `Require` |
| `self.Components` | todos os Components visíveis no client |
| `self.Libs` | o que estiver em `src/Libs` |

Um Controller que declara `Require` de um Service **interrompe a geração**. Se
o client precisa de algo que só o server tem, isso é rede — ver
[Dependências](/arquitetura/dependencias#lado-nao-atravessa).
