--!strict
const Modux = require(ReplicatedStorage.shared.Modux)
const ClassTyped = Modux.Controller("ClassTyped", {
    Require = { "PlayerTyped", "ZombieTyped" },
    Priority = 1,
})
type Self = typeof(ClassTyped)

ClassTyped.TakeDamage = function(self: Self)
    --
end

function ClassTyped.Heal(self: Self)
    --
end

function ClassTyped:Die()
    --
end

ClassTyped:OnInit(function()
    ClassTyped:Heal(10)
end)

return ClassTyped