local mq = require 'mq'
local logger = require 'utils/logging'
local debugUtils = require 'utils/debug'
local mqevent = require('mqevent')
local state = require('state')
local repository = require('repository')

---@param line string
---@param spawn spawn
local function parseLine(line, spawn)
  logger.Info("%s <%s>", line, spawn())
  if spawn() then
    repository.dialogue_log.insert(spawn.ID(), spawn.Name(), spawn.CleanName(), spawn.X(), spawn.Y(), spawn.Z(), mq.TLO.Zone.ID(), mq.TLO.Zone.ShortName(), state.currentKeyword, line:gsub("'", "''"))
  end
end

state.init(500)
for _, npcSpawn in ipairs(state.zoneSpawns) do
  local npcLoggerEvent = mqevent:new(npcSpawn.ID().."_event", npcSpawn.CleanName().." #*#", function (line) parseLine(line, npcSpawn) end)
  npcLoggerEvent:Register()
end
logger.Debug("Created listening events.")

logger.Debug("Listening...")
while true do
  while true do
    mq.doevents()
  end
end