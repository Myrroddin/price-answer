-- upvalue globals
local LibStub, pairs, GetItemInfoInstant, pcall = LibStub, pairs, C_Item.GetItemInfoInstant, pcall
local BNSendWhisper, wipe = BNSendWhisper or C_BattleNet.SendWhisper, wipe
local strtrim, strsub, strmatch, strlower = strtrim, strsub, strmatch, strlower
local select, InCombatLockdown, UnitAffectingCombat = select, InCombatLockdown, UnitAffectingCombat
local DEFAULT, SendChatMessage, GetItemInfo = DEFAULT, C_ChatInfo.SendChatMessage, C_Item.GetItemInfo
local GetTime, tonumber, tostring, type = GetTime, tonumber, tostring, type
local TSM_API, CTL = _G.TSM_API, _G.ChatThrottleLib
local GetCustomPriceValue = TSM_API and TSM_API.GetCustomPriceValue
local ToItemString = TSM_API and TSM_API.ToItemString
local GOLD_AMOUNT_SYMBOL, SILVER_AMOUNT_SYMBOL, COPPER_AMOUNT_SYMBOL = GOLD_AMOUNT_SYMBOL, SILVER_AMOUNT_SYMBOL, COPPER_AMOUNT_SYMBOL
local floor, format, FormatLargeNumber = floor, format, FormatLargeNumber

-- addon creation
local PriceAnswer = LibStub("AceAddon-3.0"):NewAddon("PriceAnswer", "AceConsole-3.0", "AceEvent-3.0", "LibAboutPanel-2.0")
local L = LibStub("AceLocale-3.0"):GetLocale("PriceAnswer")
local CURRENT_DB_VERSION = 2

-- defaults
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
local db, player_name
player_name = UnitName("player")
local isMainline = WOW_PROJECT_ID == WOW_PROJECT_MAINLINE
local isClassicEra = WOW_PROJECT_ID == WOW_PROJECT_CLASSIC
local isSeason = C_Seasons and C_Seasons.GetActiveSeason()
isSeason = isSeason and isSeason >= 2
local PriceAnswerSentMessages = {}

-- price sources for normalization logic based on game version
local minBuyoutSources, marketValuesSources, recentValuesSources, regionMarketValuesSources = {}, {}, {}, {}
if isClassicEra and not isSeason then
	minBuyoutSources = {
		"aucminbuyout",
		"atrvalue",
		"ahdbminbuyout"
	}
else
	minBuyoutSources = {
		"dbminbuyout",
		"aucminbuyout",
		"atrvalue",
		"ahdbminbuyout"
	}
end
marketValuesSources = {
	"dbmarket",
	"aucmarket",
	"oerealm"
}
recentValuesSources = {
	"dbrecent",
	"aucappraiser"
}
regionMarketValuesSources = {
	"dbregionmarketavg",
	"oeregion"
}

-- attempt to resolve a valid itemID from a value (link, ID, or name)
local function tryGetItemID(val)
	if (not val) or (strtrim(val) == "") then
		return nil
	end
	-- val may be an itemLink or item name, attempt to get a valid itemID from it
	local ok, result = pcall(GetItemInfoInstant, val)
	if (ok and result) then
		return result
	end
	-- val may be an itemID passed in as a string or number, attempt to get a valid itemID from it
	ok, result = pcall(GetItemInfoInstant, tonumber(val))
	if (ok and result) then
		return result
	end
	-- fallback: resolve item name via C_Item.GetItemInfo (requires cache), extract itemID from itemLink
	local ok2, _, itemLink = pcall(GetItemInfo, val)
	if (ok2 and itemLink) then
		local itemIDFromLink = itemLink:match("item:(%d+)")
		if itemIDFromLink then
			return tonumber(itemIDFromLink)
		end
	end
	-- failed to get a valid itemID from val
	return nil
end

-- ensure a string does not start with a blank space
local function AppendField(base, label, value)
	if not value then return base end
	if base ~= "" then
		return base .. " " .. label .. " " .. value
	else
		return label .. " " .. value
	end
end

-- ensures itemCount is a valid number, rounds it to the nearest whole integer using standard rounding rules
-- (>= 0.5 rounds up, < 0.5 rounds down), and guarantees the result is at least 1
-- returns the rounded integer value or 1 if the input is invalid or less than 1 after rounding
local function TrueRound(itemCount)
	local n = tonumber(itemCount)

	if not n then
		return 1
	end

	local rounded = floor(n + 0.5)

	if (not rounded) or (rounded < 1) then
		return 1
	end

	return rounded
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
	["CHAT_MSG_COMMUNITIES_CHANNEL"] = isMainline
}

-- init
function PriceAnswer:OnInitialize()
	-- check for TSM_API, if it's not present then disable the addon and show an error message
	if not TSM_API then
		local msg = L["TradeSkillMaster is required. Disabling Price Answer."]
		UIErrorsFrame:AddMessage(msg, 1.0, 0.1, 0.1, 5)
		self:SetEnabledState(false)
		return
	end

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
	self:SetEnabledState(db and db.enableAddOn)

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
		if (events[event]) and (db and db.watchedChatChannels[event]) then
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

	local trigger = strlower(db.trigger)
	if strlower(strsub(msg, 1, #trigger)) ~= trigger then return end

	-- prevent message loops and duplicate processing:
	-- 1. ignore messages that match ones recently sent by this addon (prevents responding to our own output)
	-- 2. ignore messages already processed from the same sender (prevents duplicate replies and echo loops)
	if msg and msg ~= "" then
		local self_hash = msg .. "::" .. player_name
		if PriceAnswerSentMessages[self_hash] then return end
	end
	local hash = msg .. "::" .. sender
	if PriceAnswerSentMessages[hash] then return end

	-- return messages from Step 2, parsed from Steps 3 and 4, to be sent in Step 5
	local m1, m2 = self:GetOutgoingMessage(msg)

	-- send the outgoing messages using Step 5, but only if they are not empty strings (if they are empty strings,
	-- it means we failed to parse the incoming message or get valid price data from TSM, so we should not send a response)
	if m1 ~= "" then self:SendResponse(event, m1, sender, ...) end
	if m2 ~= "" then self:SendResponse(event, m2, sender, ...) end
end

-- Step 2: Parse the message to attempt to extract an itemString and quantity,
-- then query TSM for the relevant price sources using the itemString and build the outgoing message based on the results
function PriceAnswer:GetOutgoingMessage(incomingMessage)
	local pattern = "^(%d*)%s*(.*)$"
	local incomingMessageTrim = strtrim(strsub(incomingMessage, #db.trigger + 1), " \r\n")
	local itemCount, tail = strmatch(incomingMessageTrim, pattern)

	itemCount = TrueRound(itemCount)
	tail = tail and strtrim(tail)

	-- if no tail exists, the input was likely a single value (itemID),
	-- so treat itemCount as the item and default quantity to 1
	if (not tail) or (tail == "") then
		tail = itemCount
		itemCount = 1
	end

	local itemID = tryGetItemID(tail) or tryGetItemID(itemCount)

	-- attempt to build a TSM itemString ("i:12345") from the tail or itemCount, prioritizing the tail
	local itemString = nil
	local ok, result = pcall(ToItemString, tail)
	if (ok and result) then
		itemString = result
	end
	if (not itemString) then
		ok, result = pcall(ToItemString, itemCount)
		if (ok and result) then
			itemString = result
		end
	end
	-- failed to get a valid TSM itemString from the tail or itemCount, attempt to build a TSM itemString from the itemID
	if (not itemString and itemID) then
		ok, result = pcall(ToItemString, tostring(itemID))
		if (ok and result) then
			itemString = result
		else
			itemString = "i:" .. tostring(itemID)
		end
	end

	-- if we still don't have a valid TSM itemString at this point, exit the function with empty messages, going back to Step 1 without sending a response
	if (not itemString) then
		return "", ""
	end

	-- assign default price values of 0 (they are in copper amounts)
	local dbminbuyout = 0
	local dbmarket = 0
	local dbrecent = 0
	local dbhistorical = 0
	local dbregionmarket = 0
	local dbregionhistorical = 0
	local oerealm = 0
	local craftingcost = 0
	local destroyvalue = 0

	-- Step 3: Loop through the price sources in order of priority and assign the first valid price we find to the appropriate variable.
	-- The price sources we check depend on the game version, as some sources are not available in certain versions.
	if (isClassicEra and not isSeason) then
		dbminbuyout = self:GetPriceFromSources(minBuyoutSources, itemString, itemCount)
		dbmarket = self:GetPriceFromSources("aucmarket", itemString, itemCount)
		dbrecent = self:GetPriceFromSources("aucappraiser", itemString, itemCount)
	else
		dbminbuyout = self:GetPriceFromSources(minBuyoutSources, itemString, itemCount)
		dbmarket = self:GetPriceFromSources(marketValuesSources, itemString, itemCount)
		dbrecent = self:GetPriceFromSources(recentValuesSources, itemString, itemCount)
		dbregionmarket = self:GetPriceFromSources(regionMarketValuesSources, itemString, itemCount)
		dbhistorical = self:GetPriceFromSources("dbhistorical", itemString, itemCount)
		dbregionhistorical = self:GetPriceFromSources("dbregionhistorical", itemString, itemCount)
	end
	-- retail/mainline also has the "oerealm" source available, so we check that for all versions and it will return 0 if it's not available in the current version
	if isMainline then
		oerealm = self:GetPriceFromSources("oerealm", itemString, itemCount)
		-- compare oerealm to dbmarket; if they are the same, 0 out oerealm to avoid showing duplicate price info in the output message
		if (oerealm == dbmarket) then
			oerealm = 0
		end
	end
	-- crafting cost and destroy value are available in all versions, so we check those for all versions as well
	craftingcost = self:GetPriceFromSources("crafting", itemString, itemCount)
	destroyvalue = self:GetPriceFromSources("destroy", itemString, itemCount)

	-- Step 4: Convert the price values (which are in copper) to a human readable gold/silver/copper format and build the outgoing message string
	-- if a price value is 0 or nil, the return will be nil instead of an empty string
	local dbminbuyoutString = self:ConvertToHumanReadable(dbminbuyout)
	local dbmarketString = self:ConvertToHumanReadable(dbmarket)
	local dbrecentString = self:ConvertToHumanReadable(dbrecent)
	local dbregionmarketString = self:ConvertToHumanReadable(dbregionmarket)
	local dbhistoricalString = self:ConvertToHumanReadable(dbhistorical)
	local dbregionhistoricalString = self:ConvertToHumanReadable(dbregionhistorical)
	local oeString = isMainline and self:ConvertToHumanReadable(oerealm)
	local craftingCostString = self:ConvertToHumanReadable(craftingcost)
	local destroyValueString = self:ConvertToHumanReadable(destroyvalue)

	local out1, out2 = "", ""

	-- passed in are outN (string), localized label (string), human readable coin amount, ex: 147g21s39c (string/nil)
	-- if the third arg passed is nil, then outN will be appended with an empty string
	if db.tsmSources.dbminbuyout then
		out1 = AppendField(out1, L["Cheapest Auction"], dbminbuyoutString)
	end
	if db.tsmSources.dbrecent then
		out1 = AppendField(out1, L["Current AH Avg"], dbrecentString)
	end
	if (isMainline and oeString) then
		if db.tsmSources.oerealm then
			out1 = AppendField(out1, L["3-Day Realm Avg"], oeString)
		end
	end
	if db.tsmSources.dbmarket then
		out1 = AppendField(out1, L["14-Day Realm Avg"], dbmarketString)
	end
	if db.tsmSources.dbregionmarketavg then
		out1 = AppendField(out1, L["14-Day Region Avg"], dbregionmarketString)
	end
	if db.tsmSources.dbhistorical then
		out2 = AppendField(out2, L["60-Day Realm Avg"], dbhistoricalString)
	end
	if db.tsmSources.dbregionhistorical then
		out2 = AppendField(out2, L["60-Day Region Avg"], dbregionhistoricalString)
	end
	if db.tsmSources.crafting then
		out2 = AppendField(out2, L["Crafting Cost"], craftingCostString)
	end
	if db.tsmSources.destroy then
		out2 = AppendField(out2, L["Disenchant/Mill/Prospect Value"], destroyValueString)
	end

	out1 = strtrim(out1)
	out2 = strtrim(out2)

	-- return to Step 1 for sending during Step 5
	return out1, out2
end

-- Step 3: Pass in a table/string of price sources, the TSM itemString, and itemQuantity, and return the value of the item * quantity
-- or 0 if no valid price is found from any of the sources
function PriceAnswer:GetPriceFromSources(sources, itemString, itemQuantity)
	local okay, result = nil, nil
	if type(sources) == "table" then
		-- multiple sources passed in as a table, loop through them and attempt to get a price from each source in order of priority until we find a valid price
		for _, source in pairs(sources) do
			okay, result = pcall(GetCustomPriceValue, source, itemString)
			if (okay and result) and (result > 0) then
				return result * itemQuantity
			end
		end
	else
		-- single source passed in as a string rather than a table, attempt to get a price from that source
		okay, result = pcall(GetCustomPriceValue, sources, itemString)
		if (okay and result) and (result > 0) then
			return result * itemQuantity
		end
	end
	return 0
end

-- Step 4: Convert the price values (which are in copper) to a human readable 147g21s39c format, returning to Step 2 as a string or nil
function PriceAnswer:ConvertToHumanReadable(num_copper)
	local gold_string, silver_string, copper_string = "", "", ""
	local gold, silver, copper

	if (num_copper and num_copper >= 1) then
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

-- Step 5: Send the outgoing message to the appropriate channel based on the event
function PriceAnswer:SendResponse(event, msg, target, ...)
	if (db.disableInCombat and (InCombatLockdown() or UnitAffectingCombat("player"))) then
		return
	end

	local channel = db.replyChannel[event] or "WHISPER"

	local hash = msg .. "::" .. player_name
	PriceAnswerSentMessages[hash] = GetTime()

	if event == "CHAT_MSG_BN_WHISPER" then
		local id = select(13, ...)
		BNSendWhisper(id, msg)
	else
		if CTL then
			CTL:SendChatMessage("NORMAL", "PATSM", msg, channel, nil, channel == "WHISPER" and target or nil)
		else
			SendChatMessage(msg, channel, nil, channel == "WHISPER" and target or nil)
		end
	end
end