local modpath = core.get_modpath("ttd_util")

local ttd_util = {}

-- each submodule returns a function that accepts the namespace
ttd_util.spawn = dofile(modpath .. "/spawn.lua")(ttd_util)
ttd_util.jail  = dofile(modpath .. "/jail.lua")(ttd_util)
ttd_util.rules = dofile(modpath .. "/rules.lua")(ttd_util)

dofile(modpath .. "/chat.lua")(ttd_util)

core.log("action", "[TTD_UTIL] Mod loaded.")
