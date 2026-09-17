--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local Modux = require(ServerScriptService.server.Modux)

const ZoneComponent = Modux.Component("ZoneComponent")

function ZoneComponent:Entrou(jogador: Player)
	-- `self.Instance` vem do enxerto, nao da folha
	self.Nome = self.Instance.Name :: string
	self.Dependencies.SaveService:Gravar(jogador.Name, 1)
end

return ZoneComponent
