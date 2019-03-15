-- constant prototypes names
local SENSOR = "ghost-scanner"
local Item_count_lookup = {}

---- MOD SETTINGS ----

local UpdateInterval = settings.global["ghost-scanner_update_interval"].value
local MaxResults = settings.global["ghost-scanner_max_results"].value
if MaxResults == 0 then MaxResults = nil end
local InvertSign = settings.global["ghost-scanner-negative-output"].value

script.on_event(defines.events.on_runtime_mod_setting_changed, function(event)
  if event.setting == "ghost-scanner_update_interval" then
    UpdateInterval = settings.global["ghost-scanner_update_interval"].value
    UpdateEventHandlers()
  end
  if event.setting == "ghost-scanner_max_results" then
    MaxResults = settings.global["ghost-scanner_max_results"].value
    if MaxResults == 0 then MaxResults = nil end
  end
  if event.setting == "ghost-scanner-negative-output" then
    InvertSign = settings.global["ghost-scanner-negative-output"].value
  end
end)


---- EVENTS ----

do -- create & remove
function OnEntityCreated(event)
	if (event.created_entity.name == SENSOR) then
    local entity = event.created_entity
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
	if event.entity.name == SENSOR then
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

--- returns ghost requested items as signals or nil
local function get_ghosts_as_signals(logsiticNetwork)
  if not (logsiticNetwork and logsiticNetwork.valid) then
    return nil
  end

  local result_limit = MaxResults
  
  local found_entities ={} -- store found unit_numbers to prevent duplicate entries
  signals = {}
  signal_indexes = {}

  for _,cell in pairs(logsiticNetwork.cells) do
    local pos = cell.owner.position
    local r = cell.construction_radius
    if r > 0 then
      local bounds = { { pos.x - r, pos.y - r, }, { pos.x + r, pos.y + r } }      
      -- finding each entity by itself is slightly (0.008ms) faster than finding all and selecting later
      local entities = cell.owner.surface.find_entities_filtered{area=bounds, limit=result_limit, type="item-request-proxy", force=logsiticNetwork.force}
      local count_unique_entities = 0
      for _, e in pairs(entities) do
        -- item-request-proxy holds item_requests (modules) for built entities
        local uid = e.proxy_target.unit_number
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

      local entities = cell.owner.surface.find_entities_filtered{area=bounds, limit=result_limit, type="entity-ghost", force=logsiticNetwork.force}
      local count_unique_entities = 0
      for _, e in pairs(entities) do
        -- entity-ghost knows items_to_place_this and item_requests (modules)
        local uid = e.unit_number
        if not found_entities[uid] then
          found_entities[uid] = true

          -- for item_name, item_prototype in pairs(e.ghost_prototype.items_to_place_this) do
          for _, item_stack in pairs(e.ghost_prototype.items_to_place_this) do  
            add_signal(item_stack.name, item_stack.count)
            count_unique_entities = count_unique_entities + item_stack.count
          end

          for request_item, count in pairs(e.item_requests) do
            add_signal(request_item, count)
            count_unique_entities = count_unique_entities + count
          end
        end
      end
      -- log("found "..tostring(count_unique_entities).."/"..tostring(result_limit).." ghosts." ) 
      if MaxResults then         
        result_limit = result_limit - count_unique_entities
        if result_limit <= 0 then break end
      end

      local entities = cell.owner.surface.find_entities_filtered{area=bounds, limit=result_limit, type="tile-ghost", force=logsiticNetwork.force}
      local count_unique_entities = 0
      for _, e in pairs(entities) do
        -- tile-ghost knows only items_to_place_this
        local uid = e.unit_number
        if not found_entities[uid] then
          found_entities[uid] = true

          -- add_signal(next(e.ghost_prototype.items_to_place_this), 1)
          for _, item_stack in pairs(e.ghost_prototype.items_to_place_this) do
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
  end -- for logsiticNetwork.cells

  return signals
end

function UpdateSensor(ghostScanner)
  -- handle invalidated sensors
  if not ghostScanner.entity.valid then
    RemoveSensor(ghostScanner.ID)
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
  ghostScanner.entity.get_control_behavior().parameters = {parameters=signals}
end

end


---- INIT ----
do
local function init_events()
	script.on_event({defines.events.on_built_entity, defines.events.on_robot_built_entity}, OnEntityCreated)
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
  init_events()
end)

script.on_configuration_changed(function(data)
  global.GhostScanners = global.GhostScanners or {}
  global.UpdateIndex = global.UpdateIndex or 1
  init_events()
end)

end
