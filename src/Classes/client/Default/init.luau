--!strict
local StarterPlayer = game:GetService("StarterPlayer")
local Modux = require(StarterPlayer.StarterPlayerScripts.client.Modux)

const Default = Modux.Controller("Default")

function Default:Reload()
	self.Dependencies.Zombie:Heal(25)
end

function Default:Refresh() end

return Default
