local mq = require 'mq'
local packageMan = require('mq/packageman')
local fileUtil = require('utils/file')
local logger = require 'utils/logging'
local debugUtils = require 'utils/debug'
local plugins = require('utils/plugins')
local mqevent = require('mqevent')
local broadCastInterfaceFactory = require('broadcast/broadcastinterface')

local sqlite3 = packageMan.Require('lsqlite3')

local bci = broadCastInterfaceFactory()
if not bci then
  logger.Fatal("No networking interface found, please start eqbc or dannet")
  return
end

local configDir = (mq.configDir.."/"):gsub("\\", "/"):gsub("%s+", "%%20")
local serverName = mq.TLO.MacroQuest.Server()
fileUtil.EnsurePathExists(configDir..serverName.."/data")
local dbFileName = configDir..serverName.."/data/npc_quest_parser.db"
local connectingString = string.format("file:///%s?cache=shared&mode=rwc&_journal_mode=WAL", dbFileName)
local db = sqlite3.open(connectingString, sqlite3.OPEN_READWRITE + sqlite3.OPEN_CREATE + sqlite3.OPEN_URI)

plugins.EnsureIsLoaded("mq2nav")

db:exec[[
  PRAGMA journal_mode=WAL;
  CREATE TABLE IF NOT EXISTS dialogue_log (
      id INTEGER PRIMARY KEY
      , npc_id INTEGER
      , npc_name TEXT
      , npc_cleanname TEXT
      , x INTEGER
      , y INTEGER
      , z INTEGER
      , zone_id INTEGER
      , zone_name TEXT
      , keyword TEXT
      , message TEXT
      , timestamp INTEGER
  );
]]

---@param npc_id integer
---@param npc_name string
---@param npc_cleanname string
---@param x integer
---@param y integer
---@param z integer
---@param zone_id integer
---@param zone_name string
---@param keyword string
---@param message string
local function insert(npc_id, npc_name, npc_cleanname,x, y, z, zone_id, zone_name, keyword, message)
  local insertStatement = string.format("INSERT INTO dialogue_log(npc_id, npc_name, npc_cleanname,x, y, z, zone_id, zone_name, keyword, message, timestamp) VALUES( %d, '%s', '%s', %d, %d, %d, %d, '%s', '%s', '%s', %d)", npc_id, npc_name, npc_cleanname,x, y, z, zone_id, zone_name, keyword, message, os.time())
  local retries = 0
  local result = db:exec(insertStatement)
  while result ~= 0 and retries < 20 do
    mq.delay(10)
    retries = retries + 1
    result = db:exec(insertStatement)
  end

  if result ~= 0 then
    print("Failed <"..insertStatement..">")
  end
end

local zoneSpawns = mq.getFilteredSpawns(function (spawn)
  return spawn.Type() == "NPC" and spawn.Aggressive() == false
end)

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

local currentKeyword = nil
local keywords = {}

local function parseLine(line)
  logger.Info(line)
  insert(mq.TLO.Target.ID(), mq.TLO.Target.Name(), mq.TLO.Target.CleanName(), mq.TLO.Target.X(), mq.TLO.Target.Y(), mq.TLO.Target.Z(), mq.TLO.Zone.ID(), mq.TLO.Zone.ShortName(), currentKeyword, line:gsub("'", "''"))
  for s in string.gmatch(line, "%[.-%]") do
    local keyword = s:gsub("[%[%]]", "")
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
  -- debugUtils.PrintTable(zoneSpawns)
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
    if ensureTarget(nearest.ID()) then
      currentKeyword = nil
      logger.Debug("Engaging conversion by /hail with <%s>", nearest.Name())
      mq.delay(500)
      mq.cmd("/hail")
      mq.delay(2000)
      mq.doevents()
      mq.delay(2000)

      while next(keywords) do
        local keyword = table.remove(keywords)
        currentKeyword = keyword
        logger.Debug(keyword)
        mq.cmd(string.format("/say %s", keyword))
        mq.delay(2000)
        mq.doevents()
        mq.delay(2000)
      end

      for _, event in ipairs(events) do
        event:UnRegister()
      end
    end

    removeParsedNpc(nearest)
  end
end
