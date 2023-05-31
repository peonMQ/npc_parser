--- @type ImGui
local imgui = require 'ImGui'
local mq = require 'mq'
local icons = require 'mq/icons'
local logger = require 'utils/logging'
local plugins = require 'utils/plugins'
local luapaths = require 'utils/lua-paths'
local luaUtils = require('utils/lua-table')

local mqevent = require 'mqevent'
local constants = require 'constants'
local state = require 'state'

-- GUI Control variables
local isOpen, shouldDraw = true, true
local terminate = false
local buttonSize = ImVec2(30, 30)
local windowFlags = bit32.bor(ImGuiWindowFlags.NoDocking, ImGuiWindowFlags.AlwaysAutoResize)


---@type RunningDir
local runningDir = luapaths.RunningDir:new()
runningDir:AppendToPackagePath()
local activeRecorderScript = runningDir:GetRelativeToMQLuaPath("activeRecorder")
local passiveRecorderScript = runningDir:GetRelativeToMQLuaPath("passiveRecorder")

local function create(h, s, v)
  local r, g, b = imgui.ColorConvertHSVtoRGB(h / 7.0, s, v)
  return ImVec4(r, g, b, 1)
end

local greenButton = {
  default = create(2, 0.6, 0.6),
  hovered = create(2, 0.7, 0.7),
  active = create(2, 0.8, 0.8),
}

local redButton = {
  default = create(0, 0.6, 0.6),
  hovered = create(0, 0.7, 0.7),
  active = create(0, 0.8, 0.8),
}

local function createPlayButton(isDisabled)
  if not state.isActive then
    imgui.PushStyleColor(ImGuiCol.Button, redButton.default)
    imgui.PushStyleColor(ImGuiCol.ButtonHovered, greenButton.hovered)
    imgui.PushStyleColor(ImGuiCol.ButtonActive, greenButton.active)
    imgui.BeginDisabled(isDisabled)
    imgui.Button(icons.MD_PLAY_ARROW, buttonSize)
    imgui.EndDisabled()
  else
    imgui.PushStyleColor(ImGuiCol.Button, greenButton.default)
    imgui.PushStyleColor(ImGuiCol.ButtonHovered, redButton.hovered)
    imgui.PushStyleColor(ImGuiCol.ButtonActive, redButton.hovered)
    imgui.BeginDisabled(isDisabled)
    imgui.Button(icons.MD_STOP, buttonSize)
    imgui.EndDisabled()
  end

  if imgui.IsItemClicked(0) then
    if state.isActive then
      if state.recordType == constants.RecordTypes.Active then
        if plugins.IsLoaded("mq2nav") and mq.TLO.Navigation.Active() then
          mq.cmd("/nav stop")
        end
        local command = string.format('/lua stop %s', activeRecorderScript)
        mq.cmd(command)
      elseif state.recordType == constants.RecordTypes.Passive then
        local command = string.format('/lua stop %s', passiveRecorderScript)
        mq.cmd(command)
      end

      state.activePID = nil
    else
      if state.recordType == constants.RecordTypes.Active then
        local command = string.format('/lua run %s', activeRecorderScript)
        if state.radius < 0 then
          command = string.format('/lua run %s %d', activeRecorderScript, state.radius)
        end

        mq.cmd(command)
      elseif state.recordType == constants.RecordTypes.Passive then
        local command = string.format('/lua run %s', passiveRecorderScript)
        mq.cmd(command)
      end

      state.activePID = -1
    end

    state.isActive = not state.isActive
  end

  imgui.PopStyleColor(3)
end

local function actionbarUI()
  if not isOpen then return end

  isOpen, shouldDraw = imgui.Begin('NPC Text Recorder', isOpen, windowFlags)

  if shouldDraw then
    imgui.BeginDisabled(state.isActive or false)
    state.recordType,_ = imgui.RadioButton("Active", state.recordType, constants.RecordTypes.Active)
    imgui.SameLine()
    state.recordType,_ = imgui.RadioButton("Passive", state.recordType, constants.RecordTypes.Passive)
    if state.recordType == constants.RecordTypes.Active then
      state.radius, _ = imgui.SliderFloat("Radius", state.radius, 0, 10000)
    end

    imgui.EndDisabled()
    createPlayButton(false)
  end

  imgui.End()

  if not isOpen then
      terminate = true
  end
end

mq.imgui.init('ActionBar', actionbarUI)

local event = mqevent:new("runningscript", "Running lua script '#1#' with PID #2#", function (line, scriptName, scriptPID) if scriptName == activeRecorderScript or scriptName == passiveRecorderScript then state.activePID = tonumber(scriptPID) end end)
event:Register()

while not terminate do
  if state.isActive and state.activePID > 0 then
    state.isActive = false
    state.activePID = nil
  end
  logger.Debug("Were inside the terminate loop")
  mq.delay(500)
end