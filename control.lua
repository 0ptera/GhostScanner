-- constant prototypes names
local SENSOR = "ghost-scanner"

---- MOD SETTINGS ----

local UpdateInterval = settings.global["ghost-scanner_update_interval"].value
local InvertSign = settings.global["ghost-scanner-negative-output"].value

script.on_event(defines.events.on_runtime_mod_setting_changed, function(event)
  if event.setting == "ghost-scanner_update_interval" then
    UpdateInterval = settings.global["ghost-scanner_update_interval"].value
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

    script.on_event(defines.events.on_tick, OnTick)
    script.on_event({defines.events.on_pre_player_mined_item, defines.events.on_robot_pre_mined, defines.events.on_entity_died}, OnEntityRemoved)
	end
end

function OnEntityRemoved(event)
-- script.on_event({defines.events.on_pre_player_mined_item, defines.events.on_robot_pre_mined, defines.events.on_entity_died}, function(event)
	if event.entity.name == SENSOR then
    for i=#global.GhostScanners, 1, -1 do
      if event.entity.unit_number == global.GhostScanners[i].ID then
        table.remove(global.GhostScanners,i)
      end
    end

		if #global.GhostScanners == 0 then
			script.on_event(defines.events.on_tick, nil)
			script.on_event({defines.events.on_pre_player_mined_item, defines.events.on_robot_pre_mined, defines.events.on_entity_died}, nil)
		end
	end
end
end

do -- onTick
local function UpdateSensor(ghostScanner)
  -- storing logistic network becomes problematic when roboports run out of energy
  local logisticNetwork = ghostScanner.entity.surface.find_logistic_network_by_position(ghostScanner.entity.position, ghostScanner.entity.force )
  if not logisticNetwork then
    ghostScanner.entity.get_control_behavior().parameters = nil
    return
  end

  local signals = Get_Ghost_Requests_as_Signals(logisticNetwork)
  if not signals then
    ghostScanner.entity.get_control_behavior().parameters = nil
    return
  end
  ghostScanner.entity.get_control_behavior().parameters = {parameters=signals}
end

function OnTick(event)
  local offset = event.tick % UpdateInterval
  for i=#global.GhostScanners - offset, 1, -1 * UpdateInterval do
    UpdateSensor(global.GhostScanners[i])
  end
end
end

---- LOGIC ----
do --create signals from ghosts
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
function Get_Ghost_Requests_as_Signals(logsiticNetwork)
  if not (logsiticNetwork and logsiticNetwork.valid) then
    return nil
  end

  local found_entities ={} -- store found unit_numbers to prevent duplicate entries
  signals = {}
  signal_indexes = {}

  for _,cell in pairs(logsiticNetwork.cells) do
    local pos = cell.owner.position
    local r = cell.construction_radius
    local bounds = { { pos.x - r, pos.y - r, }, { pos.x + r, pos.y + r } }

    -- finding each entity by itself is slightly (0.008ms) faster than finding all and selecting later
    local entities = cell.owner.surface.find_entities_filtered{area=bounds, type="entity-ghost", force=logsiticNetwork.force}
    for _, e in pairs(entities) do
      -- entity-ghost knows items_to_place_this and item_requests (modules)
      local uid = e.unit_number
      if not found_entities[uid] then
        found_entities[uid] = true
        add_signal(next(e.ghost_prototype.items_to_place_this), 1)
        for request_item, count in pairs(e.item_requests) do
            add_signal(request_item, count)
        end
      end
    end

    local entities = cell.owner.surface.find_entities_filtered{area=bounds, type="tile-ghost", force=logsiticNetwork.force}
    for _, e in pairs(entities) do
      -- tile-ghost knows only items_to_place_this
      local uid = e.unit_number
      if not found_entities[uid] then
        found_entities[uid] = true
        add_signal(next(e.ghost_prototype.items_to_place_this), 1)
      end
    end

    local entities = cell.owner.surface.find_entities_filtered{area=bounds, type="item-request-proxy", force=logsiticNetwork.force}
    for _, e in pairs(entities) do
      -- item-request-proxy holds item_requests (modules) for built entities
      local uid = e.proxy_target.unit_number
      if not found_entities[uid] then
        found_entities[uid] = true
        for request_item, count in pairs(e.item_requests) do
          add_signal(request_item, count)
        end
      end
    end

  end

  return signals
end

end


---- INIT ----
do
local function init_events()
	script.on_event({defines.events.on_built_entity, defines.events.on_robot_built_entity}, OnEntityCreated)
	if global.GhostScanners and #global.GhostScanners > 0 then
		script.on_event(defines.events.on_tick, OnTick)
		script.on_event({defines.events.on_pre_player_mined_item, defines.events.on_robot_pre_mined, defines.events.on_entity_died}, OnEntityRemoved)
	end
end

script.on_load(function()
  init_events()
end)

script.on_init(function()
  global.GhostScanners = global.GhostScanners or {}
  init_events()
end)

script.on_configuration_changed(function(data)
  global.GhostScanners = global.GhostScanners or {}
	init_events()
  log("[GS] on_config_changed complete.")
end)

end
