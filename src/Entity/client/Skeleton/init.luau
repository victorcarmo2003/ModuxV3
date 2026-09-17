--!strict
local StarterPlayer = game:GetService("StarterPlayer")
local Modux = require(StarterPlayer.StarterPlayerScripts.client.Modux)
const Skeleton = Modux.Controller("Skeleton")

function Skeleton:ShotArrow() end

function Skeleton:KillPlayer() end

return Skeleton
