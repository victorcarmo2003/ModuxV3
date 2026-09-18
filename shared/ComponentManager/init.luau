--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Loader = require(ReplicatedStorage.shared.Modux.Loader)
local Registry = require(ReplicatedStorage.shared.Modux.Classes.Registry)

export type Options = Loader.Options

const ComponentManager = {}

-- Runs after Loader.start has returned, which is what guarantees a component's
-- OnInit never fires before the Controller or Service it depends on.
--
-- Does not build anything yet: binding tags to objects is the next step. Until
-- it lands, a declared Component registers its template and stays inert.
function ComponentManager.start(
	templates: Registry.Templates,
	byId: { [string]: Registry.Entry },
	options: Options
) end

function ComponentManager.stop() end

return ComponentManager
