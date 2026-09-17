--!strict
-- GERADO a partir das Type.luau. Nao editar a mao.
--
-- Cada entrada e o `self` ja enxertado: os metodos da Type.luau mais as
-- `Dependencies` resolvidas. E dela que o corpo do controller puxa o tipo
-- esperado, e por isso `self` fica tipado sem o usuario anotar nada.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SelfOf = require(ReplicatedStorage.shared.Types.SelfOf)
local Default = require(ReplicatedStorage.shared.Classes.Default.Type)
local Skeleton = require(ReplicatedStorage.shared.Entity.Skeleton.Type)
local Zombie = require(ReplicatedStorage.shared.Entity.Zombie.Type)

export type AllControllers = {
	Default: SelfOf.Build<Default.Public, { Zombie: Zombie.Public }>,
	Zombie: SelfOf.Build<Zombie.Public, { Skeleton: Skeleton.Public }>,
	Skeleton: SelfOf.Build<Skeleton.Public, {}>,
}
export type AllServices = {}
export type AllComponents = {}

return {}
