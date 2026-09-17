--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Classes = require(ReplicatedStorage.shared.Modux.Classes)
-- Require na forma de string simples; a forma de array tambem vale.
const Default = Classes.Controller("Default", { Require = "Zombie" })

function Default.Reload(self)
	self.Dependencies.Zombie:Heal(25)
end

function Default.Refresh(self) end

return Default
