return function(ttd_util)
      local core, storage = core, core.get_mod_storage()
      local jail = {}

      -- Utilities ----------------------------------------------------------
      local function safe_show_rules(player)
            if ttd_util.rules and ttd_util.rules.show_rules then
                  ttd_util.rules.show_rules(player)
            end
      end


      local function normalize_ip(ip)
            return ip == "::1" and "127.0.0.1" or ip
      end


      local function save_privs(name)
            local privs = core.get_player_privs(name)
            local serialized_privs = core.serialize(privs)
            storage:set_string("jail_privs_" .. name, serialized_privs)
      end


      local function restore_privs(name)
            local key, privs_str = "jail_privs_" .. name,
                  storage:get_string("jail_privs_" .. name)

            if privs_str ~= "" then
                  local privs = core.deserialize(privs_str)
                  if privs then
                        core.set_player_privs(name, privs)
                  end
                  storage:set_string(key, "")
            else
                  local privs = core.get_player_privs(name)
                  privs.jailed = nil
                  core.set_player_privs(name, privs)
            end
      end


      local function move_to_spawn(player)
            if ttd_util.spawn and ttd_util.spawn.teleport_to_spawn then
                  return ttd_util.spawn.teleport_to_spawn(player)
            end
      end


      -- File backend -------------------------------------------------------
      local jail_file = core.get_worldpath() .. "/jailed.txt"

      local function load_jail_entries()
            local entries = { name = {}, ip = {} }
            local f       = io.open(jail_file, "r")
            if not f then
                  return entries
            end
            for line in f:lines() do
                  local kind, ident, reason, admin, ts = line:match(
                        "^(%w+)|([^|]+)|([^|]*)|([^|]*)|?(%d*)$")
                  if kind and ident and entries[kind] then
                        entries[kind][ident] = {
                              reason = reason ~= "" and reason or "No reason given",
                              admin  = admin ~= "" and admin or "<unknown>",
                              time   = tonumber(ts) or 0
                        }
                  end
            end
            f:close()
            return entries
      end


      local function save_jail_entries(entries)
            local f = io.open(jail_file, "w")
            if not f then
                  return core.log("error",
                        "[ttd_util] Could not open jailed.txt for writing")
            end
            for kind, map in pairs(entries) do
                  for ident, data in pairs(map) do
                        f:write(("%s|%s|%s|%s|%d\n"):format(
                              kind, ident,
                              data.reason or "No reason given",
                              data.admin or "<unknown>",
                              data.time or 0
                        ))
                  end
            end
            f:close()
      end


      -- Public API ---------------------------------------------------------
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
            if jail.has_entry(name, "name") then return true end
            local info = core.get_player_information(name)
            return info and info.address and jail.has_entry(normalize_ip(info.address), "ip")
      end


      -- Jail position ------------------------------------------------------
      function jail.set_pos(pos)
            storage:set_string("jail_pos", core.pos_to_string(pos))
      end


      function jail.get_pos()
            local raw = storage:get_string("jail_pos")
            return raw ~= "" and core.string_to_pos(raw) or nil
      end


      -- Jail / Unjail ------------------------------------------------------
      function jail.jail_player(player, reason, by_ip, admin)
            local name = type(player) == "string"
                  and player or player:get_player_name()

            local target = type(player) == "string"
                  and core.get_player_by_name(player) or player

            local jail_pos = jail.get_pos()

            if not target then
                  return false, "Player not found."
            end

            if not jail_pos then
                  return false, "Jail position not set."
            end

            save_privs(name)
            core.set_player_privs(name, {jailed = true, shout = true})
            target:set_pos(jail_pos)

            if by_ip then
                  local info = core.get_player_information(name)
                  if info and info.address then
                        local ip = normalize_ip(info.address)
                        jail.add(ip, "ip", reason, admin)
                        for _, p in ipairs(core.get_connected_players()) do
                              local pname, pinfo =
                                    p:get_player_name(),
                                    core.get_player_information(p:get_player_name())

                              if pname ~= name and pinfo and normalize_ip(pinfo.address) == ip then
                                    save_privs(pname)
                                    core.set_player_privs(pname, { jailed = true, shout = true })
                                    p:set_pos(jail_pos)
                                    core.chat_send_player(pname, "You are jailed on this server.")
                              end
                        end
                  end
            else
                  jail.add(name, "name", reason, admin)
            end

            core.log("action", ("TTD_UTIL: %s was jailed by %s. Reason: \"%s\" (by_ip=%s)")
                  :format(name, admin or "<unknown>", reason or "", tostring(by_ip)))
            return true, name .. " has been jailed."
      end


      function jail.unjail_player(name, by_ip, admin)
            if by_ip then
                  local info = core.get_player_information(name)
                  if info and info.address then
                        local ip, count = normalize_ip(info.address), 0
                        jail.remove(ip, "ip")
                        for _, p in ipairs(core.get_connected_players()) do
                              local pname, pinfo =
                                    p:get_player_name(),
                                    core.get_player_information(p:get_player_name())

                              if pinfo and normalize_ip(pinfo.address) == ip then
                                    restore_privs(pname)
                                    move_to_spawn(p)
                                    core.after(0.75, function()
                                          if core.get_player_by_name(pname) then
                                                p:get_meta():set_string("ttd_util_accepted_rules", "")
                                                ttd_util.rules.show_rules(p)
                                          end
                                    end)
                                    core.chat_send_player(pname, "You have been unjailed (IP release).")
                                    count = count + 1
                              end
                        end
                        if count > 1 then
                              core.log("action", ("TTD_UTIL: Unjailed %d players on IP %s (by %s)")
                                    :format(count, ip, admin or "<unknown>"))
                        end
                  end
            else
                  jail.remove(name, "name")
                  restore_privs(name)
                  local player = core.get_player_by_name(name)
                  if player then
                        move_to_spawn(player)
                        core.after(0.75, function()
                              if core.get_player_by_name(name) then
                                    safe_show_rules(player)
                              end
                        end)
                  end
            end
            core.log("action", ("TTD_UTIL: %s was unjailed by %s (by_ip=%s)")
                  :format(name, admin or "<unknown>", tostring(by_ip)))
            return true, name .. " has been unjailed."
      end


      -- ensure jailed players are restricted on join
      core.register_on_joinplayer(function(player)
            local name = player:get_player_name()
            if jail.is_jailed(name) then
                  local jail_pos = jail.get_pos()
                  if jail_pos then player:set_pos(jail_pos) end
                  core.set_player_privs(name, {jailed = true, shout = true})
                  core.chat_send_player(name, "You are jailed on this server.")
            end
      end)

      -- set jail position to your current location
      core.register_chatcommand("set_jail_pos", {
            description = "Set the jail position to your current location",
            privs = { server = true },
            func = function(name)
                  local player = core.get_player_by_name(name)
                  if player then
                        jail.set_pos(player:get_pos())
                        return true, "Jail position set."
                  else
                        return false, "Player not found."
                  end
            end
      })

      -- jail a player (IP by default, or by name with $name)
      core.register_chatcommand("jail", {
            params = "[$name] <player> <reason>",
            description = "Jail a player. Defaults to IP jail. Use $name to jail by name.",
            privs = { server = true },
            func = function(admin, param)
                  if param == "" then
                        return false, "Usage: /jail [$name] <player> <reason>"
                  end

                  local by_ip, player, reason = true, nil, nil

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

      -- unjails a player, whether by name or IP
      core.register_chatcommand("unjail", {
            params = "<player>",
            description = "Release a player jailed by IP or name",
            privs = { server = true },
            func = function(admin, param)
                  if param == "" then
                        return false, "Usage: /unjail <player>"
                  end

                  local player = param
                  local entries = load_jail_entries()

                  -- Check name entry first
                  local data = entries.name[player]
                  if data then
                        return jail.unjail_player(player, false, admin)
                  end

                  -- If no name entry, check IP entry
                  local info = core.get_player_information(player)
                  if info and info.address then
                        local ip = normalize_ip(info.address)
                        if entries.ip[ip] then
                              return jail.unjail_player(player, true, admin)
                        end
                  end

                  return false, player .. " is not jailed."
            end
      })

      -- Show jail status of a player
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

                  local data = entries.name[player]
                  local kind = "name"

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
                        "[JAIL] %s was jailed (by %s) by %s on %s. Reason: %s",
                        player,
                        kind,
                        data.admin or "<unknown>",
                        date_str,
                        data.reason or "No reason given"
                  )

                  return true, msg
            end
      })

      return jail
end