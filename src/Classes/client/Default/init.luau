--!strict
local StarterPlayer = game:GetService("StarterPlayer")
local Modux = require(StarterPlayer.StarterPlayerScripts.client.Modux)
-- Require na forma de string simples; a forma de array tambem vale.
const Default = Modux.Controller("Default", { Require = "Zombie" })

function Default.Reload(self)
	self.Dependencies.Zombie:Heal(25)
end

function Default.Refresh(self) end

return Default
