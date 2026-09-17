--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Classes = require(ReplicatedStorage.shared.Modux.Classes)
const Skeleton = Classes.Controller("Skeleton")

function Skeleton:ShotArrow() end

function Skeleton:KillPlayer() end

return Skeleton
