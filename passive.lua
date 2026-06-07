function blindexpander_init_passive_obj()
	blindexpander.Passives = {}

	blindexpander.Passive = SMODS.GameObject:extend({
		set = "Passive",
		obj_buffer = {},
		obj_table = blindexpander.Passives,
		required_params = {
			"key",
		},
		loc_vars = function(self, blind, passive) end,
		config = {},
		class_prefix = "psv",
		calculate = function(self, blind, passive, context) end,
		inject = function(self, i) end,
		remove = function(self) end,
		apply = function(self, from_disable) end,
		create_fake_card = function(self)
			return {
				config = self.config,
				disabled = false,
				key = self.key,
				fake_card = true,
			}
		end,
		generate_ui = function(self, info_queue, card, desc_nodes, specific_vars, full_UI_table)
			if not card then
				card = self:create_fake_card()
			end
			local target = {
				type = "descriptions",
				key = self.key,
				set = self.set,
				nodes = desc_nodes,
				AUT = full_UI_table,
				vars = specific_vars or {},
			}
			local res = {}
			if self.loc_vars and type(self.loc_vars) == "function" then
				res = self:loc_vars(nil, card) or {}
				target.vars = res.vars or target.vars
				target.key = res.key or target.key
				target.set = res.set or target.set
				target.scale = res.scale
				target.text_colour = res.text_colour
			end

			if desc_nodes == full_UI_table.main and not full_UI_table.name then
				full_UI_table.name = self.set == "Enhanced" and "temp_value"
					or localize({
						type = "name",
						set = target.set,
						key = res.name_key or target.key,
						nodes = full_UI_table.name,
						vars = res.name_vars or target.vars or {},
					})
			elseif desc_nodes ~= full_UI_table.main and not desc_nodes.name and self.set ~= "Enhanced" then
				desc_nodes.name = localize({ type = "name_text", key = res.name_key or target.key, set = target.set })
			end
			local safe_vars = target.vars or {}
			desc_nodes.name = string.gsub(desc_nodes.name, "(#%d+#)", function(matched)
				return tostring(safe_vars[tonumber(string.gsub(matched, "[#%s]", ""), 10)])
			end)
			if specific_vars and specific_vars.debuffed and not res.replace_debuff then
				target = {
					type = "other",
					key = "debuffed_" .. (specific_vars.playing_card and "playing_card" or "default"),
					nodes = desc_nodes,
					AUT = full_UI_table,
				}
			end
			if res.main_start then
				desc_nodes[#desc_nodes + 1] = res.main_start
			end

			localize(target)
			if res.main_end then
				desc_nodes[#desc_nodes + 1] = res.main_end
			end
			desc_nodes.background_colour = res.background_colour
		end,
	})
end

local loadapis_ref = loadAPIs
function loadAPIs()
    loadapis_ref()
    blindexpander_init_passive_obj()
end