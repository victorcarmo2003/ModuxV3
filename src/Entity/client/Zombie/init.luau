--!strict
local StarterPlayer = game:GetService("StarterPlayer")
local Modux = require(StarterPlayer.StarterPlayerScripts.client.Modux)
const Zombie = Modux.Controller("Zombie")

function Zombie.Heal(self, Amount: number)
	self.Dependencies.Skeleton:KillPlayer()
	self.Dependencies.Skeleton:ShotArrow()
end

Zombie:OnInit(function(self)
	self:Heal(10)
end)

return Zombie
