local storage = core.get_mod_storage()

local spawn = ttd_util.spawn

local jail = {}

-- Priv used for mechanical restrictions
core.register_privilege("jailed", {
      description = "Player is jailed and restricted",
      give_to_singleplayer = false,
})

---------------------------------------------------------------------
-- File backend in world directory
-- Format per line: kind|identifier|reason|admin|timestamp
---------------------------------------------------------------------
local worldpath = core.get_worldpath()
local jail_file = worldpath .. "/jailed.txt"

local function load_jail_entries()
      local entries = { name = {}, ip = {} }
      local f = io.open(jail_file, "r")
      if f then
            for line in f:lines() do
                  local kind, ident, reason, admin, ts =
                        line:match("^(%w+)|([^|]+)|([^|]*)|([^|]*)|?(%d*)$")
                  if kind and ident and (kind == "name" or kind == "ip") then
                        entries[kind][ident] = {
                              reason = reason ~= "" and reason or "No reason given",
                              admin  = admin ~= "" and admin or "<unknown>",
                              time   = tonumber(ts) or 0
                        }
                  end
            end
            f:close()
      end
      return entries
end

local function save_jail_entries(entries)
      local f = io.open(jail_file, "w")
      if not f then
            core.log("error", "[ttd_util] Could not open jailed.txt for writing")
            return
      end
      for kind, map in pairs(entries) do
            for ident, data in pairs(map) do
                  f:write(kind .. "|" .. ident .. "|" ..
                        (data.reason or "No reason given") .. "|" ..
                        (data.admin or "<unknown>") .. "|" ..
                        tostring(data.time or 0) .. "\n")
            end
      end
      f:close()
end

local function normalize_ip(ip)
      -- Treat IPv6 loopback as IPv4 loopback
      if ip == "::1" then return "127.0.0.1" end
      return ip
end


---------------------------------------------------------------------
-- Public API
---------------------------------------------------------------------
function jail.add(identifier, kind, reason, admin)
      local entries = load_jail_entries()
      entries[kind][identifier] = {
            reason = reason or "No reason given",
            admin  = admin or "<unknown>",
            time   = os.time()
      }
      save_jail_entries(entries)
end

function jail.remove(identifier, kind)
      local entries = load_jail_entries()
      entries[kind][identifier] = nil
      save_jail_entries(entries)
end

function jail.has_entry(identifier, kind)
      local entries = load_jail_entries()
      return entries[kind][identifier] ~= nil, entries[kind][identifier]
end

function jail.is_jailed(name)
      local jailed = jail.has_entry(name, "name")
      if jailed then return true end
      local info = core.get_player_information(name)
      if info and info.address then
            local ijailed = jail.has_entry(info.address, "ip")
            if ijailed then return true end
      end
      return false
end

---------------------------------------------------------------------
-- Jail position
---------------------------------------------------------------------
function jail.set_pos(pos)
      storage:set_string("jail_pos", core.pos_to_string(pos))
end

function jail.get_pos()
      local raw = storage:get_string("jail_pos")
      return raw ~= "" and core.string_to_pos(raw) or nil
end

---------------------------------------------------------------------
-- Jail / Unjail functions
---------------------------------------------------------------------
function jail.jail_player(player, reason, by_ip, admin)
      local name, target
      if type(player) == "string" then
            name   = player
            target = core.get_player_by_name(player)
      else
            name   = player:get_player_name()
            target = player
      end

      local jail_pos = jail.get_pos()
      if not target then
            return false, "Player not found."
      end
      if not jail_pos then
            return false, "Jail position not set."
      end

      -- Save current privs
      local privs = core.get_player_privs(name)
      storage:set_string("jail_privs_" .. name, core.serialize(privs))

      -- Restrict to only jailed + shout
      core.set_player_privs(name, {jailed = true, shout = true})

      -- Move to jail
      target:set_pos(jail_pos)

      -- Mark jailed
      if by_ip then
      	local info = core.get_player_information(name)
      	if info and info.address then
            	local ip = normalize_ip(info.address)
            	jail.add(ip, "ip", reason, admin)

            	-- NEW: also jail all other connected players on this IP
            	for _, player in ipairs(core.get_connected_players()) do
                  	local pname = player:get_player_name()
                  	if pname ~= name then
                        	local pinfo = core.get_player_information(pname)
                        	if pinfo and normalize_ip(pinfo.address) == ip then
                              	-- Save privs
                              	local privs = core.get_player_privs(pname)
                              	storage:set_string("jail_privs_" .. pname, core.serialize(privs))
                              	-- Restrict privs
                              	core.set_player_privs(pname, {jailed = true, shout = true})
                              	-- Move to jail
                              	local jail_pos = jail.get_pos()
                              	if jail_pos then
							player:set_pos(jail_pos)
						end
                              	-- Notify
                              	core.chat_send_player(pname,
							"You are jailed on this server.")
                        	end
                  	end
            	end
      	end
	else
      	jail.add(name, "name", reason, admin)
	end

      core.log("action",
            string.format('TTD_UTIL: %s was jailed by %s. Reason: "%s" (by_ip = %s)',
                  name,
                  admin or "<unknown>",
                  reason or "",
                  tostring(by_ip))
      )

      return true, name .. " has been jailed."
end


function jail.unjail_player(name, by_ip, admin)
      if by_ip then
            local info = core.get_player_information(name)
            if info and info.address then
                  local ip = normalize_ip(info.address)
                  jail.remove(ip, "ip")

                  local count = 0
                  for _, player in ipairs(core.get_connected_players()) do
                        local pname = player:get_player_name()
                        local pinfo = core.get_player_information(pname)
                        if pinfo and normalize_ip(pinfo.address) == ip then
                              -- Restore privs
                              local privs_str = storage:get_string("jail_privs_" .. pname)
                              if privs_str ~= "" then
                                    local privs = core.deserialize(privs_str)
                                    if privs then
                                          core.set_player_privs(pname, privs)
                                          storage:set_string("jail_privs_" .. pname, "")
                                    end
                              else
                                    local privs = core.get_player_privs(pname)
                                    privs.jailed = nil
                                    core.set_player_privs(pname, privs)
                              end

                              -- Teleport to spawn
                              local spawn = spawn.get_pos()
                              player:set_pos(spawn)

                              -- Show rules formspec
                              core.after(0.75, function()
                                    if core.get_player_by_name(player:get_player_name()) then
							player:get_meta():set_string("ttd_util_accepted_rules", "")
                                          ttd_util.rules.show_rules(player)
                                    end
                              end)

                              core.chat_send_player(pname, "You have been unjailed (IP release).")
                              count = count + 1
                        end
                  end

                  if count > 1 then
                        core.log("action", ("TTD_UTIL: Unjailed %d players on IP %s (by %s)"):format(count, ip, admin or "<unknown>"))
                  end
            end
      else
            -- Name-based unjail (single player)
            jail.remove(name, "name")
            local privs_str = storage:get_string("jail_privs_" .. name)
            if privs_str ~= "" then
                  local privs = core.deserialize(privs_str)
                  if privs then
                        core.set_player_privs(name, privs)
                        storage:set_string("jail_privs_" .. name, "")
                  end
            else
                  local privs = core.get_player_privs(name)
                  privs.jailed = nil
                  core.set_player_privs(name, privs)
            end

            local player = core.get_player_by_name(name)
            if player then
                  local spawn = spawn.get_pos()
                  player:set_pos(spawn)
                  core.after(0.75, function()
                        if player:is_player_connected() then
                              rules.show_rules(player)
                        end
                  end)
            end
      end

      core.log("action", ("TTD_UTIL: %s was unjailed by %s (by_ip=%s)"):format(name, admin or "<unknown>", tostring(by_ip)))
      return true, name .. " has been unjailed."
end


---------------------------------------------------------------------
-- Chat commands
---------------------------------------------------------------------
core.register_chatcommand("set_jail_pos", {
      description = "Set the jail position to your current location",
      privs = { server = true },
      func = function(name)
            local player = core.get_player_by_name(name)
            if player then
                  jail.set_pos(player:get_pos())
                  return true, "Jail position set."
            end
      end
})

core.register_chatcommand("jail", {
      params = "[$name] <player> <reason>",
      description = "Jail a player. Defaults to IP jail. Use $name to jail by name.",
      privs = { server = true },
      func = function(admin, param)
            if param == "" then
                  return false, "Usage: /jail [$name] <player> <reason>"
            end

            local by_ip = true
            local player, reason

            -- Check for $name flag
            local flag, p, r = param:match("^(%$name)%s+(%S+)%s*(.*)$")
            if flag then
                  by_ip = false
                  player = p
                  reason = r or ""
            else
                  player, reason = param:match("^(%S+)%s*(.*)$")
                  by_ip = true
            end

            if not player or player == "" then
                  return false, "Usage: /jail [$name] <player> <reason>"
            end

            return jail.jail_player(player, reason, by_ip, admin)
      end
})

core.register_chatcommand("unjail", {
      params = "[$name] <player>",
      description = "Release a player jailed by IP or name. Defaults to IP jail.",
      privs = { server = true },
      func = function(admin, param)
            if param == "" then
                  return false, "Usage: /unjail [$name] <player>"
            end

            local by_ip = true
            local player

            local flag, p = param:match("^(%$name)%s+(%S+)$")
            if flag then
                  by_ip = false
                  player = p
            else
                  player = param:match("^(%S+)$")
                  by_ip = true
            end

            if not player or player == "" then
                  return false, "Usage: /unjail [$name] <player>"
            end

            return jail.unjail_player(player, by_ip, admin)
      end
})


core.register_chatcommand("jail_status", {
	params = "<player>",
    	description = "Show jail status of a player",
    	privs = { server = true },
    	func = function(admin, param)
        	if param == "" then
            	return false, "Usage: /jail_status <player>"
        	end

        	local player = param
        	local entries = load_jail_entries()

        	-- First check name-based entry
        	local data = entries.name[player]
        	local kind = "name"

        	-- If not found, try IP-based entry via player info
        	if not data then
            	local info = core.get_player_information(player)
            	if info and info.address then
                		data = entries.ip[info.address]
                		kind = "ip"
            	end
        	end

        	if not data then
            	return true, "[JAIL] " .. player .. " is not jailed."
        	end

        	local date_str = os.date("!%d %B %Y - %H:%M UTC", data.time or os.time())
        	local msg = string.format(
            	'[JAIL] %s was jailed (by %s) by %s on %s. Reason: %s',
            	player,
            	kind,
            	data.admin or "<unknown>",
            	date_str,
            	data.reason or "No reason given"
        	)

        	return true, msg
    	end
})


core.register_on_joinplayer(function(player)
      local name = player:get_player_name()
      if jail.is_jailed(name) then
            local jail_pos = jail.get_pos()
            if jail_pos then player:set_pos(jail_pos) end
            core.set_player_privs(name, {jailed = true, shout = true})
            core.chat_send_player(name, "You are jailed on this server.")
      end
end)


return jail
