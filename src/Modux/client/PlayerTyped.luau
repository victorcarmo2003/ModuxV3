local PlayerTyped = {}
type SelfClass = { typeof(PlayerTyped) }

function PlayerTyped:SaveData(Amount: number) end

function PlayerTyped:ReloadData(Amount: number) end

function PlayerTyped:GetData() end

return PlayerTyped
