---@meta

---@class blindexpander.Passive: SMODS.GameObject
---@field super? SMODS.GameObject|table Parent class.
---@field __call? fun(self: blindexpander.Passive|table, o: blindexpander.Passive|table): nil|table|blindexpander.Passive
---@field extend? fun(self: blindexpander.Passive|table, o: blindexpander.Passive|table): table Primary method of creating a class.
---@field check_duplicate_register? fun(self: blindexpander.Passive|table): boolean? Ensures objects already registered will not register.
---@field check_duplicate_key? fun(self: blindexpander.Passive|table): boolean? Ensures objects with duplicate keys will not register. Checked on `__call` but not `take_ownership`. For take_ownership, the key must exist.
---@field register? fun(self: blindexpander.Passive|table) Registers the object.
---@field check_dependencies? fun(self: blindexpander.Passive|table): boolean? Returns `true` if there's no failed dependencies.
---@field process_loc_text? fun(self: blindexpander.Passive|table) Called during `inject_class`. Handles injecting loc_text.
---@field send_to_subclasses? fun(self: blindexpander.Passive|table, func: string, ...: any) Starting from this class, recusively searches for functions with the given key on all subordinate classes and run all found functions with the given arguments.
---@field pre_inject_class? fun(self: blindexpander.Passive|table) Called before `inject_class`. Injects and manages class information before object injection.
---@field post_inject_class? fun(self: blindexpander.Passive|table) Called after `inject_class`. Injects and manages class information after object injection.
---@field inject_class? fun(self: blindexpander.Passive|table) Injects all direct instances of class objects by calling `obj:inject` and `obj:process_loc_text`. Also injects anything necessary for the class itself. Only called if class has defined both `obj_table` and `obj_buffer`.
---@field inject? fun(self: blindexpander.Passive|table, i?: number) Called during `inject_class`. Injects the object into the game.
---@field take_ownership? fun(self: blindexpander.Passive|table, key: string, obj: blindexpander.Passive|table, silent?: boolean): nil|table|blindexpander.Passive Takes control of vanilla objects. Child class must have get_obj for this to function
---@field get_obj? fun(self: blindexpander.Passive|table, key: string): blindexpander.Passive|table? Returns an object if one matches the `key`.
---@field obj_buffer? string[] Array of keys to all objects registered to this class. 
---@field obj_table? table<string, blindexpander.Passive|table> Table of objects registered to this class.
---@field loc_vars? fun(self: blindexpander.Passive, blind: Blind, passive: PassiveData): table?.
---@field calculate? fun(self: blindexpander.Passive, blind: Blind, passive: PassiveData, context: CalcContext): table? Acts as a usual calculate function.
---@field remove? fun(self: blindexpander.Passive, passive: PassiveData, from_disable: boolean?) Called when this passive is removed or disabled.
---@field apply? fun(self: blindexpander.Passive, passive: PassiveData, from_disable: boolean?) Called when this passive is applied to the Blind or this passive becomes undisabled.

---@overload fun(self: blindexpander.Passive): blindexpander.Passive
blindexpander.Passive = setmetatable({}, {
	__call = function(self)
		return self
	end,
})

---@class Blind
---@field passives_data? PassiveData[] Contains tables that store the states of individual passives.

---@class PassiveData
---@field config table
---@field disabled boolean
---@field key string