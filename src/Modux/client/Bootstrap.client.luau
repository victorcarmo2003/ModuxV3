--!strict
local StarterPlayer = game:GetService("StarterPlayer")
local Modux = require(StarterPlayer.StarterPlayerScripts.client.Modux)
Modux.Configure({ DebugLevel = "High", Profiling = true })
Modux.Start()
