-- G.GAME.blind_tray: created on set_blind
-- Blind:add_blind

local init_blind = false
local from_swap = false

local set_blindref = Blind.set_blind
function Blind.set_blind(self, blind, reset, silent)
    if not reset and not blind then
        if #get_alive_blinds() == 0 then
            G.GAME.blind_tray = nil
            G.GAME.blind_id = nil
        end
    end
    if not reset and blind and not G.GAME.blind_tray then
        init_blind = true
        G.GAME.blind_tray = {}
        G.GAME.blind_id = 1
    end
    if not reset and blind and not self.original_blind then
        self.blind_id = G.GAME.blind_id
        self.scored_chips = 0
        G.GAME.blind_id = G.GAME.blind_id + 1
    end
    set_blindref(self, blind, reset, silent)
    init_blind = false
end

local blind_saveref = Blind.save
function Blind.save(self)
    local blindTable = blind_saveref(self)
    if not G.should_not_save_chips then blindTable.scored_chips = G.GAME.chips
    else blindTable.scored_chips = self.scored_chips end
    blindTable.blind_id = self.blind_id
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
            delay = 0.3 * G.SETTINGS.GAMESPEED,
            func = function(t)
                return math.floor(t)
            end,
        }))
    end
    
    self.blind_id = blindTable.blind_id
    blind_loadref(self, blindTable)
end

function Blind:hot_load(blindTable)
    for k, v in pairs(blindTable) do
        if k == "config_blind" then self.config.blind = G.P_BLINDS[blindTable.config_blind] or {}
        elseif k == "scored_chips" then
        else self[k] = blindTable[k] end
    end
end

function Blind:add_blind(blind)
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
        if not no_save then G.GAME.blind_tray[self.blind_id] = self:save() end
        if hotswap then self:hot_load(G.GAME.blind_tray[id]); return; end
        from_swap = true
        self:load(G.GAME.blind_tray[id])
        from_swap = false
        G.GAME.blind.loc_debuff_lines = {}
        G.FUNCS.HUD_blind_debuff(G.HUD_blind:get_UIE_by_ID('HUD_blind_debuff'))
        G.GAME.blind:set_text()
        G.FUNCS.HUD_blind_debuff(G.HUD_blind:get_UIE_by_ID('HUD_blind_debuff'))
    end
end

function get_alive_blinds()
    if not G.GAME.blind_tray then return {} end
    local alive = {}
    for blind_id, blindTable in ipairs(G.GAME.blind_tray) do
        if (blind_id == G.GAME.blind.blind_id and G.GAME.chips < G.GAME.blind.chips) or (blind_id ~= G.GAME.blind.blind_id and blindTable.scored_chips < blindTable.chips) then
            table.insert(alive, blindTable)
        end
    end
    return alive
end

--== CALCULATION ==--

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
            self:swap_blind(cur_blind_id, true, true)
        end
    end
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
            self:swap_blind(cur_blind_id, true)
        end
    end
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
            self:swap_blind(cur_blind_id, true)
        end
    end
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
            self:swap_blind(cur_blind_id, true)
        end
    end
    if #debuffs > 1 then
        local str = ""
        for k, blind_id in pairs(debuffs) do
            str = str..localize{type = "name_text", key = G.P_BLINDS[G.GAME.blind_tray[blind_id].config_blind].key, set = "Blind"}
            if k ~= #debuffs then str = str..", " end
        end
        SMODS.debuff_text = str
    elseif #debuffs == 1 then
        self:swap_blind(debuffs[1], true)
        self:set_text()
        SMODS.debuff_text = self:get_loc_debuff_text()
        self:swap_blind(cur_blind_id, true)
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
            self:swap_blind(cur_blind_id, true)
        end
    end
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
            self:swap_blind(cur_blind_id, true, true)
        end
    end
    return should_stay_flipped
end

--== UI ==--

function create_UIBox_toggle_tray()
    return {n = G.UIT.R, config = {align = "cm", no_fill = true, padding = 0.1, func = "toggle_tray_visible", id = "HUD_blind_toggle_tray"}, nodes = {
        {n = G.UIT.C, config = {align = "cm", colour = G.C.DYN_UI.MAIN, maxw = 1.4, maxh = 0.5, padding = 0.1, r = 0.1, hover = true, button = "toggle_tray", shadow = true}, nodes = {
            {n = G.UIT.R, config = {align = "cm", no_fill = true}, nodes={
                {n = G.UIT.T, config = {text = "Toggle Tray", scale = 0.5, colour = G.C.WHITE, shadow = true}}
            }},
        }}
    }}
end

function create_UIBox_blind_tray()
    local blind_chips = {}
    for blind_id, blindTable in ipairs(get_alive_blinds()) do
        local blind_config = G.P_BLINDS[blindTable.config_blind]
        local blind_animation = SMODS.create_sprite(0,0, 1.2, 1.2, SMODS.get_atlas(blind_config.atlas) or 'blind_chips', blind_config.pos) 

        blind_animation.states.collide.can = true
        blind_animation.states.drag.can = true
        blind_animation.states.hover.can = true

        function blind_animation:hover()
            if G.blind_tray_hover then
                G.blind_tray_hover:remove()
                G.blind_tray_hover = nil
            end
            if blindTable.passives_data then
                G.blind_tray_hover = UIBox{
                    definition = create_UIBox_blind_passive({ passives_data = blindTable.passives_data }),
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
                G.blind_tray_hover.attention_text = true
                G.blind_tray_hover.states.collide.can = false
                G.blind_tray_hover.states.drag.can = false
            end
            Sprite.hover(self)
        end
        
        function blind_animation:stop_hover()
            if G.blind_tray_hover then
                G.blind_tray_hover:remove()
                G.blind_tray_hover = nil
            end
            Sprite.stop_hover(self)
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
            {n = G.UIT.C, config={align = "cm", minh = 1, r = 0.2, padding = 0.1, colour = darken(G.C.DYN_UI.MAIN, 0.2)}, nodes={
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