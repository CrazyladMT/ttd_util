local storage = core.get_mod_storage()
local rules = {}

local default_rules = [[
<center>┏━━━━━━━━━━━━━━━━━━━━━━━━━━━┓</center>
<center>┃                 <style size=18><b>Welcome to the</b></style>                 ┃</center>
<center>┃      <style size=18><b><style color=#ca0000>The Technical Difficulties!</style></b></style>      ┃</center>
<center>┗━━━━━━━━━━━━━━━━━━━━━━━━━━━┛</center>

rules...
]]

local rules_text = storage:get_string("ttd_util_rules_text")

if rules_text == "" then
      rules_text = default_rules
      storage:set_string("ttd_util_rules_text", rules_text)
end

local no_interact_msg = "You must agree to the rules to gain the privilege"
      .. " 'interact'. Use /rules when you reconsider."

local interact_msg = "Thank you for agreeing to the rules. You now have the privilege 'interact'."

local function set_rules_text(new_text)
      rules_text = new_text
      storage:set_string("ttd_util_rules_text", rules_text)
end


local pad      = 0.325
local form_w   = 9
local form_h   = 11
local button_h = 0.85

local txt_area_pad = 0.15

local content_w = form_w - pad * 2
local content_h = form_h - (button_h + pad * 3)

local function get_rules_formspec(player)
      local meta = player:get_meta()
      local accepted = meta:get_string("ttd_util_accepted_rules") == "true"

      local button_w  = (form_w - (pad * 3)) / 2

      local fs = {
            "formspec_version[6]",
            "size[" .. form_w .. "," .. form_h .. "]",

            "box[" .. pad .. "," .. pad .. ";"
                  .. content_w .. "," .. content_h .. ";#000000]",

            "container[" .. pad + txt_area_pad .. "," .. pad + txt_area_pad .. "]",

            "hypertext[0,0;"
                  .. form_w - (pad + txt_area_pad) * 2 .. "," .. content_h - txt_area_pad * 2
                  .. ";ttd_util_rules_ht;"
                  .. core.formspec_escape(rules_text) .. "]",
            "container_end[]",
      }

      local button_y = form_h - (button_h + pad)

      if accepted then
            -- single close button
            local close_x = (form_w - button_w) / 2
            fs[#fs + 1] = "button_exit[" .. close_x .. "," .. button_y .. ";"
                  .. button_w .. "," .. button_h
                  .. ";ttd_util_rules_close;Close]"
      else
            -- disagree button (red)
            fs[#fs + 1] = "style[ttd_util_rules_disagree;bgcolor=red]"
            fs[#fs + 1] = "button[" .. pad .. "," .. button_y .. ";"
                  .. button_w .. "," .. button_h
                  .. ";ttd_util_rules_disagree;I do not agree!]"

            -- agree button (green)
            fs[#fs + 1] = "style[ttd_util_rules_agree;bgcolor=green]"
            fs[#fs + 1] = "button[" .. (pad * 2 + button_w) .. "," .. button_y
                  .. ";" .. button_w .. "," .. button_h
                  .. ";ttd_util_rules_agree;I agree]"
      end

      return table.concat(fs)
end


local function get_setrules_formspec(current_text)
      local width     = (content_w * 2) + (pad * 3)
      local content_h = form_h - (button_h + pad * 3)

      local button_w  = 3

      local fs = {
            "formspec_version[6]",
            "size[" .. width .. "," .. form_h .. "]",
            "no_prepend[]",
            "bgcolor[#00000000]",
            "background9[0,0;" .. width .. "," .. form_h .. ";gui_formbg.png;true;10]",

            "container[" .. pad .. "," .. button_h + pad * 2 .. "]",

            -- Left side: textarea editor
            "textarea[0,0;"
                  .. content_w .. "," .. content_h
                  .. ";ttd_util_edit_rules_input;;"
                  .. core.formspec_escape(current_text) .. "]",

            -- Right side: black box background
            "box[" .. content_w + pad .. ",0;"
                  .. content_w .. "," .. content_h .. ";#000000]",

            "container[" .. content_w + pad + txt_area_pad .. "," .. txt_area_pad .. "]",
            "hypertext[0,0;"
                  .. content_w - (txt_area_pad * 2) .. "," .. content_h - (txt_area_pad * 2)
                  .. ";ttd_util_edit_rules_preview;"
                  .. core.formspec_escape(current_text) .. "]",
            "container_end[]",
            "container_end[]",

            "image_button[" .. width - pad - button_w - pad - button_h .. "," .. pad
                  .. ";" .. button_h .. "," .. button_h .. ";refresh.png;refresh_rules;]",

            "style[save_rules;bgcolor=green]",

            "button[" .. width - pad - button_w .. "," .. pad .. ";" .. button_w
                  .. "," .. button_h .. ";save_rules;Save]",

            "button[" .. pad .. "," .. pad .. ";" .. button_w
                  .. "," .. button_h .. ";cancel_rules;Cancel]",
      }

      return table.concat(fs)
end


function rules.show_rules(player)
      core.show_formspec(player:get_player_name(),
            "ttd_util_rules:main",
            get_rules_formspec(player)
      )
end

core.register_on_newplayer(function(player)
      local name  = player:get_player_name()
      local meta  = player:get_meta()
      local privs = core.get_player_privs(name)

      privs.interact = nil
      core.set_player_privs(name, privs)

      if meta:get_string("ttd_util_accepted_rules") ~= "true" then
            core.after(0.75, function()
                  rules.show_rules(player)
            end)
      end
end)

core.register_on_joinplayer(function(player)
      local name = player:get_player_name()
      local meta = player:get_meta()
      if meta:get_string("ttd_util_accepted_rules") ~= "true" then
            local privs = core.get_player_privs(name)
            privs.interact = nil
            core.set_player_privs(name, privs)
            core.after(0.75, function()
                  rules.show_rules(player)
            end)
      end
end)

core.register_chatcommand("rules", {
      description = "Show the server rules",
      func = function(name)
            local player = core.get_player_by_name(name)
            if player then
                  rules.show_rules(player)
            end
      end
})

core.register_chatcommand("set_rules", {
      description = "Edit the server rules (admin only)",
      privs = { server = true },
      func = function(name)
            core.show_formspec(name, "ttd_util_rules:set",
                  get_setrules_formspec(rules_text))
      end
})


core.register_on_player_receive_fields(function(player, formname, fields)
      local name = player:get_player_name()
      local meta = player:get_meta()

      if formname == "ttd_util_rules:main" then
            -- Handle closing with ESC or clicking outside
            if fields.quit then
                  if meta:get_string("ttd_util_accepted_rules") ~= "true" then
                        core.chat_send_player(name, no_interact_msg)
                  end
                  return
            end

            if fields.ttd_util_rules_agree then
                  if meta:get_string("ttd_util_accepted_rules") ~= "true" then
                        meta:set_string("ttd_util_accepted_rules", "true")
                        local privs = core.get_player_privs(name)
                        privs.interact = true
                        core.set_player_privs(name, privs)
                        core.chat_send_player(name, interact_msg)
                        core.close_formspec(name, "ttd_util_rules:main")
                  else
                        core.show_formspec(name, "ttd_util_rules:main", get_rules_formspec(player))
                  end

            elseif fields.ttd_util_rules_disagree then
                  if meta:get_string("ttd_util_accepted_rules") == "true" then
                        core.show_formspec(name, "ttd_util_rules:main", get_rules_formspec(player))
                  else
                        core.close_formspec(name, "ttd_util_rules:main")
                        core.chat_send_player(name, no_interact_msg)
                  end
            end
            return
      end

      if formname == "ttd_util_rules:set" then
            -- refresh button: re‑open the formspec wih updated preview
            if fields.refresh_rules and fields.ttd_util_edit_rules_input then
                  core.show_formspec(name, "ttd_util_rules:set",
                        get_setrules_formspec(fields.rules_input))
                  return
            end

            -- save button
            if fields.save_rules and fields.ttd_util_edit_rules_input then
                  set_rules_text(fields.rules_input)
                  core.chat_send_player(name, "Rules updated successfully.")
                  core.close_formspec(name, "ttd_util_rules:set")
                  return
            end

            -- cancel button
            if fields.cancel_rules then
                  core.chat_send_player(name, "Rules edit cancelled.")
                  core.close_formspec(name, "ttd_util_rules:set")
                  return
            end
      end
end)

return rules