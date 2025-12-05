-- ttd_util/init.lua
-- Implements various utilities in Luanti, such as jail, rules, and spawn.

local modpath = core.get_modpath("ttd_util")

local ttd_util = {}

ttd_util.spawn = dofile(modpath .. "/spawn.lua")
ttd_util.jail  = dofile(modpath .. "/jail.lua")
ttd_util.rules = dofile(modpath .. "/rules.lua")

dofile(modpath .. "/chat.lua")

_G.ttd_util = ttd_util

core.log("action", "[TTD_UTIL] Mod loaded.")



