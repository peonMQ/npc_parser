local mq = require 'mq'
local logger = require 'utils/logging'
local debugUtils = require 'utils/debug'
local plugins = require 'utils/plugins'
local mqevent = require 'mqevent'
local state = require 'state'
local repository = require 'repository'

plugins.EnsureIsLoaded("mq2nav")

local args = {...}
local radius = nil
if next(args) then
  radius = tonumber(args[1])
  logger.Debug("Attempting to parse NPC's in a %d radius", radius)
else
  logger.Debug("Attempting to parse NPC's zonewide")
end

state.init(radius)

local function ensureTarget(targetId)
  if not targetId then
    logger.Debug("Invalid <targetId>")
    return false
  end

  if mq.TLO.Target.ID() ~= targetId then
    if mq.TLO.SpawnCount("id "..targetId)() > 0 then
      mq.cmdf("/mqtarget id %s", targetId)
      mq.delay("3s", function() return mq.TLO.Target.ID() == targetId end)
    else
      logger.Warn("EnsureTarget has no spawncount for target id <%d>", targetId)
    end
  end

  return mq.TLO.Target.ID() == targetId
end

local function parseLine(line, spawn)
  if spawn() then
    logger.Info("%s <%s>", line, spawn())
    repository.dialogue_log.insert(spawn.ID(), spawn.Name(), spawn.CleanName(), spawn.X(), spawn.Y(), spawn.Z(), mq.TLO.Zone.ID(), mq.TLO.Zone.ShortName(), state.currentKeyword, line:gsub("'", "''"))
    for s in string.gmatch(line, "%[.-%]") do
      local keyword = s:gsub("[%[%]]", "")
      logger.Debug("Found keyword <%s>", keyword)
      table.insert(state.keywords, keyword)
    end
  end
end


while next(state.zoneSpawns) do
  local nearest = state.popNearestSpawn()
  if nearest() then
    local navParam = string.format("id %s", nearest.ID())
    if(mq.TLO.Navigation.PathExists(navParam)) then
      mq.cmdf("/nav %s", navParam)
      mq.delay(100)
      while mq.TLO.Navigation.Active() do
        mq.delay(100)
      end
    else
      repository.dialogue_log_error.insert(nearest.ID(), nearest.Name(), nearest.CleanName(), nearest.X(), nearest.Y(), nearest.Z(), mq.TLO.Zone.ID(), mq.TLO.Zone.ShortName(), "Unable to naviaget to NPC")
      logger.Error("Unable to naviaget to NPC <%s>[%d]", nearest.Name(), nearest.ID())
    end

    local npcLoggerEvent = mqevent:new(nearest.ID().."_event", nearest.CleanName().." #*#", function (line) parseLine(line, nearest) end)
    npcLoggerEvent:Register()

    mq.delay(100)
    if ensureTarget(nearest.ID()) then
      state.resetKeywords()
      logger.Debug("Engaging conversion by /hail with <%s>", nearest.Name())
      mq.delay(500)
      mq.cmd("/hail")
      mq.delay(2000)
      mq.doevents()
      mq.delay(2000)

      while next(state.keywords) do
        local keyword = state.popKeyword()
        logger.Debug(keyword)
        mq.cmd(string.format("/say %s", keyword))
        mq.delay(2000)
        mq.doevents()
        mq.delay(2000)
      end
    end

    npcLoggerEvent:UnRegister()
  end

  state.cleanNils()
end
