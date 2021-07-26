local max_stack_size_items = GetModConfigData("StackSizeItems")
local is_dst = GLOBAL.TheSim:GetGameID() == "DST"
local is_server = GLOBAL.TheNet:GetIsServer()

GLOBAL.setmetatable(
  env,
  {
    __index = function(t, k) return GLOBAL.rawget(GLOBAL, k) end
  }
)

local items_pass = {
  "backpack",
  "bundle",
  "blueprint",
  "candybag",
  "foliageath_together",
  "gift",
  "glommerflower",
  "hambat",
  "heatrock",
  "icepack",
  "krampus_sack",
  "miao_packbox",
  "miao_packbox_full",
  "piggyback",
  "premiumwateringcan",
  "sketch",
  "spicepack",
  "tacklesketch",
  "wateringcan",
}
local must_have_tags = {
  "_stackable",
  "_inventoryitem",
}
local must_not_have_tags = { 
  "INLIMBO", 
  "NOCLICK", 
  "catchable", 
  "fire",
}

TUNING.STACK_SIZE_TINYITEM = max_stack_size_items
TUNING.STACK_SIZE_SMALLITEM = max_stack_size_items
TUNING.STACK_SIZE_MEDITEM = max_stack_size_items
TUNING.STACK_SIZE_LARGEITEM = max_stack_size_items

local function decrease_size(inst)
  local size = inst.components.stackable:StackSize() - 1
  inst.components.stackable:SetStackSize(size)    
end

local function event_finish(inst)
  decrease_size(inst)
  if inst.components.finiteuses ~= nil then
    inst.components.finiteuses:SetPercent(1)
  elseif inst.components.fueled ~= nil then
    inst.components.fueled:SetPercent(1)
  end         
end

local function modify_true(
  inst, 
  components_one, 
  components_two
)
  local percent = components_one:GetPercent() + 
    components_two:GetPercent()
  if percent > 1 then
    percent = percent - 1
  else
    decrease_size_by_one(inst)
  end

  components_one:SetPercent(percent)
end

local function modify_false(
  item, 
  components_one, 
  components_two
)
  local percent = components_one:GetPercent()
  if percent < 1 then
    local item_percent = components_two:GetPercent()
    local left_percent = 1 - percent
    if item_percent > left_percent then
      local new_percent = item_percent - left_percent
      components_two:SetPercent(new_percent)
      components_one:SetPercent(1)
    else
      if item.components.stackable:StackSize() > 1 then
        components_one:SetPercent(1)
        local new_percent = 1 - (left_percent - item_percent)
        components_two:SetPercent(new_percent)
        decrease_size_by_one(item)
      else
        local new_percent = percent + item_percent
        components_one:SetPercent(new_percent)
        item:Remove()
        return true
      end
    end
    if components_two:GetPercent() < 0.01 then
      item:Remove()
      return true
    end
  end
  return false
end

local function stackable_behavior(self)
  local new_put = self.Put
  self.Put = function(self, item, source)
    if item.prefab == self.inst.prefab then
      local new_total = item.components.stackable:StackSize() + 
      self.inst.components.stackable:StackSize()
      if item.components.finiteuses ~= nil then
        if new_total <= self.inst.components.stackable.maxsize then
          modify_true(
            self.inst, 
            self.inst.components.finiteuses, 
            item.components.finiteuses
          )
        else
          if modify_false(
            item, 
            self.inst.components.finiteuses, 
            item.components.finiteuses
          ) then
            return nil
          end
        end
      elseif item.components.fueled ~= nil then
        if new_total <= self.inst.components.stackable.maxsize then
          modify_true(
            self.inst, 
            self.inst.components.fueled, 
            item.components.fueled
          )
        else
          if modify_false(
            item, 
            self.inst.components.fueled, 
            item.components.fueled
          ) then
           return nil
          end
        end
      elseif item.components.armor ~= nil then
        if new_total <= self.inst.components.stackable.maxsize then
          modify_true(
            self.inst, 
            self.inst.components.armor, 
            item.components.armor
          )
        else
          if modify_false(
            item, 
            self.inst.components.armor, 
            item.components.armor
          ) then
            return nil
          end
        end
      end
    end
    return new_put(self, item, source)
  end
end

local function modify_sectionfn(
  callback, 
  new, 
  old, 
  inst, 
  is_dlc
)
  if new == 0 then
    if inst.components.stackable:StackSize() > 1 then
      event_finish(inst)
    else
      callback(new, old, inst)
    end  
  end  
end

local function add_stackable(inst)
  if inst.components.stackable ~= nil then
    return
 end
  if inst.components.sanity ~= nil then
    return
  end
  if inst.components.inventoryitem == nil  then
    return
  end

  for _, value in pairs(items_pass) do
    if type(inst.prefab) == type(value) and inst.prefab == value then
      if inst.components.inventoryitem then
        inst.components.inventoryitem.cangoincontainer = true
        return
      end
      return
    end
  end

  inst:AddComponent("stackable")
  if inst:HasTag("trap") then
    inst.components.stackable.forcedropsingle = true
  end
  if inst.components.projectile == nil or 
    (inst.components.projectile ~= nil and 
    not inst.components.projectile.cancatch) then
    if inst.components.throwable == nil then
      if inst.components.equippable ~= nil then
        inst.components.equippable.equipstack = true
      end 
    end 
  end
        
  if inst.components.finiteuses == nil then
    if inst.components.fueled == nil then
      return
    end     
  end
                
  if inst.components.finiteuses ~= nil then
    local onfinished = inst.components.finiteuses.onfinished and 
      inst.components.finiteuses.onfinished or nil
    if onfinished ~= nil then
      inst.components.finiteuses.onfinished = function(inst)         
        if inst.components.stackable:StackSize() > 1 then
          event_finish(inst)
        else
          onfinished(inst)
        end 
      end
    end
  end
  if inst.components.fueled ~= nil then
    local sectionfn = inst.components.fueled.sectionfn and 
      inst.components.fueled.sectionfn or nil
    if sectionfn ~= nil then
      inst.components.fueled.sectionfn = function(new, old, inst)
          modify_sectionfn(sectionfn, new, old, inst, true)
      end
    else
      local new_depleted = inst.components.fueled.depleted and 
        inst.components.fueled.depleted or nil
      if new_depleted ~= nil then
        inst.components.fueled.depleted = function(inst)   
          if inst.components.stackable:StackSize() > 1 then
            event_finish(inst)
          else
            new_depleted(inst)
          end
        end
      end
    end 
  end
end

local function armor_behavior(self)
  local new_condition = self.SetCondition
  self.SetCondition = function(self, amount)
    local armor_hp = math.min(amount, self.maxcondition)
    if armor_hp <= 0 then
      if self.inst.components.stackable ~= nil and
        self.inst.components.stackable:StackSize() > 1
      then
        decrease_size_by_one(self.inst)
        amount = self.maxcondition
      end
    end
    new_condition(self, amount)
  end
end

local function put_prefab_target(item, target)
  if target and target:IsValid() and 
    target ~= item and target.prefab == item.prefab and 
    item.components.stackable and 
    not item.components.stackable:IsFull() and 
    target.components.stackable and 
    not target.components.stackable:IsFull() 
then
    local position = GLOBAL.SpawnPrefab("small_puff")
    position.Transform:SetPosition(target.Transform:GetWorldPosition())
    position.Transform:SetScale(.5, .5, .5)

    item.components.stackable:Put(target)
  end
end

local function prefabs_behavior(inst)
  if inst.components.stackable == nil or 
    inst.components.inventoryitem == nil then 
    return
  end
  inst:ListenForEvent("on_loot_dropped", function(inst)
    inst:DoTaskInTime(.5, function(inst)
      if inst and inst:IsValid() and 
        not inst.components.stackable:IsFull() then
        local x, y, z = inst:GetPosition():Get()
        local range = 20
        local entities = TheSim:FindEntities(
          x, y, z, 
          range, 
          must_have_tags, 
          must_not_have_tags
        )
        for _, value in pairs(entities) do
          put_prefab_target(inst, value)
        end
      end
    end)
  end)
end

local function pig_king_stack(inst)
  local old_onaccept = inst.components.trader.onaccept
  inst.components.trader.onaccept = function(inst, giver, item)
    if old_onaccept ~= nil then 
      old_onaccept(inst, giver, item) 
    end

    inst:DoTaskInTime(2, function(inst)
      local x, y, z = inst:GetPosition():Get()
      local range = 20
      local ents = TheSim:FindEntities(
        x, y, z, 
        range, 
        { "_inventoryitem" }, 
        { "INLIMBO", "NOCLICK", "catchable", "fire" }
      )
      for _, objBase in pairs(ents) do
        if objBase:IsValid() and objBase.components.stackable and not 
          objBase.components.stackable:IsFull() then
          for _,obj in pairs(ents) do
            if obj:IsValid() then
              put_prefab_target(objBase, obj)
            end
          end
        end
      end
    end)
  end
end

if not is_dst or (is_dst and is_server) then
  AddPrefabPostInit("pigking", pig_king_stack)
  AddPrefabPostInitAny(add_stackable)
  AddPrefabPostInitAny(prefabs_behavior)
  AddComponentPostInit("stackable", stackable_behavior)
  AddComponentPostInit("armor", armor_behavior)
end

local component_stackable = require("components/stackable_replica")

local function edit_stackable(self, inst)
  self.inst = inst
  self._stacksize = net_shortint(
    inst.GUID, 
    "stackable._stacksize", 
    "stacksizedirty"
  )
  self._maxsize = net_tinybyte(
    inst.GUID, 
    "stackable._maxsize"
  )
end

component_stackable._ctor = edit_stackable
