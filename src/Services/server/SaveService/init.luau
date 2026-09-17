--!strict
local ServerScriptService = game:GetService("ServerScriptService")
local Modux = require(ServerScriptService.server.Modux)

const SaveService = Modux.Service("SaveService")

function SaveService:Gravar(chave: string, valor: number): boolean
	self.Pendentes = 0
	return true
end

return SaveService
