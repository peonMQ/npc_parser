local mq = require 'mq'
local packageMan = require 'mq/packageman'
local fileUtil = require 'utils/file'

local sqlite3 = packageMan.Require('lsqlite3')

local configDir = (mq.configDir.."/"):gsub("\\", "/"):gsub("%s+", "%%20")
local serverName = mq.TLO.MacroQuest.Server()
fileUtil.EnsurePathExists(configDir..serverName.."/data")
local dbFileName = configDir..serverName.."/data/npc_recorder.db"
local connectingString = string.format("file:///%s?cache=shared&mode=rwc&_journal_mode=WAL", dbFileName)
local db = sqlite3.open(connectingString, sqlite3.OPEN_READWRITE + sqlite3.OPEN_CREATE + sqlite3.OPEN_URI)

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

db:exec[[
  PRAGMA journal_mode=WAL;
  CREATE TABLE IF NOT EXISTS dialogue_log_error (
      id INTEGER PRIMARY KEY
      , npc_id INTEGER
      , npc_name TEXT
      , npc_cleanname TEXT
      , x INTEGER
      , y INTEGER
      , z INTEGER
      , zone_id INTEGER
      , zone_name TEXT
      , message TEXT
      , timestamp INTEGER
  );
]]

local dialogue_log = {
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
  insert = function(npc_id, npc_name, npc_cleanname,x, y, z, zone_id, zone_name, keyword, message)
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
}

local dialogue_log_error = {
  ---@param npc_id integer
  ---@param npc_name string
  ---@param npc_cleanname string
  ---@param x integer
  ---@param y integer
  ---@param z integer
  ---@param zone_id integer
  ---@param zone_name string
  ---@param message string
  insert = function(npc_id, npc_name, npc_cleanname,x, y, z, zone_id, zone_name, message)
    local insertStatement = string.format("INSERT INTO dialogue_log_error(npc_id, npc_name, npc_cleanname,x, y, z, zone_id, zone_name, message, timestamp) VALUES( %d, '%s', '%s', %d, %d, %d, %d, '%s', '%s', %d)", npc_id, npc_name, npc_cleanname,x, y, z, zone_id, zone_name, message, os.time())
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
}

return {
  dialogue_log = dialogue_log,
  dialogue_log_error = dialogue_log_error
}