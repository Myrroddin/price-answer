-- upvalue globals
local LibStub, pairs, GetItemInfoInstant, pcall = LibStub, pairs, C_Item.GetItemInfoInstant, pcall
local BNSendWhisper, wipe = BNSendWhisper, wipe -- note to self: BNSendWhisper will be replaced by C_BattleNet.SendWhisper in future WoW versions
local strtrim, strsub, strmatch, gsub = strtrim, strsub, strmatch, gsub
local select, InCombatLockdown, UnitAffectingCombat = select, InCombatLockdown, UnitAffectingCombat
local Settings, StaticPopupDialogs, StaticPopup_Show = Settings, StaticPopupDialogs, StaticPopup_Show
local ACCEPT, DEFAULT = ACCEPT, DEFAULT
local GetTime, hooksecurefunc = GetTime, hooksecurefunc
local assert, UnitName = assert, UnitName
local TSM_API = assert(TSM_API, "PriceAnswer requires TradeSkillMaster")
local GetCustomPriceValue = TSM_API.GetCustomPriceValue
local IsPriceSourceValid = TSM_API.IsPriceSourceValid
local ToItemString = TSM_API.ToItemString
local GetPriceSourceKeys = TSM_API.GetPriceSourceKeys
local GetPriceSourceDescription = TSM_API.GetPriceSourceDescription
local CTL = assert(ChatThrottleLib, "PriceAnswer requires ChatThrottleLib")

-- addon creation
local PriceAnswer = LibStub("AceAddon-3.0"):NewAddon("PriceAnswer", "AceConsole-3.0", "AceEvent-3.0", "LibAboutPanel-2.0")
local L = LibStub("AceLocale-3.0"):GetLocale("PriceAnswer")
local CURRENT_DB_VERSION = 1 -- increment when breaking changes are made

-- defaults for options
local defaults = {
	profile = {
		enableAddOn = true,
		formatLargeNumbers = true,
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
	global = {
		current_db_version = CURRENT_DB_VERSION
	}
}

-- local variables
local db -- used for shorthand and for resetting the options to defaults
local isMainline = WOW_PROJECT_ID == WOW_PROJECT_MAINLINE -- retail World of Warcraft
local isMists = WOW_PROJECT_ID == WOW_PROJECT_MISTS_CLASSIC -- Mists of Pandaria Classic
local isClassicEra = WOW_PROJECT_ID == WOW_PROJECT_CLASSIC -- Classic Era
local isSeason = C_Seasons and C_Seasons.GetActiveSeason() -- C_Seasons API is only available in "classic" versions of the game
isSeason = isSeason and isSeason >= 2 -- Season of Discovery or later
local playerName = UnitName("player")
local PriceAnswerSentMessages = {} -- table to track sent message hashes to prevent loops in whispers
local function GetMessageHash(message, sender)
	return tostring(message) .. "::" .. tostring(sender)
end

local events = {
	["CHAT_MSG_CHANNEL"]				= true,
	["CHAT_MSG_SAY"]					= true,
	["CHAT_MSG_YELL"]					= true,
	["CHAT_MSG_GUILD"]					= true,
	["CHAT_MSG_OFFICER"]				= true,
	["CHAT_MSG_PARTY"]					= true,
	["CHAT_MSG_RAID"]					= true,
	["CHAT_MSG_WHISPER"]				= true,
	["CHAT_MSG_BN_WHISPER"]				= true,
	["CHAT_MSG_RAID_WARNING"]			= true,
	["CHAT_MSG_INSTANCE_CHAT"]			= isMists or isMainline,
	["CHAT_MSG_COMMUNITIES_CHANNEL"]	= isMainline
}

-- main Ace3 Functions
function PriceAnswer:OnInitialize()
	self.db = LibStub("AceDB-3.0"):New("PriceAnswerDB", defaults, true)
	self.db.RegisterCallback(self, "OnProfileChanged", "RefreshConfig")
	self.db.RegisterCallback(self, "OnProfileCopied", "RefreshConfig")
	self.db.RegisterCallback(self, "OnProfileReset", "RefreshConfig")

	-- Only reset if DB version is outdated
	if (not self.db.global.current_db_version) or (self.db.global.current_db_version < CURRENT_DB_VERSION) then
		StaticPopupDialogs["PRICEANSWER_RESET"] = {
			text = L["Price Answer has been updated. The settings have been reset to defaults."],
			button1 = ACCEPT,
			timeout = 0,
			whileDead = true,
			hideOnEscape = true
		}
		StaticPopup_Show("PRICEANSWER_RESET")
		self.db:ResetDB(DEFAULT)
		self.db.global.current_db_version = CURRENT_DB_VERSION
	end
	db = self.db.profile

	-- set enabled/disabled state as per user prefs
	self:SetEnabledState(db.enableAddOn)

	local options = self:GetOptions()

	-- create Profiles within the options
	options.args.profiles = LibStub("AceDBOptions-3.0"):GetOptionsTable(self.db)
	options.args.profiles.order = 0

	-- LibAboutPanel-2.0 support
	options.args.aboutTable = self:AboutOptionsTable("PriceAnswer")
	options.args.aboutTable.order = -1

	LibStub("AceConfig-3.0"):RegisterOptionsTable("PriceAnswer", options)

	-- register options with WoW's Interface\AddOns\ UI
	LibStub("AceConfigDialog-3.0"):AddToBlizOptions("PriceAnswer", L["Price Answer"])

	-- create and register slash command
	self:RegisterChatCommand("priceanswer", "ChatCommand")
	self:RegisterChatCommand("prans", "ChatCommand")
end

function PriceAnswer:OnEnable()
	for event in pairs(events) do
		if events[event] and db.watchedChatChannels[event] then
			self:RegisterEvent(event, "HandleChatEvent")
		end
	end
end

function PriceAnswer:OnDisable()
	self:UnregisterAllEvents()
	wipe(PriceAnswerSentMessages) -- clear the sent messages table
end

-- reset the SV database
function PriceAnswer:RefreshConfig(callback)
	if callback == "OnProfileReset" then
		self.db:ResetDB(DEFAULT)
		self.db.global.current_db_version = CURRENT_DB_VERSION
	end
	db = self.db.profile
	wipe(PriceAnswerSentMessages) -- clear sent messages on profile change/reset
end

-- handle slash commands
function PriceAnswer:ChatCommand()
	Settings.OpenToCategory(L["Price Answer"])
end

-- secure hook ChatThrottleLib:SendChatMessage for testing purposes when the user sends themself a message
hooksecurefunc(CTL, "SendChatMessage", function(_, prefix, message, _, _, senderName)
	if not prefix or prefix ~= "PATSM" then return end
	if not senderName or senderName ~= playerName then return end -- only track self/test messages
	local hash = GetMessageHash(message, senderName)
	if PriceAnswerSentMessages[hash] then return end
	PriceAnswerSentMessages[hash] = GetTime() -- store timestamp for cleanup
end)

-- chat messages event handlers
-- no need to duplicate code for every event
function PriceAnswer:GetOutgoingMessage(incomingMessage)
	-- pattern for "trigger N item" incoming chat messages
	-- item can be an itemLink EX: ["|cff0070dd|Hitem:63470::::::::53:257::2:1:4198:2:28:1199:9:35:::::|h[Missing Diplomat's Pauldrons]|h|r"]
	-- or item can be an itemID EX: 63470
	-- or item can be an item name EX: Missing Diplomat's Pauldrons
	-- the quantity N is optional and defaults to 1 if not provided or is less than 1
	local pattern = "^(%d*)%s*(.*)$"
	local incomingMessageTrim = strtrim(strsub(incomingMessage, strlen(L[db.trigger])+1)," \r\n")
	local itemCount, tail = strmatch(incomingMessageTrim, pattern)

	itemCount = itemCount and itemCount:trim()
	tail = tail and tail:trim()

	-- Helper to try getting itemID from multiple sources
	local function tryGetItemID(val)
		if not val then return nil end
		local ok, result = pcall(GetItemInfoInstant, val)
		if ok and result then return result end
		ok, result = pcall(GetItemInfoInstant, tonumber(val))
		if ok and result then return result end
		return nil
	end

	local itemID = tryGetItemID(tail) or tryGetItemID(itemCount)

	-- convert to a TSM item string "i:12345"
	local itemString
	if TSM_API and TSM_API.ToItemString then
		itemString = TSM_API.ToItemString(tostring(tail))
		if not itemString then
			itemString = TSM_API.ToItemString(tostring(itemCount))
			if itemString then itemCount = 1 end
		end
		if not itemString and itemID then
			itemString = TSM_API.ToItemString(tostring(itemID))
			if not itemString then
				itemString = "i:" .. tostring(itemID)
			end
		end
	end

	itemCount = tonumber(itemCount) or 1
	if not itemCount or itemCount < 1 then
		itemCount = 1
	end

	-- cache price results per item per message
	local priceCache = {}
	local function getCachedPrice(source)
		if priceCache[source] ~= nil then return priceCache[source] end
		priceCache[source] = self:GetItemValue(source, itemString, itemCount)
		return priceCache[source]
	end
	local craftingCopper = getCachedPrice("crafting")
	local destroyCopper = getCachedPrice("destroy")
	local dbminbuyoutCopper = getCachedPrice("dbminbuyout")
	local dbmarketCopper = getCachedPrice("dbmarket")
	local dbregionmarketavgCopper = getCachedPrice("dbregionmarketavg")
	local dbhistoricalCopper = getCachedPrice("dbhistorical")
	local dbregionhistoricalCopper = getCachedPrice("dbregionhistorical")
	local dbrecentCopper = getCachedPrice("dbrecent")
	local oeCopper = getCachedPrice("oerealm") -- only for retail WoW, from Oribos Exchange

	-- non-Vanilla Classic Era, Mists Classic, and Mainline
	if isSeason or isMists or isMainline then
		-- min buyout, provided by TSM ("dbminbuyout"), Auctionator ("atrvalue"), Auction House DataBase ("ahdbminbuyout")
		dbminbuyoutCopper = dbminbuyoutCopper or self:GetItemValue("atrvalue", itemString, itemCount) or self:GetItemValue("ahdbminbuyout", itemString, itemCount)
	elseif isClassicEra and not isSeason then
		-- we need external price sources for vanilla Classic Era: Auctioneer, Auctionator, or Auction House DataBase
		dbminbuyoutCopper = self:GetItemValue("aucminbuyout", itemString, itemCount) or self:GetItemValue("atrvalue", itemString, itemCount) or self:GetItemValue("ahdbminbuyout", itemString, itemCount)
		dbmarketCopper = self:GetItemValue("aucmarket", itemString, itemCount)
		dbrecentCopper = self:GetItemValue("aucappraiser", itemString, itemCount)
		-- these values are not available in vanilla Classic Era
		dbregionmarketavgCopper = 0
		dbhistoricalCopper = 0
		dbregionhistoricalCopper = 0
		oeCopper = 0
	end

	-- convert copper coins into human-readable strings "14g55s96c" or nil. must be >= 1c if it isn't nil
	local craftingString = self:ConvertToHumanReadable(craftingCopper)
	local destroyString = self:ConvertToHumanReadable(destroyCopper)
	local dbminbuyoutString = self:ConvertToHumanReadable(dbminbuyoutCopper)
	local dbmarketString = self:ConvertToHumanReadable(dbmarketCopper)
	local dbregionmarketavgString = self:ConvertToHumanReadable(dbregionmarketavgCopper)
	local dbhistoricalString = self:ConvertToHumanReadable(dbhistoricalCopper)
	local dbregionhistoricalString = self:ConvertToHumanReadable(dbregionhistoricalCopper)
	local dbrecentString = self:ConvertToHumanReadable(dbrecentCopper)
	local oeString = self:ConvertToHumanReadable(oeCopper)

	-- build the outgoing message
	local outgoingMessageOne, outgoingMessageTwo = "", ""

	if db.tsmSources["dbminbuyout"] then
		if dbminbuyoutString then
			outgoingMessageOne = L["Cheapest Auction"] .. " " .. dbminbuyoutString
		end
	end

	if db.tsmSources["dbrecent"] then
		if dbrecentString then
			outgoingMessageOne = outgoingMessageOne .. " " .. L["Current AH Avg"] .. " " .. dbrecentString
		end
	end

	if db.tsmSources["oerealm"] then
		if oeString then
			outgoingMessageOne = outgoingMessageOne .. " " .. L["3-Day Realm Avg"] .. " " .. oeString
		end
	end

	if db.tsmSources["dbmarket"] then
		if dbmarketString then
			outgoingMessageOne = outgoingMessageOne .. " " .. L["14-Day Realm Avg"] .. " " .. dbmarketString
		end
	end

	if db.tsmSources["dbhistorical"] then
		if dbhistoricalString then
			outgoingMessageOne = outgoingMessageOne .. " " .. L["60-Day Realm Avg"] .. " " .. dbhistoricalString
		end
	end

	if db.tsmSources["dbregionmarketavg"] then
		if dbregionmarketavgString then
			outgoingMessageTwo =  L["14-Day Region Avg"] .. " " .. dbregionmarketavgString
		end
	end

	if db.tsmSources["dbregionhistorical"] then
		if dbregionhistoricalString then
			outgoingMessageTwo = outgoingMessageTwo .. " " .. L["60-Day Region Avg"] .. " " .. dbregionhistoricalString
		end
	end

	if db.tsmSources["crafting"] then
		if craftingString then
			outgoingMessageTwo = outgoingMessageTwo .. " " .. L["Crafting Cost"] .. " " .. craftingString
		end
	end

	if db.tsmSources["destroy"] then
		if destroyString then
			outgoingMessageTwo = outgoingMessageTwo .. " " .. L["Disenchant/Mill/Prospect Value"] .. " " .. destroyString
		end
	end

	-- trim dead spaces
	outgoingMessageOne = outgoingMessageOne:trim()
	outgoingMessageTwo = outgoingMessageTwo:trim()

	return outgoingMessageOne, outgoingMessageTwo
end

-- TradeSkillMaster price functions
function PriceAnswer:GetItemValue(price_source, item_string, item_count)
	if not item_string or not price_source then return 0 end
	if not IsPriceSourceValid or not IsPriceSourceValid(price_source) then return 0 end
	if not GetCustomPriceValue then return 0 end
	local ok, value, err_string = pcall(GetCustomPriceValue, price_source, item_string)
	if ok and value and type(value) == "number" then
		return value * (item_count or 1)
	end
	return 0
end

-- TradeSkillMaster has some weird control characters in TSM_API.FormatMoneyString, build our own version
function PriceAnswer:ConvertToHumanReadable(num_copper)
	local gold_string, silver_string, copper_string = "", "", ""
	local gold, silver, copper

	if num_copper and num_copper >= 1 then
		gold = floor(num_copper / 10000)
		silver = (num_copper / 100) % 100
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

-- Generalized event handler
function PriceAnswer:HandleChatEvent(event, ...)
	-- hard exit if in combat to prevent tainting issues
	if InCombatLockdown() or UnitAffectingCombat("player") then return end

	local incomingMessage, senderName = ...
	local hash = GetMessageHash(incomingMessage, senderName)
	if PriceAnswerSentMessages[hash] then return end -- prevent loop for WHISPER
	-- Cleanup old hashes (older than 10 minutes)
	local now = GetTime()
	for k, t in pairs(PriceAnswerSentMessages) do
		if now - t > 600 then PriceAnswerSentMessages[k] = nil end
	end

	if not incomingMessage:find("^" .. gsub(L[db.trigger], "^%?", "%%%?")) then return end

	self:UnregisterEvent(event)

	local msg1, msg2 = self:GetOutgoingMessage(incomingMessage)
	if msg1 ~= "" then
		self:SendResponse(event, msg1, senderName, ...)
	end
	if msg2 ~= "" then
		self:SendResponse(event, msg2, senderName, ...)
	end

	self:RegisterEvent(event, "HandleChatEvent")
end

-- Helper to send response via correct channel
function PriceAnswer:SendResponse(event, msg, target, ...)
	-- hard exit if in combat to prevent tainting issues
	if InCombatLockdown() or UnitAffectingCombat("player") then return end

	local channel = db.replyChannel[event] or "WHISPER"
	if event == "CHAT_MSG_BN_WHISPER" then
		local bnSenderID = select(13, ...)
		BNSendWhisper(bnSenderID, msg)
	else
		CTL:SendChatMessage("NORMAL", "PATSM", msg, channel, nil, channel == "WHISPER" and target or nil)
	end
end