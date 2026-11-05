local _, addon = ...

-- constants
local COPPER_AMOUNT_SYMBOL = COPPER_AMOUNT_SYMBOL
local CURRENT_DB_VERSION = 2
local DEFAULT = DEFAULT
local GOLD_AMOUNT_SYMBOL = GOLD_AMOUNT_SYMBOL
local LibStub = LibStub
local SILVER_AMOUNT_SYMBOL = SILVER_AMOUNT_SYMBOL

local isStandard = WOW_PROJECT_ID == WOW_PROJECT_MAINLINE

-- Lua functions
local floor = floor
local format = format
local FormatLargeNumber = FormatLargeNumber
local GetItemInfo = C_Item.GetItemInfo
local GetItemInfoInstant = C_Item.GetItemInfoInstant
local GetTime = GetTime
local InCombatLockdown = InCombatLockdown
local pairs = pairs
local pcall = pcall
local select = select
local strlower = strlower
local strmatch = strmatch
local strsub = strsub
local strtrim = strtrim
local tonumber = tonumber
local tostring = tostring
local type = type
local UnitAffectingCombat = UnitAffectingCombat
local wipe = wipe

-- ChatThrottleLib is bundled and loaded before this file.
local CTL = ChatThrottleLib
local SendBattleNetWhisper = C_BattleNet and C_BattleNet.SendWhisper or BNSendWhisper

-- addon creation
---@class PriceAnswer: AceAddon, AceConsole-3.0, AceEvent-3.0, LibAboutPanel-2.0
---@field db AceDBObject-3.0!
local PriceAnswer = LibStub("AceAddon-3.0"):NewAddon("PriceAnswer", "AceConsole-3.0", "AceEvent-3.0", "LibAboutPanel-2.0")
addon.PriceAnswer = PriceAnswer
local L = LibStub("AceLocale-3.0"):GetLocale("PriceAnswer")

local defaults = {
	profile = {
		enableAddOn = true,
		formatLargeNumbers = true,
		disableInCombat = true,
		trigger = "price",
		replyChannel = {
			["*"] = "WHISPER"
		},
		tsmSources = {
			["*"] = true
		},
		watchedChatChannels = {
			["*"] = true
		}
	},
	global = {}
}

-- locals
local db
local player_name = UnitName("player")
local PriceAnswerSentMessages = {}

-- attempt to resolve a valid itemID from a value (link, ID, or name)
local function tryGetItemID(val)
	if not val then
		return nil
	end

	local value = tostring(val)
	if strtrim(value) == "" then
		return nil
	end

	-- val may be an itemLink or item name, attempt to get a valid itemID from it
	local ok, result = pcall(GetItemInfoInstant, value)
	if ok and type(result) == "number" then
		return result
	end

	-- val may be an itemID passed in as a string or number, attempt to get a valid itemID from it
	local itemID = tonumber(value) or tonumber(strmatch(value, "^i:(%d+)$"))
	if itemID then
		ok, result = pcall(GetItemInfoInstant, itemID)
		if ok and type(result) == "number" then
			return result
		end
	end

	-- fallback: resolve item name via C_Item.GetItemInfo (requires cache), extract itemID from itemLink
	local ok2, _, itemLink = pcall(GetItemInfo, value)
	if ok2 and type(itemLink) == "string" then
		local itemIDFromLink = itemLink:match("item:(%d+)")
		if itemIDFromLink then
			return tonumber(itemIDFromLink)
		end
	end

	-- failed to get a valid itemID from val
	return nil
end

-- ensures itemCount is a valid number, rounds it to the nearest whole integer using standard rounding rules
-- (>= 0.5 rounds up, < 0.5 rounds down), and guarantees the result is at least 1
-- returns the rounded integer value or 1 if the input is invalid or less than 1 after rounding
local function TrueRound(itemCount)
	local n = tonumber(itemCount)

	if not n or n ~= n or n == math.huge then
		return 1
	end

	local rounded = floor(n + 0.5)

	if (not rounded) or (rounded < 1) then
		return 1
	end

	return rounded
end

local function GetActiveTrigger()
	return db.trigger == "price" and L["price"] or db.trigger
end

-- events
local events = {
	["CHAT_MSG_CHANNEL"] = true,
	["CHAT_MSG_SAY"] = true,
	["CHAT_MSG_YELL"] = true,
	["CHAT_MSG_GUILD"] = true,
	["CHAT_MSG_OFFICER"] = true,
	["CHAT_MSG_PARTY"] = true,
	["CHAT_MSG_RAID"] = true,
	["CHAT_MSG_WHISPER"] = true,
	["CHAT_MSG_BN_WHISPER"] = true,
	["CHAT_MSG_RAID_WARNING"] = true,
	["CHAT_MSG_INSTANCE_CHAT"] = true,
	["CHAT_MSG_COMMUNITIES_CHANNEL"] = isStandard
}

-- init
function PriceAnswer:OnInitialize()
	-- set up the database and config
	self.db = LibStub("AceDB-3.0"):New("PriceAnswerDB", defaults, true)
	self.db.RegisterCallback(self, "OnProfileChanged", "RefreshConfig")
	self.db.RegisterCallback(self, "OnProfileCopied", "RefreshConfig")
	self.db.RegisterCallback(self, "OnProfileReset", "RefreshConfig")

	-- if the current_db_version is less than the CURRENT_DB_VERSION, reset the database to defaults and show a popup message to the user
	local oldVersion = self.db.global.current_db_version
	if (not oldVersion) or (oldVersion < CURRENT_DB_VERSION) then
		StaticPopupDialogs["PRICEANSWER_RESET"] = {
			text = L["Price Answer has been updated. The settings have been reset to defaults."],
			button1 = ACCEPT,
			timeout = 0,
			whileDead = true,
			hideOnEscape = true
		}
		StaticPopup_Show("PRICEANSWER_RESET")
		self.db:ResetDB(DEFAULT)
	end

	self.db.global.current_db_version = CURRENT_DB_VERSION
	db = self.db.profile
	self:SetEnabledState(db.enableAddOn)

	-- set up the options menu
	local options = self:GetOptions()
	options.args.profiles = LibStub("AceDBOptions-3.0"):GetOptionsTable(self.db)
	options.args.aboutTable = self:AboutOptionsTable("PriceAnswer")

	LibStub("AceConfig-3.0"):RegisterOptionsTable("PriceAnswer", options)
	LibStub("AceConfigDialog-3.0"):AddToBlizOptions("PriceAnswer", L["Price Answer"])

	self:RegisterChatCommand("priceanswer", "ChatCommand")
	self:RegisterChatCommand("prans", "ChatCommand")
end

function PriceAnswer:OnEnable()
	for event in pairs(events) do
		if (events[event]) and (db.watchedChatChannels[event]) then
			self:RegisterEvent(event, "HandleChatEvent")
		end
	end
end

function PriceAnswer:OnDisable()
	self:UnregisterAllEvents()
	wipe(PriceAnswerSentMessages)
end

function PriceAnswer:RefreshConfig()
	db = self.db.profile
	wipe(PriceAnswerSentMessages)
	self:UnregisterAllEvents()
	if db.enableAddOn then
		if self:IsEnabled() then self:OnEnable() else self:Enable() end
	else
		self:Disable()
	end
end

function PriceAnswer:ChatCommand()
	LibStub("AceConfigDialog-3.0"):Open("PriceAnswer")
end

--[[ MAIN LOGIC]]
-- Step 1: Listen for chat messages in the appropriate channels and check if they start with the trigger word. If not, ignore them. If they do, continue to step 2.
function PriceAnswer:HandleChatEvent(event, ...)
	if (db.disableInCombat and (InCombatLockdown() or UnitAffectingCombat("player"))) then
		return
	end

	-- clean up old entries from PriceAnswerSentMessages
	local now = GetTime()
	for hash, timestamp in pairs(PriceAnswerSentMessages) do
		if now - timestamp >= 15 then
			PriceAnswerSentMessages[hash] = nil
		end
	end

	local msg, sender = ...
	if not msg or not sender then return end

	local trigger = GetActiveTrigger()
	local triggerLower = strlower(trigger)
	if strlower(strsub(msg, 1, #trigger)) ~= triggerLower then return end

	-- prevent message loops and duplicate processing:
	-- 1. ignore messages that match ones recently sent by this addon (prevents responding to our own output)
	-- 2. ignore messages already processed from the same sender (prevents duplicate replies and echo loops)
	if msg and msg ~= "" then
		local self_hash = msg .. "::" .. player_name
		if PriceAnswerSentMessages[self_hash] then return end
	end
	local hash = msg .. "::" .. sender
	if PriceAnswerSentMessages[hash] then return end

	for _, message in ipairs(self:GetOutgoingMessage(msg)) do
		self:SendResponse(event, message, sender, ...)
	end
	PriceAnswerSentMessages[hash] = now
end

-- Resolve input without relying on TSM's item parser. Preserve full links for
-- providers that distinguish equipment variants by level or bonus IDs.
function PriceAnswer:GetOutgoingMessage(incomingMessage)
	local trigger = GetActiveTrigger()
	local input = strtrim(strsub(incomingMessage, #trigger + 1))
	if input == "" then return {} end
	local quantity, item = strmatch(input, "^(%d+)%s*(.+)$")
	if tonumber(input) then
		quantity, item = 1, input
	elseif not item then
		quantity, item = 1, input
	end
	quantity = TrueRound(quantity)
	local itemID = tryGetItemID(item)
	if not itemID or not item then return {} end
	local _, cachedLink = GetItemInfo(item)
	local itemLink = strmatch(item, "|Hitem:") and item or cachedLink
	local itemString = "i:" .. tostring(itemID)

	local messages, message = {}, ""
	for _, price in ipairs(self:GetPrices(itemID, itemLink, itemString)) do
		local amount = self:ConvertToHumanReadable(floor(price.value * quantity + 0.5))
		if amount then
			local field = price.label .. " (" .. price.provider .. "): " .. amount
			-- ChatThrottleLib enforces the game's 255-byte limit. Keep fields
			-- together where possible and never cut a UTF-8 character in half.
			if message ~= "" and #message + #field + 1 > 255 then
				messages[#messages + 1], message = message, ""
			end
			while #field > 255 do
				local boundary = 256
				while string.byte(field, boundary) >= 128 and string.byte(field, boundary) < 192 do
					boundary = boundary - 1
				end
				messages[#messages + 1] = strsub(field, 1, boundary - 1)
				field = strsub(field, boundary)
			end
			message = message == "" and field or message .. " " .. field
		end
	end
	if message ~= "" then messages[#messages + 1] = message end
	return messages
end

-- Convert copper to a plain-text amount suitable for chat.
function PriceAnswer:ConvertToHumanReadable(num_copper)
	local gold_string, silver_string, copper_string = "", "", ""
	local gold, silver, copper

	if (num_copper and num_copper >= 1 and num_copper < math.huge) then
		gold = floor(num_copper / 10000)
		silver = floor(num_copper / 100) % 100
		copper = num_copper % 100

		if gold >= 1 then
			if db.formatLargeNumbers then
				gold = FormatLargeNumber(gold)
				gold_string = format("%s" .. GOLD_AMOUNT_SYMBOL, gold)
			else
				gold_string = format("%d" .. GOLD_AMOUNT_SYMBOL, gold)
			end
		end
		if silver >= 1 then
			silver_string = format("%d" .. SILVER_AMOUNT_SYMBOL, silver)
		end
		if copper >= 1 then
			copper_string = format("%d" .. COPPER_AMOUNT_SYMBOL, copper)
		end

		return gold_string .. silver_string .. copper_string
	end
	return nil
end

-- Send replies to the configured channel.
function PriceAnswer:SendResponse(event, msg, target, ...)
	if (db.disableInCombat and (InCombatLockdown() or UnitAffectingCombat("player"))) then
		return
	end

	local channel = db.replyChannel[event] or "WHISPER"

	local hash = msg .. "::" .. player_name
	PriceAnswerSentMessages[hash] = GetTime()

	if event == "CHAT_MSG_BN_WHISPER" then
		local id = select(13, ...)
		SendBattleNetWhisper(id, msg)
	else
		CTL:SendChatMessage("NORMAL", "PriceAnswer", msg, channel, nil, channel == "WHISPER" and target or nil)
	end
end