---@meta

--- Returns a row node that contains information of a passive.
---@param passive string Key of the passive.
---@return table
function info_from_passive(passive) end

--- Returns a root node that contains the UIBox of all passives.
---@param blind table Current blind. (G.GAME.blind)
---@return table
function create_UIBox_blind_passive(blind) end

--- Allows changing width of passive UIBox.
---@return number passive_width Width of the passive UIBox, default 6
function SMODS.current_mod.passive_ui_size() end

--- Finds whether a passive is on the current blind or not.
---@param key string Key of the passive.
---@return boolean
function find_passive(key) end

---@class SMODS.GameObject: metatable
---@class SMODS.Blind: SMODS.GameObject
---@field passives? table Contains passive keys.
---@field summon? string Key of the Blind to be fought after current Blind ends.
---@field phases? number Amount of times Blind need to be defeated before round ends.
---@field phase_refresh? boolean Whether the deck should be refreshed when Blind is defeated.
---@field mod_score? fun(self: SMODS.Blind|table, score: number): number Modifies the score. 
---@field phase_change? fun(self: SMODS.Blind) Called when the Blind is defeated, and a new phase starts.
---@field pre_defeat? fun(self: SMODS.Blind) Called when the final Blind (requires summon or phases) is defeated, but before deck shuffle and round eval occurs.