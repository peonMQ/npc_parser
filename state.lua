local mq = require 'mq'
local logger = require 'utils/logging'
local luapaths = require('utils/lua-paths')

local constants = require 'constants'

local state = {
  isActive = nil,
  recordType = constants.RecordTypes.Active,
  currentKeyword = nil,
  radius = 0,
  keywords = {},
  zoneKeywords = {},
  zoneSpawns = {},
  activePID = nil
}

---@type RunningDir
local runningDir = luapaths.RunningDir:new()
local path = mq.luaDir..'/'..runningDir:RelativeToMQLuaPath()..'zone_files/'..mq.TLO.Zone.ShortName()..'.lua'
logger.Debug("Attempting to read zone keyword file from <%s>", path)
local configData, err = loadfile(path)
if configData then
  logger.Debug("Attemtping to load config file")
  state.zoneKeywords = configData()
end

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
  for _, keyword in ipairs(state.zoneKeywords) do
    table.insert(state.keywords, keyword)
  end
end

state.init = function(radius)
  if radius and radius > 0 and radius < 10000 then
    state.zoneSpawns = mq.getFilteredSpawns(function (spawn)
        return spawn.Type() == "NPC" and spawn.Aggressive() == false and spawn.Body() ~= "Construct" and spawn.Distance() < radius
      end)
  else
    state.zoneSpawns = mq.getFilteredSpawns(function (spawn)
        return spawn.Type() == "NPC" and spawn.Aggressive() == false and spawn.Body() ~= "Construct"
      end)
  end
end

return state