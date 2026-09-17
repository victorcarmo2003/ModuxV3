--!strict
local StarterPlayer = game:GetService("StarterPlayer")
local Modux = require(StarterPlayer.StarterPlayerScripts.client.Modux)

const Zombie = Modux.Controller("Zombie", { Require = { "Skeleton" } })

function Zombie:Heal(Amount: number)
	self.Dependencies.Skeleton:ShotArrow()
end

return Zombie
