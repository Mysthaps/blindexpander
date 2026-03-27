--- G.GAME.blind.original_blind (string): Key of the first Blind if Blinds are summoned
--- G.GAME.current_round.phases_beaten (number): Amount of times Blind was beaten if Blind has phases
---
--- NOTES
---
--- Localization for Passives are taken from G.localization.descriptions.Passive
--- Passive key should be "psv_[mod prefix]_[key]" for consistency
--- SMODS.Blind.defeat(self) is called on the current blind if it has a summon
--- If passive description is too long, changing how it is formatted instead of changing UIBox width is preferred

to_big = to_big or function(x)
	return x
end
local BLINDEXPANDER_VERSION = 200000

local init_blind = false
local from_swap = false
local function startup()
	if blindexpander.started_up then
		return
	end
	blindexpander.started_up = true

	-- copied from cryptid's cry_deep_copy
	function lobc_deep_copy(obj, seen)
		if type(obj) ~= "table" then
			return obj
		end
		if seen and seen[obj] then
			return seen[obj]
		end
		local s = seen or {}
		local res = setmetatable({}, getmetatable(obj))
		s[obj] = res
		for k, v in pairs(obj) do
			res[lobc_deep_copy(k, s)] = lobc_deep_copy(v, s)
		end
		return res
	end

	local set_blindref = Blind.set_blind
	function Blind.set_blind(self, blind, reset, silent)
		if not reset and not blind then
			if #get_alive_blinds(true) == 0 then
				G.GAME.blind_tray = nil
				G.GAME.blind_id = nil
			end
		end
		if not reset then
			if blind and not G.GAME.blind_tray then
				init_blind = true
				G.GAME.blind_tray = {}
				G.GAME.blind_id = 1
				G.GAME.total_dollars = 0
			end
			if not reset and blind and not self.original_blind then
				self.blind_id = G.GAME.blind_id
				self.scored_chips = 0
				G.GAME.blind_id = G.GAME.blind_id + 1
			end
			self.passives = blind and lobc_deep_copy(blind.passives)
			if self.passives then
				self.passives_data = {}
				for _, key in ipairs(self.passives) do
					local obj = blindexpander.Passives[key]
					local cfg = {}
					if obj then
						cfg = copy_table(obj.config)
					end
					local data = {
						disabled = false,
						key = key,
						config = cfg,
					}
					if blind then
						data.blind_obj = blind
					end
					self.passives_data[#self.passives_data + 1] = data
					if obj then
						obj:apply(self, data, false)
					end
				end
				self.children.alert = UIBox({
					definition = create_UIBox_card_alert(),
					config = {
						align = "tri",
						offset = {
							x = 0.1,
							y = 0,
						},
						parent = self,
					},
				})
			else
				self.children.alert = nil
			end
		end
		set_blindref(self, blind, reset, silent)
		init_blind = false
	end

	local modifies_draw_ref = SMODS.blind_modifies_draw
	function SMODS.blind_modifies_draw(key)
		local res = modifies_draw_ref(key)
		if G.GAME.blind and G.GAME.blind.passives_data then
			for _, data in ipairs(G.GAME.blind.passives_data) do
				if blindexpander.Passives[data.key] and blindexpander.Passives[data.key].modifies_draw then
					res = true
					break
				end
			end
		end
		return res
	end

	if Spectrallib then
		local set_copied_blinds_ref = Spectrallib.set_copied_blinds
		function Spectrallib.set_copied_blinds(blinds, self, silent, reset)
			set_copied_blinds_ref(blinds, self, silent, reset)
			for _, k in pairs(blinds) do
				local s = G.P_BLINDS[k]
				if s.passives then
					G.GAME.blind.passives_data = G.GAME.blind.passives_data or {}
					for _, key in ipairs(s.passives) do
						local obj = blindexpander.Passives[key]
						local cfg = {}
						if obj then
							cfg = copy_table(obj.config)
						end
						local data = {
							disabled = false,
							key = key,
							config = cfg,
						}
						data.blind_obj = s
						if not find_passive(key) then
							G.GAME.blind.passives_data[#G.GAME.blind.passives_data + 1] = data
							if obj then
								obj:apply(self, data, false)
							end
						end
					end
					if not self.children.alert then
						self.children.alert = UIBox({
							definition = create_UIBox_card_alert(),
							config = {
								align = "tri",
								offset = {
									x = 0.1,
									y = 0,
								},
								parent = self,
							},
						})
					end
				end
			end
		end
	end

	local blind_saveref = Blind.save
	function Blind.save(self)
		local blindTable = blind_saveref(self)
		blindTable.passives = self.passives
		blindTable.passives_data = self.passives_data
		blindTable.original_blind = self.original_blind
		blindTable.scored_chips = self.scored_chips
		blindTable.blind_id = self.blind_id
		blindTable.minion = self.minion
		return blindTable
	end

	local blind_loadref = Blind.load
	function Blind.load(self, blindTable)
		if not from_swap then
			G.GAME.chips = blindTable.scored_chips
		else
			G.E_MANAGER:add_event(Event({
				trigger = "ease",
				blocking = false,
				ref_table = G.GAME,
				ref_value = "chips",
				ease_to = blindTable.scored_chips,
				delay = 0.3,
				func = function(t)
					return math.floor(t)
				end,
			}))
		end
		self.blind_id = blindTable.blind_id
		self.minion = blindTable.minion
		self.passives = blindTable.passives
		self.passives_data = blindTable.passives_data
		self.original_blind = blindTable.original_blind
		blind_loadref(self, blindTable)
		if self.passives_data then
			for _, passive in ipairs(self.passives_data) do
				passive.blind_data = self.config.blind
			end
		end
	end

	function Blind:hot_load(blindTable)
		self.in_blind = blindTable.in_blind
		self.effect = blindTable.effect
		self.config.blind = G.P_BLINDS[blindTable.config_blind] or {}
		self.name = blindTable.name
		self.dollars = blindTable.dollars
		self.debuff = blindTable.debuff
		self.pos = blindTable.pos
		self.mult = blindTable.mult
		self.disabled = blindTable.disabled
		self.discards_sub = blindTable.discards_sub
		self.hands_sub = blindTable.hands_sub
		self.boss = blindTable.boss
		self.chips = blindTable.chips
		self.chip_text = blindTable.chip_text
		self.hands = blindTable.hands
		self.only_hand = blindTable.only_hand
		self.triggered = blindTable.triggered
		self.passives = blindTable.passives
		self.passives_data = blindTable.passives_data
		self.original_blind = blindTable.original_blind
		self.blind_id = blindTable.blind_id
		self.minion = blindTable.minion
	end

	function info_from_passive(passive_data)
		local obj = blindexpander.Passives[passive_data.key]
		local disabled = (G.GAME.blind or {}).disabled or passive_data.disabled
		local loc_res = {}
		if obj then
			loc_res = obj:loc_vars(G.GAME.blind, passive_data) or {}
		end
		local no_name = loc_res.no_name
		local loc_key = loc_res.key or passive_data.key
		local loc_set = loc_res.set or "Passive"
		local desc_nodes = {}
		localize({ type = "descriptions", key = loc_key, set = loc_set, nodes = desc_nodes, vars = loc_res.vars or {} })
		local desc = {}
		for _, v in ipairs(desc_nodes) do
			desc[#desc + 1] = { n = G.UIT.R, config = { align = "cl" }, nodes = v }
		end
		local name_nodes =
			localize({ type = "name", key = loc_key, set = loc_set, name_nodes = {}, vars = loc_res.vars or {} })
		if disabled and not obj.fixed then
			name_nodes[1].nodes[1].nodes[1].config.strikethrough = G.C.RED
		end
		return {
			(not no_name) and {
				n = G.UIT.R,
				config = { align = "cl", padding = 0.05 },
				nodes = name_nodes,
			} or nil,
			{
				n = G.UIT.R,
				config = {
					align = "cl",
					--minw = width,
					--minh = 0.4,
					r = 0.1,
					padding = 0.05,
					emboss = 0.05,
					colour = desc_nodes.background_colour or G.C.WHITE,
				},
				nodes = { { n = G.UIT.R, config = { align = "cm", padding = 0.03 }, nodes = desc } },
			},
		}
	end

	function Blind:disable_passive(key, no_update, silent)
		if find_passive(key) then
			local obj = blindexpander.Passives[key]
			if not (obj or {}).fixed then
				for _, data in ipairs(self.passives_data) do
					if data.key == key and not data.disabled then
						data.disabled = true
						if obj then
							obj:remove(self, data, true)
						end
						if not no_update then
							G.E_MANAGER:add_event(Event({
								trigger = "immediate",
								func = function()
									if self.boss and G.GAME.chips - G.GAME.blind.chips >= 0 then
										G.STATE = G.STATES.NEW_ROUND
										G.STATE_COMPLETE = false
									end
									return true
								end,
							}))
							for _, v in ipairs(G.playing_cards) do
								self:debuff_card(v)
							end
							for _, v in ipairs(G.jokers.cards) do
								self:debuff_card(v)
							end
						end
						if not self.children.alert then
							self.children.alert = UIBox({
								definition = create_UIBox_card_alert(),
								config = {
									align = "tri",
									offset = {
										x = 0.1,
										y = 0,
									},
									parent = self,
								},
							})
						end
						if not silent then
							self:wiggle()
						end
						break
					end
				end
			end
		end
	end

	function Blind:enable_passive(key, no_update, silent)
		if find_passive(key) then
			for _, data in ipairs(self.passives_data) do
				if data.key == key and data.disabled then
					data.disabled = false
					local obj = blindexpander.Passives[key]
					if obj and not self.disabled then
						obj:apply(self, data, true)
					end
					if not no_update then
						G.E_MANAGER:add_event(Event({
							trigger = "immediate",
							func = function()
								if self.boss and G.GAME.chips - G.GAME.blind.chips >= 0 then
									G.STATE = G.STATES.NEW_ROUND
									G.STATE_COMPLETE = false
								end
								return true
							end,
						}))
						for _, v in ipairs(G.playing_cards) do
							self:debuff_card(v)
						end
						for _, v in ipairs(G.jokers.cards) do
							self:debuff_card(v)
						end
					end
					if not self.children.alert and not self.disabled then
						self.children.alert = UIBox({
							definition = create_UIBox_card_alert(),
							config = {
								align = "tri",
								offset = {
									x = 0.1,
									y = 0,
								},
								parent = self,
							},
						})
					end
					if not silent then
						self:wiggle()
					end
					break
				end
			end
		end
	end

	local disable_blind_ref = Blind.disable
	function Blind:disable()
		disable_blind_ref(self)
		if self.disabled then
			for _, passive in ipairs(self.passives_data) do
				if not passive.disabled then
					self:disable_passive(passive.key, nil, true)
				end
			end
		end
	end

	local defeat_blind_hook = Blind.defeat
	function Blind:defeat(silent)
		defeat_blind_hook(self, silent)
		self.passives_data = {}
		G.GAME.blind.original_blind = nil
	end

	function Blind:add_passive(key, no_update, silent)
		if not find_passive(key) then
			local obj = blindexpander.Passives[key]
			local cfg = {}
			if obj then
				cfg = copy_table(obj.config)
			end
			local data = {
				disabled = false,
				key = key,
				config = cfg,
				blind_data = self.config.blind,
			}
			if obj and not self.disabled then
				obj:apply(self, data, false)
			end
			self.passives_data = self.passives_data or {}
			self.passives_data[#self.passives_data + 1] = data
			if not no_update then
				G.E_MANAGER:add_event(Event({
					trigger = "immediate",
					func = function()
						if self.boss and G.GAME.chips - G.GAME.blind.chips >= 0 then
							G.STATE = G.STATES.NEW_ROUND
							G.STATE_COMPLETE = false
						end
						return true
					end,
				}))
				for _, v in ipairs(G.playing_cards) do
					self:debuff_card(v)
				end
				for _, v in ipairs(G.jokers.cards) do
					self:debuff_card(v)
				end
			end
			if not self.children.alert then
				self.children.alert = UIBox({
					definition = create_UIBox_card_alert(),
					config = {
						align = "tri",
						offset = {
							x = 0.1,
							y = 0,
						},
						parent = self,
					},
				})
			end
			if not silent then
				self:wiggle()
			end
		end
	end

	function Blind:remove_passive(key, no_update, silent)
		if find_passive(key) then
			local obj = blindexpander.Passives[key]
			if not (obj or {}).fixed then
				for i, data in ipairs(self.passives_data) do
					if data.key == key then
						if obj then
							obj:remove(self, data, false)
						end
						table.remove(self.passives_data, i)
						if not no_update then
							G.E_MANAGER:add_event(Event({
								trigger = "immediate",
								func = function()
									if self.boss and G.GAME.chips - G.GAME.blind.chips >= 0 then
										G.STATE = G.STATES.NEW_ROUND
										G.STATE_COMPLETE = false
									end
									return true
								end,
							}))
							for _, v in ipairs(G.playing_cards) do
								self:debuff_card(v)
							end
							for _, v in ipairs(G.jokers.cards) do
								self:debuff_card(v)
							end
						end
						if #self.passives_data ~= 0 and not self.children.alert then
							self.children.alert = UIBox({
								definition = create_UIBox_card_alert(),
								config = {
									align = "tri",
									offset = {
										x = 0.1,
										y = 0,
									},
									parent = self,
								},
							})
						end
						if not silent then
							self:wiggle()
						end
						break
					end
				end
			end
		end
	end

	function get_actual_original_blind(key)
		local obj = G.P_BLINDS[key]
		if obj.precedes_original and not obj.summon then
			print("WARNING: precedes_original was set, but Blind does not have a summon")
		end
		if obj.precedes_original and obj.summon then
			return get_actual_original_blind(obj.summon)
		end
		return key
	end
	---@param blind Blind
	function create_UIBox_blind_passive(blind)
		local passive_lines = {}
		for _, v in ipairs(blind.passives_data) do
			local items = info_from_passive(v)
			passive_lines[#passive_lines + 1] = items[1]
			passive_lines[#passive_lines + 1] = items[2]
		end
		return {
			n = G.UIT.ROOT,
			config = { align = "cm", colour = lighten(G.C.JOKER_GREY, 0.5), r = 0.1, emboss = 0.05, padding = 0.05 },
			nodes = {
				{
					n = G.UIT.R,
					config = {
						align = "cm",
						emboss = 0.05,
						r = 0.1,
						minw = 2.5,
						padding = 0.05,
						colour = lighten(G.C.BLACK, 0.2),
					},
					nodes = {
						{ n = G.UIT.C, config = { align = "lm", padding = 0.05 }, nodes = passive_lines },
					},
				},
			},
		}
	end

	local blind_hoverref = Blind.hover
	function Blind.hover(self)
		if not G.CONTROLLER.dragging.target or G.CONTROLLER.using_touch then
			if not self.hovering and self.states.visible and self.children.animatedSprite.states.visible then
				if self.passives_data and #self.passives_data > 0 then
					G.blind_passive = UIBox({
						definition = create_UIBox_blind_passive(self),
						config = {
							major = self,
							parent = nil,
							offset = {
								x = 0.15,
								y = 0.2 + 0.38 * #self.passives_data,
							},
							type = "cr",
						},
					})
					G.blind_passive.attention_text = true
					G.blind_passive.states.collide.can = false
					G.blind_passive.states.drag.can = false
					if self.children.alert then
						self.children.alert:remove()
						self.children.alert = nil
					end
				end
			end
		end
		blind_hoverref(self)
	end

	local blind_stop_hoverref = Blind.stop_hover
	function Blind.stop_hover(self)
		if G.blind_passive then
			G.blind_passive:remove()
			G.blind_passive = nil
		end
		blind_stop_hoverref(self)
	end

	function find_passive(key)
		if G.GAME.blind and G.GAME.blind.passives_data then
			for _, v in ipairs(G.GAME.blind.passives_data) do
				if v.key == key then
					return true
				end
			end
		end
		return false
	end

	local ease_hands_playedref = ease_hands_played
	function ease_hands_played(mod, instant)
		ease_hands_playedref(mod, instant)
		if G.hands_to_add_on_blind_defeat then G.hands_to_add_on_blind_defeat = G.hands_to_add_on_blind_defeat + mod end
	end

	local update_new_roundref = Game.update_new_round
	function Game.update_new_round(self, dt)
		if self.buttons then
			self.buttons:remove()
			self.buttons = nil
		end
		if self.shop then
			self.shop:remove()
			self.shop = nil
		end

		if not G.STATE_COMPLETE and G.GAME.chips >= G.GAME.blind.chips then
			G.hands_to_add_on_blind_defeat = 0
			local should_end_round = true
			local should_reset_chips = false
			-- Phases
			-- For now, phases_beaten is linked to G.GAME.current_round instead of G.GAME.blind
			if G.GAME.blind.config.blind.phases then
				if G.GAME.current_round.phases_beaten < G.GAME.blind.config.blind.phases then
					G.GAME.current_round.phases_beaten = G.GAME.current_round.phases_beaten + 1
					if G.GAME.blind.config.blind.phase_refresh then
						-- Refresh deck
						G.FUNCS.draw_from_discard_to_deck()
						G.FUNCS.draw_from_hand_to_deck()
						G.E_MANAGER:add_event(Event({
							trigger = "before",
							delay = 1,
							blockable = false,
							func = function()
								G.E_MANAGER:add_event(Event({
									trigger = "immediate",
									func = function()
										G.deck:shuffle(G.GAME.blind.config.blind.key .. "_refresh")
										G.deck:hard_set_T()
										return true
									end,
								}))
								return true
							end,
						}))
					end

					local obj = G.GAME.blind.config.blind
					if obj.phase_change and type(obj.phase_change) == "function" then
						obj:phase_change()
					end

					should_end_round = false
					should_reset_chips = true
					G.GAME.blind_tray[G.GAME.blind.blind_id] = G.GAME.blind:save()
					G.GAME.blind_tray[G.GAME.blind.blind_id].scored_chips = 0
				end
			-- Summons
			elseif G.GAME.blind.config.blind.summon and (not G.GAME.blind.disabled or G.GAME.blind.config.blind.summon_while_disabled) then
				local obj = G.GAME.blind.config.blind
				G.P_BLINDS[obj.key].discovered = true
				if obj.defeat and type(obj.defeat) == "function" then
					obj:defeat()
				end
				G.GAME.blind.original_blind = G.GAME.blind.original_blind
					or get_actual_original_blind(G.GAME.blind.config.blind.key)
                local blind_id = G.GAME.blind.blind_id
				G.GAME.blind:set_blind(G.P_BLINDS[G.GAME.blind.config.blind.summon])
                G.GAME.blind.blind_id = blind_id
				G.GAME.blind.dollars = G.P_BLINDS[G.GAME.blind.original_blind].dollars
				G.GAME.blind.boss = G.P_BLINDS[G.GAME.blind.original_blind].boss
				G.GAME.current_round.dollars_to_be_earned = G.GAME.blind.dollars > 0
					and (string.rep(localize("$"), G.GAME.blind.dollars) .. "")
					or ""
					
				should_end_round = false
				should_reset_chips = true
				G.GAME.blind_tray[G.GAME.blind.blind_id] = G.GAME.blind:save()
				G.GAME.blind_tray[G.GAME.blind.blind_id].scored_chips = 0
			end

			-- Is summoned, and no more summons
			if should_end_round and G.GAME.blind.original_blind and G.GAME.blind.original_blind ~= G.GAME.blind.config.blind.key and (not G.GAME.blind.config.blind.summon or (G.GAME.blind.disabled and not G.GAME.blind.config.blind.summon_while_disabled)) then
				local blind_id = G.GAME.blind.blind_id
				G.GAME.blind:set_blind(G.P_BLINDS[G.GAME.blind.original_blind])
				G.GAME.blind.blind_id = blind_id
				G.GAME.blind.chips = -1 -- force win blind
				G.GAME.blind.children.alert = nil

				if G.GAME.chips >= G.GAME.blind.chips then
					local obj = G.GAME.blind.config.blind
					if obj.pre_defeat and type(obj.pre_defeat) == "function" then
						obj:pre_defeat()
					end
				end
			end

			-- Multiblind
			if should_end_round and #get_alive_blinds(true) > 0 then
				local alive = get_alive_blinds(true)
				local target
				if #alive > 0 then target = alive[1].blind_id == G.GAME.blind.blind_id and alive[2].blind_id or alive[1].blind_id end
				if target then should_end_round = false end
				G.E_MANAGER:add_event(Event({
					trigger = 'before',
					func = function()
						G.GAME.total_dollars = G.GAME.total_dollars + G.GAME.blind.dollars
						G.GAME.blind:defeat()
						G.E_MANAGER:add_event(Event({
						func = function()
							G.GAME.blind_tray[G.GAME.blind.blind_id].scored_chips = G.GAME.chips
							G.GAME.blind:swap_blind(target, nil, true)
							G.GAME.chips = G.GAME.blind.scored_chips
							ease_hands_played(1)
							ease_discard(1)
							for _, v in ipairs(G.playing_cards) do
								G.GAME.blind:debuff_card(v)
							end
							for _, v in ipairs(G.jokers.cards) do
								G.GAME.blind:debuff_card(v)
							end
							G.E_MANAGER:add_event(Event({
								trigger = 'after',
								blockable = false,
								delay =  0.8*1.3*2,
								func = function()
									G.HUD_blind.alignment.offset.y = 0
								return true end }))
						return true end }))
				return true end	}))
			end

			if not should_end_round and G.hands_to_add_on_blind_defeat + G.GAME.current_round.hands_left > 0 then
				G.STATE = G.STATES.DRAW_TO_HAND
				if should_reset_chips then
					G.E_MANAGER:add_event(Event({
						trigger = "ease",
						blocking = false,
						ref_table = G.GAME,
						ref_value = "chips",
						ease_to = 0,
						delay = 0.3 * G.SETTINGS.GAMESPEED,
						func = function(t)
							return math.floor(t)
						end,
					}))
				end
			end
		end

		if G.STATE ~= G.STATES.DRAW_TO_HAND then
			update_new_roundref(self, dt)
		end
	end

	local new_roundref = new_round
	function new_round()
		new_roundref()
		G.GAME.current_round.phases_beaten = 0
	end

	local calculate_round_scoreref = SMODS.calculate_round_score
	function SMODS.calculate_round_score(flames)
		local score = calculate_round_scoreref(flames)
		if G.GAME.blind then
			local obj = G.GAME.blind.config.blind
			if obj.mod_score and type(obj.mod_score) == "function" then
				return obj:mod_score(score)
			end
		end
		return score
	end

	local blind_calcref = Blind.calculate
	function Blind:calculate(context)
		local blind_eff = blind_calcref(self, context)
		local final_ret = { blind_eff }
			
		if self.passives_data and not self.disabled then
			for _, data in ipairs(self.passives_data) do
			local obj = blindexpander.Passives[data.key]
				if obj and not data.disabled then
					final_ret[#final_ret + 1] = obj:calculate(self, data, context)
				end
			end
		end
		if #final_ret == 0 then
			return nil
		elseif #final_ret == 1 then
			return final_ret[1]
		else
			return SMODS.merge_defaults(unpack(final_ret))
		end
	end

	G.FUNCS.show_blind_passives_infotip = function(e)
		if e.config.ref_table then
			local num_passives = #e.config.ref_table
			local y_offset = 0.3 * math.max(num_passives - 2, 0)
			e.children.info = UIBox({
				definition = create_UIBox_blind_passive({ passives_data = e.config.ref_table }),
				config = (
					not e.config.ref_table
					or not e.config.ref_table.card_pos
					or e.config.ref_table.card_pos.x > G.ROOM.T.w * 0.4
				)
						and { offset = { x = -0.13, y = y_offset }, align = "cl", parent = e }
					or { offset = { x = 0.13, y = y_offset }, align = "cr", parent = e },
			})
			e.children.info:align_to_major()
			e.config.ref_table = nil
		end
	end

	local blind_collection_UIBox_ref = create_UIBox_blind_popup
	function create_UIBox_blind_popup(blind, ...)
		local ret = blind_collection_UIBox_ref(blind, ...)
		if blind.passives then
			local fake_data = {}
			for _, key in ipairs(blind.passives) do
				local obj = blindexpander.Passives[key]
				local cfg = {}
				if obj then
					cfg = copy_table(obj.config)
				end
				fake_data[#fake_data + 1] = {
					disabled = false,
					key = key,
					config = cfg,
					blind_obj = blind,
				}
			end
			if blind.extra_collection_passives then
				for _, key in ipairs(blind.extra_collection_passives) do
					local obj = blindexpander.Passives[key]
					local cfg = {}
					if obj then
						cfg = copy_table(obj.config)
					end
					fake_data[#fake_data + 1] = {
						disabled = false,
						key = key,
						config = cfg,
						blind_obj = blind,
					}
				end
			end
			ret.config.object = Moveable()
			ret.config.ref_table = next(fake_data) and fake_data or nil
			ret.config.func = "show_blind_passives_infotip"
		end
		return ret
	end

	--- Multiblind
	function Blind:add_blind(blind, as_minion)
		local cur_blind_id = self.blind_id
		if #G.GAME.blind_tray == 1 then
			table.insert(G.HUD_blind:get_UIE_by_ID('HUD_blind_debuff').parent.children, UIBox({
				definition = create_UIBox_toggle_tray(),
				config = {
					align = "cm",
					offset = {x = 0, y = 1.35},
					parent = G.HUD_blind:get_UIE_by_ID('HUD_blind_debuff').parent,
				}
			}))
		end
		G.GAME.blind_tray[self.blind_id] = self:save()
		G.GAME.chips = 0
		self:set_blind(blind)
		if as_minion then
			self.dollars = 0
			G.GAME.current_round.dollars_to_be_earned = ""
			self.minion = true
			self:add_passive("psv_minion", true, true)
			if self.children.alert then
				self.children.alert:remove()
				self.children.alert = nil
			end
			self:swap_blind(cur_blind_id)
			return
		end
		G.ARGS.spin.real = (G.SETTINGS.reduced_motion and 0 or 1)*(self.config.blind.boss and (self.config.blind.boss.showdown and 1 or 0.3) or 0)
		ease_background_colour_blind()
		G.GAME.blind.loc_debuff_lines = {}
		G.FUNCS.HUD_blind_debuff(G.HUD_blind:get_UIE_by_ID('HUD_blind_debuff'))
		G.GAME.blind:set_text()
		G.FUNCS.HUD_blind_debuff(G.HUD_blind:get_UIE_by_ID('HUD_blind_debuff'))
		
	end

	local start_runref = Game.start_run
	function Game.start_run(self, args)
		start_runref(self, args)
		if G.GAME.blind_tray and #G.GAME.blind_tray > 1 then
			local toggle_tray = G.HUD_blind:get_UIE_by_ID('HUD_blind_toggle_tray')
			if not toggle_tray then
				table.insert(G.HUD_blind:get_UIE_by_ID('HUD_blind_debuff').parent.children, UIBox({
					definition = create_UIBox_toggle_tray(),
					config = {
						align = "cm",
						offset = {x = 0, y = 1.35},
						parent = G.HUD_blind:get_UIE_by_ID('HUD_blind_debuff').parent,
					}
				}))
			end
		end
	end

	function Blind:swap_blind(id, hotswap, no_save)
		if G.GAME.blind_tray and G.GAME.blind_tray[id] then
			--print("swapping to "..id.." "..G.GAME.blind_tray[id].name..(hotswap and " via hotswap" or ""))
			if G.GAME.blind_tray[id].scored_chips >= G.GAME.blind_tray[id].chips then return end
			if not no_save then 
				if not hotswap then self.scored_chips = G.GAME.chips end 
				G.GAME.blind_tray[self.blind_id] = self:save()
			end
			if hotswap then self:hot_load(G.GAME.blind_tray[id]); return; end
			from_swap = true
			self:load(G.GAME.blind_tray[id])
			from_swap = false
			G.GAME.current_round.dollars_to_be_earned = self.dollars > 0 and (string.rep(localize("$"), self.dollars) .. "") or ""
			self.loc_debuff_lines = {}
			G.FUNCS.HUD_blind_debuff(G.HUD_blind:get_UIE_by_ID('HUD_blind_debuff'))
			self:set_text()
			G.FUNCS.HUD_blind_debuff(G.HUD_blind:get_UIE_by_ID('HUD_blind_debuff'))
			self.children.animatedSprite.atlas = G.ANIMATION_ATLAS[self.config.blind.atlas or "blind_chips"]
			self.children.animatedSprite:reset()
		end
	end

	function get_alive_blinds(ignore_minions)
		if not G.GAME.blind_tray then return {} end
		local alive = {}
		for blind_id, blindTable in ipairs(G.GAME.blind_tray) do
			if ((blind_id == G.GAME.blind.blind_id and G.GAME.chips < G.GAME.blind.chips) or (blind_id ~= G.GAME.blind.blind_id and blindTable.scored_chips < blindTable.chips)) and 
				(not ignore_minions or not blindTable.minion) then
				table.insert(alive, blindTable)
			end
		end
		return alive
	end

	-- Debuff cards
	local debuff_cardref = Blind.debuff_card
	function Blind.debuff_card(self, card, from_blind)
		if not G.GAME.blind_tray or init_blind then return debuff_cardref(self, card, from_blind) end
		local cur_blind_id = self.blind_id
		local should_debuff = false
		for blind_id, blindTable in ipairs(G.GAME.blind_tray) do
			if blindTable.scored_chips < blindTable.chips then
				self:swap_blind(blind_id, true, true)
				local obj = self.config.blind
				if not self.disabled and obj.recalc_debuff and type(obj.recalc_debuff) == 'function' then
					if obj:recalc_debuff(card, from_blind) then
						should_debuff = true
					end
				end
				if self.debuff and not self.disabled and card.playing_card then
					should_debuff = should_debuff or (
						(self.debuff.suit and card:is_suit(self.debuff.suit, true)) or
						(self.debuff.is_face == 'face' and card:is_face(true)) or
						(self.name == 'The Pillar' and card.ability.played_this_ante) or
						(self.debuff.value and self.debuff.value == card.base.value) or
						(self.debuff.nominal and self.debuff.nominal == card.base.nominal)
					)
				end
				if self.name == 'Crimson Heart' and not self.disabled and card.area == G.jokers and card.ability.crimson_heart_chosen then 
					should_debuff = true
				elseif self.name == 'Verdant Leaf' and not self.disabled and card.playing_card then 
					should_debuff = true
				end
			end
		end
		self:swap_blind(cur_blind_id, true, true)
		card:set_debuff(should_debuff)
	end

	-- Press play
	local press_playref = Blind.press_play
	function Blind.press_play(self)
		if not G.GAME.blind_tray then return press_playref(self) end
		local cur_blind_id = self.blind_id
		for blind_id, blindTable in ipairs(G.GAME.blind_tray) do
			if blindTable.scored_chips < blindTable.chips then
				self:swap_blind(blind_id, true)
				press_playref(self)
			end
		end
		self:swap_blind(cur_blind_id, true)
	end

	-- Modify hand
	local modify_handref = Blind.modify_hand
	function Blind.modify_hand(self, cards, poker_hands, text, mult, hand_chips, scoring_hand)
		if not G.GAME.blind_tray then return modify_handref(self, cards, poker_hands, text, mult, hand_chips, scoring_hand) end
		local modded
		local cur_blind_id = self.blind_id
		for blind_id, blindTable in ipairs(G.GAME.blind_tray) do
			if blindTable.scored_chips < blindTable.chips then
				self:swap_blind(blind_id, true)
				mult, hand_chips, modded = modify_handref(self, cards, poker_hands, text, mult, hand_chips, scoring_hand)
			end
		end
		self:swap_blind(cur_blind_id, true)
		return mult, hand_chips, modded
	end

	-- Debuff hand
	local debuff_handref = Blind.debuff_hand
	function Blind.debuff_hand(self, cards, hand, handname, check)
		if not G.GAME.blind_tray then return debuff_handref(self, cards, hand, handname, check) end
		local debuffs = {}
		local cur_blind_id = self.blind_id
		for blind_id, blindTable in ipairs(G.GAME.blind_tray) do
			if blindTable.scored_chips < blindTable.chips then
				self:swap_blind(blind_id, true)
				if debuff_handref(self, cards, hand, handname, check) then
					table.insert(debuffs, blind_id)
				end
				if SMODS.hand_debuff_source then return true end -- debuffed by a card, ignore all other calls for debuff_hand
			end
		end
		self:swap_blind(cur_blind_id, true)
		if #debuffs > 1 then
			local str = ""
			for k, blind_id in pairs(debuffs) do
				str = str..localize{type = "name_text", key = G.P_BLINDS[G.GAME.blind_tray[blind_id].config_blind].key, set = "Blind"}
				if k ~= #debuffs then str = str..", " end
			end
			SMODS.debuff_text = str
		elseif #debuffs == 1 then
			self:swap_blind(debuffs[1], true, true)
			self:set_text()
			SMODS.debuff_text = self:get_loc_debuff_text()
			self:swap_blind(cur_blind_id, true, true)
			self:set_text()
		else SMODS.debuff_text = nil end
		return #debuffs > 0
	end

	-- Drawn to hand
	local drawn_to_handref = Blind.drawn_to_hand
	function Blind.drawn_to_hand(self)
		if not G.GAME.blind_tray then return drawn_to_handref(self) end
		local cur_blind_id = self.blind_id
		for blind_id, blindTable in ipairs(G.GAME.blind_tray) do
			if blindTable.scored_chips < blindTable.chips then
				self:swap_blind(blind_id, true)
				drawn_to_handref(self)
			end
		end
		self:swap_blind(cur_blind_id, true)
	end

	-- Stay flipped
	local stay_flippedref = Blind.stay_flipped
	function Blind.stay_flipped(self, area, card, from_area)
		if not G.GAME.blind_tray or init_blind then return stay_flippedref(self, area, card, from_area) end
		local cur_blind_id = self.blind_id
		local should_stay_flipped = false
		for blind_id, blindTable in ipairs(G.GAME.blind_tray) do
			if blindTable.scored_chips < blindTable.chips then
				self:swap_blind(blind_id, true, true)
				if not self.disabled then
					local obj = self.config.blind
					if obj.stay_flipped and type(obj.stay_flipped) == 'function' then
						should_stay_flipped = obj:stay_flipped(area, card, from_area)
					end
					if area == G.hand then
						should_stay_flipped = should_stay_flipped or (
							(self.name == 'The Wheel' and SMODS.pseudorandom_probability(self, pseudoseed('wheel'), 1, 7, 'wheel')) or
							(self.name == 'The House' and G.GAME.current_round.hands_played == 0 and G.GAME.current_round.discards_used == 0) or
							(self.name == 'The Mark' and card:is_face(true)) or
							(self.name == 'The Fish' and self.prepped)
						)
					end
				end
			end
		end
		self:swap_blind(cur_blind_id, true, true)
		return should_stay_flipped
	end

	-- All calculation
	local eval_individualref = SMODS.eval_individual
	function SMODS.eval_individual(individual, context)
		local cur_blind_id = G.GAME.blind.blind_id
		if individual.blind_id then
			G.GAME.blind:swap_blind(individual.blind_id, true)
		end
		local ret, post_trig = eval_individualref(individual, context)
		if individual.blind_id then
			G.GAME.blind:swap_blind(cur_blind_id, true)
		end
		return ret, post_trig
	end

	-- Says No reward on minions
	local HUD_blind_rewardref = G.FUNCS.HUD_blind_reward
	G.FUNCS.HUD_blind_reward = function(e)
		if G.GAME.blind and G.GAME.blind.minion then
			if e.config.minh > 0.44 then 
				e.config.minh = 0.4
				e.children[1].config.text = localize('k_no_reward')
				e.UIBox:recalculate(true)
			end
			return
		end
		HUD_blind_rewardref(e)
	end

	function create_UIBox_toggle_tray()
		return {n = G.UIT.R, config = {align = "cm", no_fill = true, padding = 0.1, func = "toggle_tray_visible", id = "HUD_blind_toggle_tray"}, nodes = {
			{n = G.UIT.C, config = {align = "cm", colour = G.C.DYN_UI.MAIN, maxw = 1.4, maxh = 0.5, padding = 0.1, r = 0.1, hover = true, button = "toggle_tray", shadow = true}, nodes = {
				{n = G.UIT.R, config = {align = "cm", no_fill = true}, nodes={
					{n = G.UIT.T, config = {text = "Toggle Tray", scale = 0.5, colour = G.C.WHITE, shadow = true}}
				}},
			}}
		}}
	end

	function create_UIBox_blind_stats(blindTable)
		local blind = G.P_BLINDS[blindTable.config_blind]
		local target = {type = 'raw_descriptions', key = blind.key, set = 'Blind', vars = vars or blind.vars}
		if blind.collection_loc_vars and type(blind.collection_loc_vars) == 'function' then
			local res = blind:collection_loc_vars() or {}
			target.vars = res.vars or target.vars
			target.key = res.key or target.key
			target.set = res.set or target.set
			target.scale = res.scale
			target.text_colour = res.text_colour
		end
		local loc_target = G.localization.descriptions[target.set][target.key].text_parsed
		local loc_name = localize{type = 'name_text', key = target.key or blind.key, set = target.set or 'Blind'}
		
		local ability_text = {}
		if loc_target then 
			for k, v in ipairs(loc_target) do
				ability_text[#ability_text + 1] = {n=G.UIT.R, config={align = "cm"}, nodes=SMODS.localize_box(v, {default_col = target.text_colour or G.C.WHITE, shadow = true, vars = target.vars, scale = target.scale})}
			end
		end
		local stake_sprite = get_stake_sprite(G.GAME.stake or 1, 0.4)
		local stake_sprite_2 = get_stake_sprite(G.GAME.stake or 1, 0.4)
		return {n=G.UIT.ROOT, config={align = "cm", padding = 0.05, colour = lighten(G.C.JOKER_GREY, 0.5), r = 0.1, emboss = 0.05}, nodes={
			{n=G.UIT.R, config={align = "cm", emboss = 0.05, r = 0.1, minw = 3, padding = 0.1, colour = blind.boss_colour or G.C.GREY}, nodes={
				{n=G.UIT.O, config={object = DynaText({string = loc_name, colours = {G.C.UI.TEXT_LIGHT}, shadow = true, rotate = true, spacing = 2, bump = true, scale = 0.4})}},
			}},
			{n=G.UIT.R, config={align = "cm"}, nodes = {
				{n=G.UIT.R, config={align = "cm", emboss = 0.05, r = 0.1, minw = 3, padding = 0.07, colour = G.C.WHITE}, nodes={
					{n=G.UIT.R, config={align = "cm", r = 0.1, padding = 0.05, emboss = 0.05, colour = mix_colours(get_blind_main_colour(blind.key), G.C.BLACK, 0.4)}, nodes={
						{n=G.UIT.R, config={align = "cm"}, nodes={
							{n=G.UIT.T, config={text = localize('ph_blind_score_at_least')..": ", scale = 0.35, colour = G.C.WHITE}},
							{n=G.UIT.O, config={object = stake_sprite}},
							{n=G.UIT.T, config={text = number_format(blindTable.chips), scale = 0.4, colour = G.C.RED}}
						}},
						{n=G.UIT.R, config={align = "cm"}, nodes={
							{n=G.UIT.T, config={text = localize('k_round').." "..localize('k_lower_score')..": ", scale = 0.35, colour = G.C.WHITE}},
							{n=G.UIT.O, config={object = stake_sprite_2}},
							{n=G.UIT.T, config={text = number_format(blindTable.scored_chips), scale = 0.4, colour = G.C.WHITE}}
						}},
						{n=G.UIT.R, config={align = "cm"}, nodes = blindTable.dollars > 0 and {
							{n=G.UIT.T, config={text = localize('ph_blind_reward'), scale = 0.3, colour = G.C.WHITE}},
							{n=G.UIT.O, config={object = DynaText({string = {{ref_table = G.GAME.current_round, ref_value = 'dollars_to_be_earned'}}, colours = {G.C.MONEY},shadow = true, rotate = true, bump = true, silent = true, scale = 0.45}),id = 'dollars_to_be_earned'}},
						}},
					}},
					ability_text[1] and {n=G.UIT.R, config={align = "cm", padding = 0.08, colour = mix_colours(blind.boss_colour, G.C.GREY, 0.4), r = 0.1, emboss = 0.05, minw = 2.5, minh = 0.9}, nodes=ability_text} or nil
				}}
			}},
		}}
	end

	function create_UIBox_blind_tray()
		G.blind_tray_hover = {}
		local blind_chips = {}
		for blind_id, blindTable in ipairs(get_alive_blinds()) do
			local blind_config = G.P_BLINDS[blindTable.config_blind]
			local blind_animation = SMODS.create_sprite(0,0, 1.2, 1.2, SMODS.get_atlas(blind_config.atlas) or 'blind_chips', blind_config.pos)
			blind_animation.blind_id = blind_id

			blind_animation.states.collide.can = true
			blind_animation.states.drag.can = true
			blind_animation.states.hover.can = true
			blind_animation.states.click.can = true

			blind_animation.click_timeout = 0.3

			function blind_animation:hover()
				for i = 1, G.GAME.blind_id do
					if G.blind_tray_hover[i] then
						G.blind_tray_hover[i]:remove()
						G.blind_tray_hover[i] = nil
					end
				end
				blind_animation.hovering = true
				blind_animation.hover_tilt = 3
				blind_animation:juice_up(0.05, 0.02)
				play_sound('chips1', math.random() * 0.1 + 0.55, 0.12)
				G.blind_tray_hover[self.blind_id] = UIBox{
					definition = create_UIBox_blind_stats(blindTable),
					config = {
						major = self,
						parent = nil,
						offset = {
							x = 0,
							y = 0.5,
						},  
						type = "bm",
					}
				}
				G.blind_tray_hover[self.blind_id].attention_text = true
				G.blind_tray_hover[self.blind_id].states.collide.can = false
				G.blind_tray_hover[self.blind_id].states.drag.can = false
				if blindTable.passives_data then
					G.blind_tray_hover[self.blind_id].children.passives = UIBox{
						definition = create_UIBox_blind_passive({ passives_data = blindTable.passives_data }),
						config = {
							parent = G.blind_tray_hover[self.blind_id],
							offset = {
								x = 0.1,
								y = 0,
							},  
							type = "cr",
						}
					}
					G.blind_tray_hover[self.blind_id].children.passives.attention_text = true
					G.blind_tray_hover[self.blind_id].children.passives.states.collide.can = false
					G.blind_tray_hover[self.blind_id].children.passives.states.drag.can = false
				end
				Sprite.hover(self)
			end
			
			function blind_animation:stop_hover()
				blind_animation.hovering = false
				blind_animation.hover_tilt = 0
				if G.blind_tray_hover[self.blind_id] then
					if G.blind_tray_hover[self.blind_id].children.passives then
						G.blind_tray_hover[self.blind_id].children.passives:remove()
						G.blind_tray_hover[self.blind_id].children.passives = nil
					end
					G.blind_tray_hover[self.blind_id]:remove()
					G.blind_tray_hover[self.blind_id] = nil
				end
				Sprite.stop_hover(self)
			end

			function blind_animation:click()
				G.GAME.blind:swap_blind(self.blind_id)
			end

			blind_animation:define_draw_steps({
				{shader = 'dissolve', shadow_height = 0.05},
				{shader = 'dissolve'}
			})

			table.insert(blind_chips, {
				n = G.UIT.O, config = {object = blind_animation}
			})
		end

		return 
			{n = G.UIT.R, config = { align = "cm", minh = 1, r = 0.3, padding = 0.07, colour = G.C.DYN_UI.DARK, emboss = 0.1}, nodes = {
				{n = G.UIT.C, config={align = "cm", minh = 1, r = 0.2, padding = 0.1, colour = G.C.DYN_UI.MAIN}, nodes={
					{n = G.UIT.R, config = {align = "cm", colour = G.C.CLEAR, padding = 0.1}, nodes = blind_chips},
				}},
			}}
	end

	function G.FUNCS.toggle_tray_visible(e)
		if not G.GAME.blind_tray or #G.GAME.blind_tray == 1 then
			local uibox_ref = e.UIBox
			e:remove()
			e = nil
			uibox_ref:recalculate()
		end
	end

	function G.FUNCS.toggle_tray(e)
		if not G.blind_tray then
			G.blind_tray = UIBox({
				definition = create_UIBox_blind_tray(),
				config = {
					offset = {
						x = 0.3, y = -1
					},
					type = "cr",
					major = G.HUD_blind:get_UIE_by_ID('HUD_blind')
				}
			})
			G.blind_tray.attention_text = true
		else
			G.blind_tray:remove()
			G.blind_tray = nil
		end
	end
end

blindexpander = blindexpander or {}
if not blindexpander.ver or blindexpander.ver < BLINDEXPANDER_VERSION then
	blindexpander.ver = BLINDEXPANDER_VERSION
	blindexpander.startup = startup
end

function UIElement:draw_pixellated_strikethough(_type, _parallax, _emboss, _progress)
	if
		not self.pixellated_rect
		or #self.pixellated_rect[_type].vertices < 1
		or _parallax ~= self.pixellated_rect.parallax
		or self.pixellated_rect.w ~= self.VT.w
		or self.pixellated_rect.h ~= self.VT.h
		or self.pixellated_rect.sw ~= self.shadow_parrallax.x
		or self.pixellated_rect.sh ~= self.shadow_parrallax.y
		or self.pixellated_rect.progress ~= (_progress or 1)
	then
		self.pixellated_rect = {
			w = self.VT.w,
			h = self.VT.h,
			sw = self.shadow_parrallax.x,
			sh = self.shadow_parrallax.y,
			progress = (_progress or 1),
			fill = { vertices = {} },
			shadow = { vertices = {} },
			line = { vertices = {} },
			emboss = { vertices = {} },
			line_emboss = { vertices = {} },
			parallax = _parallax,
		}
		local ext_up = self.config.ext_up and self.config.ext_up * G.TILESIZE or 0
		local totw, toth = self.VT.w * G.TILESIZE, (self.VT.h + math.abs(ext_up) / G.TILESIZE) * G.TILESIZE

		local vertices = {
			totw,
			toth / 2 + ext_up,
			0,
			toth / 2 + ext_up,
			0,
			toth / 2 + ext_up + 1,
			totw,
			toth / 2 + ext_up + 1,
		}
		for k, v in ipairs(vertices) do
			if k % 2 == 1 and v > totw * self.pixellated_rect.progress then
				v = totw * self.pixellated_rect.progress
			end
			self.pixellated_rect.fill.vertices[k] = v
			if k > 4 then
				self.pixellated_rect.line.vertices[k - 4] = v
				if _emboss then
					self.pixellated_rect.line_emboss.vertices[k - 4] = v
						+ (
							k % 2 == 0 and -_emboss * self.shadow_parrallax.y
							or -0.7 * _emboss * self.shadow_parrallax.x
						)
				end
			end
			if k % 2 == 0 then
				self.pixellated_rect.shadow.vertices[k] = v - self.shadow_parrallax.y * _parallax
				if _emboss then
					self.pixellated_rect.emboss.vertices[k] = v + _emboss * G.TILESIZE
				end
			else
				self.pixellated_rect.shadow.vertices[k] = v - self.shadow_parrallax.x * _parallax
				if _emboss then
					self.pixellated_rect.emboss.vertices[k] = v
				end
			end
		end
	end
	love.graphics.polygon("fill", self.pixellated_rect.fill.vertices)
end

local injectItemsref = SMODS.injectItems
function SMODS.injectItems()
	injectItemsref()
	blindexpander.startup()
end

SMODS.current_mod.calculate = function(self, context)
	if
		context.end_of_round
		and not context.game_over
		and context.main_eval
		and context.beat_boss
	then
		G.GAME.blindexpander_hovered_this_ante = {}
	end
end