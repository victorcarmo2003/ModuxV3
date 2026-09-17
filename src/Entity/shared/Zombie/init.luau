--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Classes = require(ReplicatedStorage.shared.Modux.Classes)
const Zombie = Classes.Controller("Zombie")

function Zombie.Heal(self, Amount: number)
	self.Dependencies.Skeleton:KillPlayer()
	self.Dependencies.Skeleton:ShotArrow()
end

Zombie:OnInit(function(self)
	self:Heal(10)
end)

return Zombie
