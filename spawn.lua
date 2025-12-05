local storage = core.get_mod_storage()
local spawn = {}


function spawn.set_pos(pos)
    assert(pos and pos.x and pos.y and pos.z, "Invalid spawn position")
    storage:set_string("spawn_pos", core.pos_to_string(pos))
end


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


function spawn.teleport_to_spawn(name)
    local player = core.get_player_by_name(name)

    if not player then
        return false
    end

    local pos = spawn.get_pos()

    if not pos then
        core.chat_send_player(name, "Spawn point not set.")
        return false
    else
        -- increase Y level because it looks cool
        pos.y = pos.y + 1.5
    end

    player:set_pos(pos)
    core.chat_send_player(name, "Teleported to spawn!")
    return true
end


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


core.register_on_newplayer(function(player)
    local pos = spawn.get_pos()
    if pos then
        player:set_pos(pos)
    else
        core.log("warning", "[ttd_util.spawn] No spawn point set; new player spawned at engine default.")
    end
end)


return spawn
