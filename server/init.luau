--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Runtime = require(ReplicatedStorage.shared.Modux.Classes)
local Registry = require(ReplicatedStorage.shared.Modux.Classes.Registry)
local Core = require(ReplicatedStorage.shared.Modux.Core)
local Types = require(script.Types)
local Modules = require(script.Modules)

export type Settings = Core.Settings

const Modux = {}

Modux._registry = {
	Service = {} :: Registry.Store,
}

Modux._templates = {
	Component = {} :: Registry.Templates,
}

Modux._settings = {} :: Settings
Modux._configured = false
Modux._started = false

function Modux.Service<ID, P>(
	id: ID & Types.ServiceKey,
	props: (P | Types.ServiceProps)?
): Types.ServiceReturn<ID, P>
	const p = ((props :: any) or {}) :: Types.ServiceProps
	return Registry.register("Service", Runtime.Service, Modux._registry.Service, (id :: any) :: string, p) :: any
end

function Modux.Component<ID, P>(
	id: ID & Types.ComponentKey,
	props: (P | Types.ComponentProps)?
): Types.ComponentReturn<ID, P>
	const p = ((props :: any) or {}) :: Types.ComponentProps
	return Registry.template(
			"Component",
			Runtime.Component,
			Modux._templates.Component,
			(id :: any) :: string,
			p
		) :: any
end

-- Configure so guarda; quem le e o Start. Chamar depois nao faria nada, e
-- nao fazer nada em silencio e o pior resultado possivel: voce nao entende
-- por que o DebugLevel nao ligou.
function Modux.Configure(settings: Settings)
	if Modux._started then
		error("[Modux] Configure must run before Start")
	end
	Modux._settings = settings
	Modux._configured = true
end

-- Passar as settings aqui torna a ordem impossivel de errar, em vez de
-- apenas detectavel: nao existe "antes do Start" para esquecer. Configure
-- continua valendo para quem prefere separar as duas coisas.
--
-- As duas juntas viram erro. Deixar o argumento vencer em silencio seria o
-- mesmo tipo de armadilha que a guarda do Configure acabou de fechar: duas
-- fontes de verdade e nenhuma pista de qual ganhou.
function Modux.Start(settings: Settings?)
	if settings ~= nil and Modux._configured then
		error("[Modux] settings came from both Configure and Start; use one of them")
	end
	Modux._started = true
	Core.Start(
		{ Modux._registry.Service },
		Modux._templates.Component,
		Modules,
		settings or Modux._settings
	)
end

function Modux.Stop()
	Core.Stop()
	Modux._started = false
	Modux._configured = false
end

return Modux
