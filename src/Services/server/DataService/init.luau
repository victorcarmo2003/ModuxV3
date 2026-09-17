--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local Modux = require(ServerScriptService.server.Modux)

const DataService = Modux.Service("DataService", { Require = { "SaveService" } })

function DataService:Carregar(jogador: Player): boolean
	self.Carregados = 0
	return self.Dependencies.SaveService:Gravar(jogador.Name, 1)
end

return DataService
