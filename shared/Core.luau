--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ComponentManager = require(ReplicatedStorage.shared.Modux.ComponentManager)
local Loader = require(ReplicatedStorage.shared.Modux.Loader)
local Registry = require(ReplicatedStorage.shared.Modux.Classes.Registry)

export type DebugLevel = Loader.DebugLevel

-- Profiling e DebugLevel sao coisas diferentes de proposito: o primeiro marca
-- as fases no MicroProfiler, que so serve com o MicroProfiler aberto; o
-- segundo escreve no output, que e o que se olha primeiro.
--
-- TickRate nao mora aqui. Cadencia e por callback, nao por jogo, entao ela e o
-- segundo argumento de OnTick.
export type Settings = {
	Profiling: boolean?,
	DebugLevel: DebugLevel?,
}

const Core = {}

function Core.Start(
	stores: { Loader.Store },
	templates: Registry.Templates,
	moduleScripts: { ModuleScript }?,
	settings: Settings?
)
	const s = (settings or {}) :: Settings
	const options: Loader.Options = {
		Profiling = s.Profiling == true,
		Debug = s.DebugLevel or "None",
	}

	-- Quatro passos porque duas ordens diferentes precisam valer ao mesmo
	-- tempo.
	--
	-- Construcao por tag e a ultima: ninguem pediu aquele componente naquele
	-- instante, entao ele nao pode subir antes do Controller ou Service de que
	-- depende ter startado.
	--
	-- Um Create explicito e o oposto. Ele diz construa agora, e o OnStart de um
	-- Controller e exatamente onde isso e chamado, entao o manager tem que
	-- estar utilizavel antes de o Loader disparar qualquer coisa.
	const byId = Loader.prepare(stores, moduleScripts, options)
	ComponentManager.prepare(templates, byId, options)
	Loader.run(stores, options)
	ComponentManager.start()
end

function Core.Stop()
	ComponentManager.stop()
	Loader.stop()
end

return Core
