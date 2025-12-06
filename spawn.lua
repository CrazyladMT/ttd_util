return function(ttd_util)
      local core, storage = core, core.get_mod_storage()
      local spawn = {}

      -- Set spawn position -------------------------------------------------
      function spawn.set_pos(pos)
            assert(pos and pos.x and pos.y and pos.z, "Invalid spawn position")
            storage:set_string("spawn_pos", core.pos_to_string(pos))
      end

      -- Get spawn position -------------------------------------------------
      function spawn.get_pos()
            local raw = storage:get_string("spawn_pos")
            if raw ~= "" then
                  return core.string_to_pos(raw)
            end
            -- fallback: use static_spawnpoint from minetest.conf if set
            local conf = core.setting_get_pos("static_spawnpoint")
            if conf then
                  return conf
            end
            return nil
      end

      -- Teleport player to spawn -------------------------------------------
      function spawn.teleport_to_spawn(name_or_player)
            local player = type(name_or_player) == "string"
                  and core.get_player_by_name(name_or_player)
                  or name_or_player

            if not player then
                  return false
            end

            local pos = spawn.get_pos()
            if not pos then
                  -- no spawn set: fallback to respawn
                  player:respawn()
                  core.chat_send_player(player:get_player_name(),
                        "Spawn point not set. Respawning at engine default.")
                  return false
            else
                  -- increase Y level because it looks cool 
                  -- (probably too arbitrary though)
                  pos.y = pos.y + 1.5
                  player:set_pos(pos)
                  core.chat_send_player(player:get_player_name(),
                        "Teleported to spawn!")
                  return true
            end
      end

      -- chat commands ------------------------------------------------------
      core.register_chatcommand("spawn", {
            description = "Teleport to spawn point.",
            func = spawn.teleport_to_spawn,
      })

      core.register_chatcommand("set_spawn", {
            description = "Set the spawn point to your current position.",
            privs = { server = true },
            func = function(name)
                  local player = core.get_player_by_name(name)
                  if not player then
                        return false
                  end
                  spawn.set_pos(player:get_pos())
                  return true, "Spawn point set."
            end
      })

      -- new player spawn handling ------------------------------------------
      core.register_on_newplayer(function(player)
            spawn.teleport_to_spawn(player)
      end)

      return spawn
end


