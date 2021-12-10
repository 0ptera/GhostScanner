--[[ Copyright (c) 2019 Optera
 * Part of Ghost Scanner
 *
 * See LICENSE.md in the project directory for license information.
--]]

-- local logger = require("__OpteraLib__.script.logger")
-- logger.settings.read_all_properties = false
-- logger.settings.max_depth = 6

-- logger.settings.class_dictionary.LuaEntity = {
--   backer_name = true,
--   name = true,
--   type = true,
--   unit_number = true,
--   force = true,
--   logistic_network = true,
--   logistic_cell = true,
--   item_requests = true,
--   ghost_prototype = true,
--  }
-- logger.settings.class_dictionary.LuaEntityPrototype = {
--   type = true,
--   name = true,
--   valid = true,
--   items_to_place_this = true,
--   next_upgrade = true,
--  }


-- constant prototypes names
local Scanner_Name = "ghost-scanner"

---- MOD SETTINGS ----

local UpdateInterval = settings.global["ghost-scanner-update-interval"].value
local MaxResults = settings.global["ghost-scanner-max-results"].value
if MaxResults == 0 then MaxResults = nil end
local ShowHidden = settings.global["ghost-scanner-show-hidden"].value
local InvertSign = settings.global["ghost-scanner-negative-output"].value
local RoundToStack = settings.global["ghost-scanner-round2stack"].value
local ShowCellCount = settings.global["ghost-scanner-cell-count"].value

script.on_event(defines.events.on_runtime_mod_setting_changed, function(event)
  if event.setting == "ghost-scanner-update-interval" then
    UpdateInterval = settings.global["ghost-scanner-update-interval"].value
    UpdateEventHandlers()
  end
  if event.setting == "ghost-scanner-max-results" then
    MaxResults = settings.global["ghost-scanner-max-results"].value
    if MaxResults == 0 then MaxResults = nil end
  end
  if event.setting == "ghost-scanner-show-hidden" then
    ShowHidden = settings.global["ghost-scanner-show-hidden"].value
    global.Lookup_items_to_place_this = {}
  end
  if event.setting == "ghost-scanner-negative-output" then
    InvertSign = settings.global["ghost-scanner-negative-output"].value
  end
  if event.setting == "ghost-scanner-round2stack" then
    RoundToStack = settings.global["ghost-scanner-round2stack"].value
  end
  if event.setting == "ghost-scanner-cell-count" then
    ShowCellCount = settings.global["ghost-scanner-cell-count"].value
  end
end)


---- EVENTS ----

do -- create & remove
function OnEntityCreated(event)
  local entity = event.created_entity or event.entity
  if entity and entity.valid then
    if entity.name == Scanner_Name then
      global.GhostScanners = global.GhostScanners or {}

      -- entity.operable = false
      -- entity.rotatable = false

      local ghostScanner = {}
      ghostScanner.ID = entity.unit_number
      ghostScanner.entity = entity
      global.GhostScanners[#global.GhostScanners+1] = ghostScanner

      UpdateEventHandlers()
    end

  end

end

function RemoveSensor(id)
  for i=#global.GhostScanners, 1, -1 do
    if id == global.GhostScanners[i].ID then
      table.remove(global.GhostScanners,i)
    end
  end

  UpdateEventHandlers()
end

function OnEntityRemoved(event)
-- script.on_event({defines.events.on_pre_player_mined_item, defines.events.on_robot_pre_mined, defines.events.on_entity_died}, function(event)
  if event.entity.name == Scanner_Name then
    RemoveSensor(event.entity.unit_number)
  end
end
end

do -- tick handlers
function UpdateEventHandlers()
  -- unsubscribe tick handlers
  script.on_nth_tick(nil)
  script.on_event(defines.events.on_tick, nil)

  -- subcribe tick or nth_tick depending on number of scanners
  local entity_count = #global.GhostScanners
  if entity_count > 0 then
    local nth_tick = UpdateInterval / entity_count
    if nth_tick >= 2 then
      script.on_nth_tick(math.floor(nth_tick), OnNthTick)
      -- log("subscribed on_nth_tick = "..math.floor(nth_tick))
    else
      script.on_event(defines.events.on_tick, OnTick)
      -- log("subscribed on_tick")
    end

    script.on_event({defines.events.on_pre_player_mined_item, defines.events.on_robot_pre_mined, defines.events.on_entity_died}, OnEntityRemoved)
  else  -- all sensors removed
    script.on_event({defines.events.on_pre_player_mined_item, defines.events.on_robot_pre_mined, defines.events.on_entity_died}, nil)
  end
end

-- runs when #global.GhostScanners > UpdateInterval/2
function OnTick(event)
  local offset = event.tick % UpdateInterval
  for i=#global.GhostScanners - offset, 1, -1 * UpdateInterval do
    -- log( event.tick.." updating entity["..i.."]" )
    UpdateSensor(global.GhostScanners[i])
  end
end

-- runs when #global.GhostScanners <= UpdateInterval/2
function OnNthTick(NthTickEvent)
  if global.UpdateIndex > #global.GhostScanners then
    global.UpdateIndex = 1
  end

  -- log( NthTickEvent.tick.." updating entity["..global.UpdateIndex.."]" )
  UpdateSensor(global.GhostScanners[global.UpdateIndex])

  global.UpdateIndex = global.UpdateIndex + 1
end

end



---- update Sensor ----
do
local signals
local signal_indexes

local function get_items_to_place(prototype)
  if ShowHidden then
    global.Lookup_items_to_place_this[prototype.name] = prototype.items_to_place_this
  else
    -- filter items flagged as hidden
    local items_to_place_filtered = {}
    for _, v in pairs (prototype.items_to_place_this) do
      local item = v.name and game.item_prototypes[v.name]
      if item and item.has_flag("hidden") == false then
        items_to_place_filtered[#items_to_place_filtered+1] = v
      end
    end
    global.Lookup_items_to_place_this[prototype.name] = items_to_place_filtered
  end
  return global.Lookup_items_to_place_this[prototype.name]
end

local function add_signal(name, count)
  local signal_index = signal_indexes[name]
  local s
  if signal_index then
    s = signals[signal_index]
  else
    signal_index = #signals+1
    signal_indexes[name] = signal_index
    s = { signal = { type = "item", name = name }, count = 0, index = (signal_index) }
    signals[signal_index] = s
  end

  if InvertSign then
    s.count = s.count - count
  else
    s.count = s.count + count
  end
end

local function is_in_bbox(pos, area)
  if pos.x >= area.left_top.x and pos.x <= area.right_bottom.x
  and pos.y >= area.left_top.y and pos.y <= area.right_bottom.y then
    return true
  end
  return false
end

--- returns ghost requested items as signals or nil
local function get_ghosts_as_signals(logsiticNetwork)
  if not (logsiticNetwork and logsiticNetwork.valid) then
    return nil
  end

  local result_limit = MaxResults

  local search_areas = {}
  local found_entities ={} -- store found unit_numbers to prevent duplicate entries
  signals = {}
  signal_indexes = {}

  -- logistic networks don't have an id outside the gui, show the number of cells (roboports) to match the gui
  if ShowCellCount then
    signals[1] = { signal = { type = "virtual", name = "ghost-scanner-cell-count" }, count = table_size(logsiticNetwork.cells), index = (1) }
  end

  for _,cell in pairs(logsiticNetwork.cells) do
    local pos = cell.owner.position
    local r = cell.construction_radius
    if r > 0 then
      local bounds = {
        left_top={ x=pos.x-r, y=pos.y-r, },
        right_bottom={ x=pos.x+r, y=pos.y+r }
      }
      local inner_bounds = { -- hack to skip checking if position is inside bounds for tiles
        left_top={ x=pos.x-r+0.001, y=pos.y-r+0.001, },
        right_bottom={ x=pos.x+r-0.001, y=pos.y+r-0.001 }
      }
      search_areas[#search_areas+1] = {
        bounds=bounds,
        inner_bounds=inner_bounds,
        force=logsiticNetwork.force,
        surface=cell.owner.surface
      }
    end
  end

  -- cliffs
  for _, search_area in pairs(search_areas) do
    local entities = search_area.surface.find_entities_filtered{area=search_area.inner_bounds, limit=result_limit, type="cliff"}
    local count_unique_entities = 0
    for _, e in pairs(entities) do
      local uid = e.unit_number or e.position
      if not found_entities[uid] and e.to_be_deconstructed() and e.prototype.cliff_explosive_prototype then
        found_entities[uid] = true
        add_signal(e.prototype.cliff_explosive_prototype, 1)
        count_unique_entities = count_unique_entities + 1
      end
    end
    if MaxResults then
      result_limit = result_limit - count_unique_entities
      if result_limit <= 0 then break end
    end
  end

  -- upgrade requests (requires 0.17.69)
  if MaxResults == nil or result_limit > 0 then
    for _, search_area in pairs(search_areas) do
      local entities = search_area.surface.find_entities_filtered{area=search_area.bounds, limit=result_limit, to_be_upgraded=true, force=search_area.force}
      local count_unique_entities = 0
      for _, e in pairs(entities) do
        local uid = e.unit_number
        local upgrade_prototype = e.get_upgrade_target()
        if not found_entities[uid] and upgrade_prototype then
          found_entities[uid] = true
          if is_in_bbox(e.position, search_area.bounds) then
            for _, item_stack in pairs(
              global.Lookup_items_to_place_this[upgrade_prototype.name] or
              get_items_to_place(upgrade_prototype)
            ) do
              add_signal(item_stack.name, item_stack.count)
              count_unique_entities = count_unique_entities + item_stack.count
            end
          end
        end
      end
      -- log("found "..tostring(count_unique_entities).."/"..tostring(result_limit).." upgrade requests." )
      if MaxResults then
        result_limit = result_limit - count_unique_entities
        if result_limit <= 0 then break end
      end
    end
  end

  -- entity-ghost knows items_to_place_this and item_requests (modules)
  if MaxResults == nil or result_limit > 0 then
    for _, search_area in pairs(search_areas) do
      local entities = search_area.surface.find_entities_filtered{area=search_area.bounds, limit=result_limit, type="entity-ghost", force=search_area.force}
      local count_unique_entities = 0
      for _, e in pairs(entities) do
        local uid = e.unit_number
        if not found_entities[uid] then
          found_entities[uid] = true
          if is_in_bbox(e.position, search_area.bounds) then
            for _, item_stack in pairs(
              global.Lookup_items_to_place_this[e.ghost_name] or
              get_items_to_place(e.ghost_prototype)
            ) do
              add_signal(item_stack.name, item_stack.count)
              count_unique_entities = count_unique_entities + item_stack.count
            end

            for request_item, count in pairs(e.item_requests) do
              add_signal(request_item, count)
              count_unique_entities = count_unique_entities + count
            end
          end
        end
      end
      -- log("found "..tostring(count_unique_entities).."/"..tostring(result_limit).." ghosts." )
      if MaxResults then
        result_limit = result_limit - count_unique_entities
        if result_limit <= 0 then break end
      end
    end
  end

  -- item-request-proxy holds item_requests (modules) for built entities
  if MaxResults == nil or result_limit > 0 then
    for _, search_area in pairs(search_areas) do
      local entities = search_area.surface.find_entities_filtered{area=search_area.inner_bounds, limit=result_limit, type="item-request-proxy", force=search_area.force}
      local count_unique_entities = 0
      for _, e in pairs(entities) do
        local uid = script.register_on_entity_destroyed(e) -- abuse on_entity_destroyed to generate ids directly for proxies
        if not found_entities[uid] then
          found_entities[uid] = true
          for request_item, count in pairs(e.item_requests) do
            add_signal(request_item, count)
            count_unique_entities = count_unique_entities + count
          end
        end
      end
      -- log("found "..tostring(count_unique_entities).."/"..tostring(result_limit).." request proxies." )
      if MaxResults then
        result_limit = result_limit - count_unique_entities
        if result_limit <= 0 then break end
      end
    end
  end

  -- tile-ghost knows only items_to_place_this
  if MaxResults == nil or result_limit > 0 then
    for _, search_area in pairs(search_areas) do
      local entities = search_area.surface.find_entities_filtered{area=search_area.inner_bounds, limit=result_limit, type="tile-ghost", force=search_area.force}
      local count_unique_entities = 0
      for _, e in pairs(entities) do
        local uid = e.unit_number
        if not found_entities[uid] then
          found_entities[uid] = true
          for _, item_stack in pairs(
            global.Lookup_items_to_place_this[e.ghost_name] or
            get_items_to_place(e.ghost_prototype)
          ) do
            add_signal(item_stack.name, item_stack.count)
            count_unique_entities = count_unique_entities + item_stack.count
          end
        end
      end
      -- log("found "..tostring(count_unique_entities).."/"..tostring(result_limit).." tile-ghosts." )
      if MaxResults then
        result_limit = result_limit - count_unique_entities
        if result_limit <= 0 then break end
      end
    end
  end

  -- round signals to next stack size
  -- signal = { type = "item", name = name }, count = 0, index = (signal_index)
  if RoundToStack then
    local round = math.ceil
    if InvertSign then round = math.floor end

    for _, signal in pairs(signals) do
      local prototype = game.item_prototypes[signal.signal.name]
      if prototype then
        local stack_size = prototype.stack_size
        signal.count = round(signal.count / stack_size) * stack_size
      end
    end
  end

  return signals
end

function UpdateSensor(ghostScanner)
  -- handle invalidated sensors
  if not ghostScanner.entity.valid then
    RemoveSensor(ghostScanner.ID)
    return
  end

  -- skip scanner if disabled
  if not ghostScanner.entity.get_control_behavior().enabled then
    ghostScanner.entity.get_control_behavior().parameters = nil
    return
  end

  -- storing logistic network becomes problematic when roboports run out of energy
  local logisticNetwork = ghostScanner.entity.surface.find_logistic_network_by_position(ghostScanner.entity.position, ghostScanner.entity.force )
  if not logisticNetwork then
    ghostScanner.entity.get_control_behavior().parameters = nil
    return
  end

  -- set signals
  local signals = get_ghosts_as_signals(logisticNetwork)
  if not signals then
    ghostScanner.entity.get_control_behavior().parameters = nil
    return
  end
  ghostScanner.entity.get_control_behavior().parameters = signals
end

end


---- INIT ----
do
local function init_events()
  script.on_event({
    defines.events.on_built_entity,
    defines.events.on_robot_built_entity,
    defines.events.script_raised_built,
    defines.events.script_raised_revive,
  }, OnEntityCreated)
  if global.GhostScanners then
    UpdateEventHandlers()
  end
end

script.on_load(function()
  init_events()
end)

script.on_init(function()
  global.GhostScanners = global.GhostScanners or {}
  global.UpdateIndex = global.UpdateIndex or 1
  global.Lookup_items_to_place_this = {}
  init_events()
end)

script.on_configuration_changed(function(data)
  global.GhostScanners = global.GhostScanners or {}
  global.UpdateIndex = global.UpdateIndex or 1
  global.Lookup_items_to_place_this = {}
  init_events()
end)

end
