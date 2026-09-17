--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local Modux = require(ServerScriptService.server.Modux)

const ZoneComponent = Modux.Component("ZoneComponent", {})

function ZoneComponent:Entrou(jogador: Player)
	self.Nome = self.Instance.Name :: string
end

return ZoneComponent
