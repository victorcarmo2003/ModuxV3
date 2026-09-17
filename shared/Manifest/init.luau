--!strict
-- GERADO por tools/modux_manifest.py a partir das folhas do projeto.
-- NAO EDITAR A MAO: a proxima geracao sobrescreve.
--
-- Cada entrada e o `self` ja enxertado: os membros da folha mais as
-- `Dependencies` resolvidas. As dependencias apontam para a folha CRUA,
-- nunca para a enxertada, senao o enxerto desce infinitamente.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SelfOf = require(ReplicatedStorage.shared.Types.SelfOf)
local Default = require(ReplicatedStorage.shared.Classes.Default.Type)
local Skeleton = require(ReplicatedStorage.shared.Entity.Skeleton.Type)
local Zombie = require(ReplicatedStorage.shared.Entity.Zombie.Type)

export type AllControllers = {
	Default: SelfOf.Build<Default.Public, { Zombie: Zombie.Public }>,
	Skeleton: SelfOf.Build<Skeleton.Public, {}>,
	Zombie: SelfOf.Build<Zombie.Public, { Skeleton: Skeleton.Public }>,
}

export type AllServices = {}

export type AllComponents = {}

return {}
