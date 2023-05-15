local mq = require 'mq'
local logger = require 'utils/logging'
local debugUtils = require 'utils/debug'
local plugins = require('utils/plugins')
local mqevent = require('mqevent')
local broadCastInterfaceFactory = require('broadcast/broadcastinterface')

local bci = broadCastInterfaceFactory()
if not bci then
  logger.Fatal("No networking interface found, please start eqbc or dannet")
  return
end

plugins.EnsureIsLoaded("mq2nav")

local zoneSpawns = {
  mq.TLO.Target
}

-- local zoneSpawns = mq.getFilteredSpawns(function (spawn)
--   logger.Debug(spawn())
--   print(spawn.Aggresive())
--   return spawn.Aggresive() == false
-- end)

local function getNearestSpawn()
  local nearest = nil
  for _, spawn in ipairs(zoneSpawns) do
    if not nearest or spawn.Distance3D() < nearest.Distance3D() then
      nearest = spawn
    end
  end

  return nearest
end

local function removeParsedNpc(removeSpawn)
  local newZoneSpawns = {}
  for _, spawn in ipairs(zoneSpawns) do
    if spawn.ID() ~= removeSpawn.ID() then
      table.insert(newZoneSpawns, spawn)
    end
  end

  zoneSpawns = newZoneSpawns
end


local keywords = {}

local function parseLine(line)
  logger.Info(line)
  for s in string.gmatch(line, "%[.-%]") do
    local keyword = string.format("/say %s", s:gsub("[%[%]]", ""))
    logger.Debug(keyword)
    table.insert(keywords, keyword)
  end
end


local function generateEvents(spawn)
  local logSay = mqevent:new(spawn.ID().."say", spawn.CleanName().." says #*#", function (line) parseLine(line) end)
  return {
    logSay,
  }
end


while next(zoneSpawns) do
  local nearest = getNearestSpawn()
  if nearest() then
    local navParam = string.format("id %s", nearest.ID())
    if(mq.TLO.Navigation.PathExists(navParam)) then
      mq.cmdf("/nav %s", navParam)
      mq.delay(100)
      while mq.TLO.Navigation.Active() do
        mq.delay(100)
      end
    else
      logger.Error("Unable to naviaget to NPC <%s>[%d]", nearest.Name(), nearest.ID())
    end

    local events = generateEvents(nearest)
    for _, event in ipairs(events) do
      event:Register()
    end

    mq.delay(100)

    mq.cmd("/hail")
    mq.delay(500)
    mq.doevents()
    mq.delay(500)

    repeat
      local keyword = table.remove(keywords)
      -- mq.cmd(keyword)
      mq.doevents()
      mq.delay(500)
    until not next(keywords)

    for _, event in ipairs(events) do
      event:UnRegister()
    end

    removeParsedNpc(nearest)
  end
end
