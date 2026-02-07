---@meta

--- Returns a row node that contains information of a passive.
---@param passive_data PassiveData A table representing a Passive.
---@return table
function info_from_passive(passive_data) end

--- Returns a root node that contains the UIBox of all passives.
---@param blind table Current blind. (G.GAME.blind)
---@return table
function create_UIBox_blind_passive(blind) end

--- Allows changing width of passive UIBox.
---@return number passive_width Width of the passive UIBox, default 6
function SMODS.current_mod.passive_ui_size() end

--- Finds whether or not the current blind has a passive with the given key.
---@param key string Key of the passive.
---@return boolean
function find_passive(key) end

--- Gets the original Blind's key when a Blind is set. Will recursively check a Blind's summon until the Blind either does not precede the original or does not have a summon.
---@param key string
---@return string
function get_actual_original_blind(key) end

---@type table<string, blindexpander.Passive>
blindexpander.Passives = {}

---@class SMODS.GameObject: metatable
---@class SMODS.Blind: SMODS.GameObject
---@field passives? string[] Contains passive keys.
---@field summon_while_disabled? boolean If true, this Blind will summon the next Blind, even if this Blind is disabled.
---@field summon? string Key of the Blind to be fought after current Blind ends.
---@field precedes_original? boolean If true, its summon is considered the original Blind. Will recursively check the Blind's chain of summons.
---@field phases? number Amount of times Blind need to be defeated before round ends.
---@field phase_refresh? boolean Whether the deck should be refreshed when Blind is defeated.
---@field mod_score? fun(self: SMODS.Blind|table, score: number): number Modifies the score. 
---@field phase_change? fun(self: SMODS.Blind) Called when the Blind is defeated, and a new phase starts.
---@field pre_defeat? fun(self: SMODS.Blind) Called when the final Blind (requires summon or phases) is defeated, but before deck shuffle and round eval occurs.
