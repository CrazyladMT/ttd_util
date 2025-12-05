-- ttd_util/init.lua
-- Implements various utilities in Luanti, such as jail, rules, and spawn.

ttd_util = {}

local modpath = core.get_modpath("ttd_util")

ttd_util.spawn = dofile(modpath .. "/spawn.lua")
ttd_util.jail  = dofile(modpath .. "/jail.lua")
ttd_util.rules = dofile(modpath .. "/rules.lua")

dofile(modpath .. "/chat.lua")

core.log("action", "[TTD_UTIL] Mod loaded.")



