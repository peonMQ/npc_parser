local mq = require 'mq'

local zoneSpawns = mq.getFilteredSpawns(function (spawn)
  return spawn.Type() == "NPC" and spawn.Aggressive() == false and spawn.Body() ~= "Construct"
end)

local state = {
  currentKeyword = nil,
  keywords = {},
  zoneSpawns = zoneSpawns
}

local function removeSpawn(removeSpawn)
  local newZoneSpawns = {}
  for _, spawn in ipairs(state.zoneSpawns) do
    if spawn.ID() ~= removeSpawn.ID() then
      table.insert(newZoneSpawns, spawn)
    end
  end

  state.zoneSpawns = newZoneSpawns
end

state.popNearestSpawn = function()
  local nearest = nil
  for _, spawn in ipairs(state.zoneSpawns) do
    if not nearest or (spawn() and spawn.Distance3D() < nearest.Distance3D()) then
      nearest = spawn
    end
  end

  removeSpawn(nearest)
  return nearest
end

state.popKeyword = function()
  local keyword = table.remove(state.keywords)
  state.currentKeyword = keyword
  return keyword
end

state.cleanNils = function()
  local newZoneSpawns = {}
  for _, spawn in ipairs(state.zoneSpawns) do
    if spawn() then
      table.insert(newZoneSpawns, spawn)
    end
  end

  state.zoneSpawns = newZoneSpawns
end

state.resetKeywords = function()
  state.keywords = {}
  state.currentKeyword = nil
end

return state