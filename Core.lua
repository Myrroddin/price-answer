assert(TSM_API, "TradeSkillMaster is missing, please enable", 2)

-- upvalue globals
local LibStub, TSM_API, pairs, GetItemInfoInstant, pcall = LibStub, TSM_API, pairs, C_Item.GetItemInfoInstant, pcall
local SendChatMessage, BNSendWhisper, wipe = C_ChatInfo.SendChatMessage or SendChatMessage, BNSendWhisper, table.wipe

-- addon creation
local PriceAnswer = LibStub("AceAddon-3.0"):NewAddon("PriceAnswer", "AceConsole-3.0", "AceEvent-3.0", "LibAboutPanel-2.0")
local L = LibStub("AceLocale-3.0"):GetLocale("PriceAnswer")

-- defaults for options
local defaults = {
	profile = {
		enableAddOn = true,
		disableInCombat = true,
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
	global = {}
}

-- local variables
local db -- used for shorthand and for resetting the options to defaults
local isMainline = WOW_PROJECT_ID == WOW_PROJECT_MAINLINE -- not any "classic" version of the game
local isMists = WOW_PROJECT_ID == WOW_PROJECT_MISTS_CLASSIC -- Mists of Pandaria Classic
local isFresh = C_Seasons and C_Seasons.GetActiveSeason() -- C_Seasons API is only available in "Classic" versions of the game
isFresh = isFresh and isFresh >= 11 -- Fresh or Fresh Hardcore, Season 11 or later
local playerName = UnitName("player")
local PriceAnswerSentMessages = {} -- table to track sent messages to prevent loops in whispers

local events = {
	["CHAT_MSG_CHANNEL"]                = true,
	["CHAT_MSG_SAY"]                    = true,
	["CHAT_MSG_YELL"]                   = true,
	["CHAT_MSG_GUILD"]                  = true,
	["CHAT_MSG_OFFICER"]                = true,
	["CHAT_MSG_PARTY"]                  = true,
	["CHAT_MSG_RAID"]                   = true,
	["CHAT_MSG_WHISPER"]                = true,
	["CHAT_MSG_BN_WHISPER"]             = true,
	["CHAT_MSG_RAID_WARNING"]           = true,
	["CHAT_MSG_INSTANCE_CHAT"]          = isMists or isMainline,
	["CHAT_MSG_COMMUNITIES_CHANNEL"]    = isMainline
}

-- main Ace3 Functions
function PriceAnswer:OnInitialize()
	self.db = LibStub("AceDB-3.0"):New("PriceAnswerDB", defaults, true)
	self.db.RegisterCallback(self, "OnProfileChanged", "RefreshConfig")
	self.db.RegisterCallback(self, "OnProfileCopied", "RefreshConfig")
	self.db.RegisterCallback(self, "OnProfileReset", "RefreshConfig")

	-- reset the AceDB-3.0 DB on the first run, as we altered the watched chat channel SV names to match the event names
	if not self.db.global.initialized then
		StaticPopupDialogs["PRICEANSWER_RESET"] = {
			text = L["Price Answer has been updated. The settings have been reset to defaults."],
			button1 = ACCEPT,
			timeout = 0,
			whileDead = true,
			hideOnEscape = true
		}
		StaticPopup_Show("PRICEANSWER_RESET")
		self.db:RegisterDefaults(defaults)
		self.db:ResetDB(DEFAULT)
		self.db.global.initialized = true
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
	end
	self.db.global.initialized = true
	db = self.db.profile
end

-- handle slash commands
function PriceAnswer:ChatCommand()
	Settings.OpenToCategory(L["Price Answer"])
end

-- secure hook SendChatMessage for testing purposes when the user sends themself a message
hooksecurefunc("SendChatMessage", function(message, _, _, senderName)
	if PriceAnswerSentMessages[message] then return end
	if senderName and senderName == playerName then
		PriceAnswerSentMessages[message] = true
	end
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

	-- get the itemID
	local itemID, retOK, ret1 -- use pcall() to validate GetItemInfoInstant()
	if not itemID then
		retOK, ret1 = pcall(GetItemInfoInstant, tail)
		if retOK then
			itemID = ret1
		else
			retOK, ret1 = pcall(GetItemInfoInstant, tonumber(tail))
			if retOK then
				itemID = ret1
			end
		end
	end

	-- the above did not get an itemID
	if not itemID then
		retOK, ret1 = pcall(GetItemInfoInstant, itemCount)
		if retOK then
			itemID = ret1
		else
			retOK, ret1 = pcall(GetItemInfoInstant, tonumber(itemCount))
			if retOK then
				itemID = ret1
			end
		end
	end -- at this point it does not matter if there is no itemID

	-- convert to a TSM item string "i:12345"
	local itemString
	if TSM_API and TSM_API.ToItemString then
		itemString = TSM_API.ToItemString(tostring(tail))
		if not itemString then
			itemString = TSM_API.ToItemString(tostring(itemCount))
			if itemString then
				itemCount = 1
			end
		end
		if not itemString then
			if itemID then -- check if there is an itemID from the pcall()
				itemString = TSM_API.ToItemString(tostring(itemID))
				if not itemString then
					itemString = "i:" .. tostring(itemID)
				end
			end
		end
	end

	itemCount = tonumber(itemCount) or 1
	if not itemCount or itemCount < 1 then
		itemCount = 1
	end

	-- get values in copper coins
	local craftingCopper = self:GetItemValue("crafting", itemString, itemCount)
	local destroyCopper = self:GetItemValue("destroy", itemString, itemCount)
	local dbminbuyoutCopper = self:GetItemValue("dbminbuyout", itemString, itemCount)
	local dbmarketCopper = self:GetItemValue("dbmarket", itemString, itemCount)
	local dbregionmarketavgCopper = self:GetItemValue("dbregionmarketavg", itemString, itemCount)
	local dbhistoricalCopper = self:GetItemValue("dbhistorical", itemString, itemCount)
	local dbregionhistoricalCopper = self:GetItemValue("dbregionhistorical", itemString, itemCount)
	local dbrecentCopper = self:GetItemValue("dbrecent", itemString, itemCount)

	-- Fresh or Fresh Hardcore, Mists, and Mainline
	if isFresh or isMists or isMainline then
		-- min buyout, provided by TSM ("dbminbuyout"), Auctioneer ("aucminbuyout"), Auctionator ("atrvalue"), Auction House DataBase ("ahdbminbuyout")
		dbminbuyoutCopper = dbminbuyoutCopper or self:GetItemValue("aucminbuyout", itemString, itemCount) or self:GetItemValue("atrvalue", itemString, itemCount) or self:GetItemValue("ahdbminbuyout", itemString, itemCount)
		-- market value, provided by TSM ("dbmarket") or Auctioneer ("aucmarket")
		dbmarketCopper = dbmarketCopper or self:GetItemValue("aucmarket", itemString, itemCount)
		-- recent value, provided by TSM ("dbrecent") or Auctioneer ("aucappraiser")
		dbrecentCopper = dbrecentCopper or self:GetItemValue("aucappraiser", itemString, itemCount)
	else
		-- we need external price sources for vanilla Classic Era, non-Fresh, & SoD
		dbminbuyoutCopper = self:GetItemValue("aucminbuyout", itemString, itemCount) or self:GetItemValue("atrvalue", itemString, itemCount) or self:GetItemValue("ahdbminbuyout", itemString, itemCount)
		dbmarketCopper = self:GetItemValue("aucmarket", itemString, itemCount)
		dbrecentCopper = self:GetItemValue("aucappraiser", itemString, itemCount)
		dbregionmarketavgCopper = 0
		dbhistoricalCopper = 0
		dbregionhistoricalCopper = 0
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

	-- build the outgoing message
	local outgoingMessageOne, outgoingMessageTwo = "", ""

	if db.tsmSources["dbmarket"] then
		if dbmarketString then
			outgoingMessageOne = L["14-Day Realm Avg"] .. " " .. dbmarketString
		end
	end

	if db.tsmSources["dbminbuyout"] then
		if dbminbuyoutString then
			outgoingMessageOne = outgoingMessageOne .. " " .. MINIMUM .. " " .. dbminbuyoutString
		end
	end

	if db.tsmSources["dbrecent"] then
		if dbrecentString then
			outgoingMessageOne = outgoingMessageOne .. " " .. L["Current AH Avg"] .. " " .. dbrecentString
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
	if TSM_API and TSM_API.GetCustomPriceValue then
		if item_string then
			if TSM_API.GetCustomPriceValue(price_source, item_string) then -- if it isn't nil, then...
				local num_copper, err_string = TSM_API.GetCustomPriceValue(price_source, item_string) * item_count
				if num_copper then
					return num_copper
				elseif err_string then
					self:Print(err_string)
				end
			end
		end
	end
	return 0 -- price_source not valid, no current or known value, or item_string is not valid, return non-nil so we don't error
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
	if db.disableInCombat and UnitAffectingCombat("player") then return end

	local incomingMessage, senderName = ...
	if PriceAnswerSentMessages[incomingMessage] then return end -- prevent loop for WHISPER

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
	local channel = db.replyChannel[event] or "WHISPER"
	if event == "CHAT_MSG_BN_WHISPER" then
		local bnSenderID = select(13, ...)
		BNSendWhisper(bnSenderID, msg)
	else
		SendChatMessage(msg, channel, nil, channel == "WHISPER" and target or nil)
	end
end