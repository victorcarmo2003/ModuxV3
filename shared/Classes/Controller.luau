local Controller = {} :: ControllerType

function Controller:Import() end

function Controller:CreateComponent() end

--[[
OnInit is a callback register called first when the module is loaded
@params callback: (self) -> (), Frequency: number
```lua
function Example:OnTick(function()
    
end, 30)
```
]]
function Controller:OnTick() end

--[[
OnInit is a callback register called first when the module is loaded
@params callback: (self) -> ()
```lua
function Example:OnInit(function()
    print("Module inited!")
end)
```
]]
function Controller:OnInit() end

--[[
OnStart is a callback register called after Init
@params (self) -> ()
```lua
function Example:OnStart(function()
    print("Module started!")
end)
```
]]
function Controller:OnStart() end

function Controller.New() end

export type ControllerType = setmetatable<{}, Controller>
return Controller
