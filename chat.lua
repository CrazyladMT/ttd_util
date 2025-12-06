-- ttd_util/chat.lua
return function(ttd_util)
      local core, C = core, core.colorize
      local chat = { admins = {} }

      -- /jailchat command --------------------------------------------------
      core.register_chatcommand("jailchat", {
            params = "<join|leave>",
            description = "Join or leave the jail chat channel",
            privs = { server = true },
            func = function(name, param)
                  param = param:lower()
                  if param == "join" then
                        chat.admins[name] = "jail"
                        return true, "You have joined the jail chat channel."
                  elseif param == "leave" then
                        chat.admins[name] = nil
                        return true, "You have left the jail chat channel."
                  else
                        return false, "Usage: /jailchat <join|leave>"
                  end
            end
      })

      -- Helpers ------------------------------------------------------------
      local function format_jail_message(sender, message)
            return C("yellow", "[") .. C("#FF6721", "JAIL") .. C("yellow", "]") ..
                   " " .. C("yellow", "<") .. C("#FF6721", sender) ..
                   C("yellow", ">") .. " " .. C("yellow", message)
      end

      local function send_jail_message(sender, message)
            local jail = ttd_util.jail
            for _, player in ipairs(core.get_connected_players()) do
                  local pname = player:get_player_name()
                  local pmode = chat.admins[pname]
                  if jail.is_jailed(pname) or pmode == "jail" then
                        core.chat_send_player(
                              pname,
                              format_jail_message(sender, message)
                        )
                  end
            end
      end

      -- Chat interception --------------------------------------------------
      core.register_on_chat_message(function(name, message)
            local jail = ttd_util.jail
            local jailed = jail.is_jailed(name)
            local mode   = chat.admins[name]

            if jailed then
                  -- Jailed player: send only to jail channel
                  send_jail_message(name, message)
                  return true
            end

            if mode == "jail" then
                  -- Admin in jailchat mode: send only to jail channel
                  send_jail_message(name, message)
                  return true
            end

            -- Default: global chat (everyone not jailed sees it)
            for _, player in ipairs(core.get_connected_players()) do
                  local pname = player:get_player_name()
                  if not jail.is_jailed(pname) then
                        core.chat_send_player(
                              pname,
                              "<" .. name .. "> " .. message
                        )
                  end
            end
            return true
      end)
end