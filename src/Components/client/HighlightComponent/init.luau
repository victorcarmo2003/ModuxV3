--!strict
local StarterPlayer = game:GetService("StarterPlayer")
local Modux = require(StarterPlayer.StarterPlayerScripts.client.Modux)

const HighlightComponent = Modux.Component("HighlightComponent")

function HighlightComponent:Acender()
	self.Ligado = true
end

return HighlightComponent
