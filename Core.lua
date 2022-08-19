assert(TSM_API, "TradeSkillMaster is missing, please enable", 2)
local addon_folder, pt = ... -- pt is not used

-- upvalue globals
local _G = _G
local LibStub = _G.LibStub
local TSM_API = _G.TSM_API

-- addon creation
local PriceAnswer = LibStub("AceAddon-3.0"):NewAddon(addon_folder, "AceConsole-3.0", "AceEvent-3.0", "LibAboutPanel-2.0")
local L = LibStub("AceLocale-3.0"):GetLocale(addon_folder)
local Dialog = LibStub("AceConfigDialog-3.0")
local Command = LibStub("AceConfigCmd-3.0")

-- defaults for options
local defaults = {
    global = {
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
    }
}

-- handle user options
local db -- used for shorthand and for resetting the options to defaults

-- local variables
local events = {
    ["CHAT_MSG_CHANNEL"]                = GLOBAL_CHANNELS,
    ["CHAT_MSG_SAY"]                    = CHAT_MSG_SAY,
    ["CHAT_MSG_YELL"]                   = CHAT_MSG_YELL,
    ["CHAT_MSG_GUILD"]                  = CHAT_MSG_GUILD,
    ["CHAT_MSG_OFFICER"]                = CHAT_MSG_OFFICER,
    ["CHAT_MSG_COMMUNITIES_CHANNEL"]    = CLUB_FINDER_COMMUNITIES,
    ["CHAT_MSG_PARTY"]                  = CHAT_MSG_PARTY,
    ["CHAT_MSG_INSTANCE_CHAT"]          = CHAT_MSG_INSTANCE_CHAT,
    ["CHAT_MSG_RAID"]                   = CHAT_MSG_RAID,
    ["CHAT_MSG_WHISPER"]                = CHAT_MSG_WHISPER,
    ["CHAT_MSG_BN_WHISPER"]             = CHAT_MSG_BN_WHISPER,
    ["CHAT_MSG_RAID_WARNING"]           = CHAT_MSG_RAID_WARNING,
}

-- main Ace3 Functions
function PriceAnswer:OnInitialize()
    self.db = LibStub("AceDB-3.0"):New("PriceAnswerDB", defaults, true)
    self.db.RegisterCallback(self, "OnProfileChanged", "RefreshConfig")
    self.db.RegisterCallback(self, "OnProfileCopied", "RefreshConfig")
    self.db.RegisterCallback(self, "OnProfileReset", "RefreshConfig")
    db = self.db.global

    -- set enabled/disabled state as per user prefs
    self:SetEnabledState(db.enableAddOn)

    local options = self:GetOptions()

    -- create Profiles within the options
    options.args.profiles = LibStub("AceDBOptions-3.0"):GetOptionsTable(self.db)

    -- LibAboutPanel-2.0 support
    options.args.aboutTable = self:AboutOptionsTable(addon_folder)
    options.args.aboutTable.order = -1

    LibStub("AceConfig-3.0"):RegisterOptionsTable(addon_folder, options)

    -- register options with WoW's Interface\AddOns\ UI
    Dialog:AddToBlizOptions(addon_folder, L["Price Answer"])

    -- standalone GUI widget is too short, resize (default width: 700, height: 500)
    -- Dialog:SetDefaultSize(addon_folder, 700, 650)

    -- create and register slash command
    self:RegisterChatCommand("priceanswer", "ChatCommand")
    self:RegisterChatCommand("prans", "ChatCommand")
end

function PriceAnswer:OnEnable()
    for event, value in pairs(events) do
        if db.watchedChatChannels[event] then
            self:RegisterEvent(event)
        else
            self:UnregisterEvent(event)
        end
    end
end

function PriceAnswer:OnDisable()
    for event, value in pairs(events) do
        self:UnregisterEvent(event)
    end
end

-- reset the SV database
function PriceAnswer:RefreshConfig()
    db = self.db.global
end

-- handle slash commands
function PriceAnswer:ChatCommand(input)
    if Dialog.OpenFrames[addon_folder] then
        Dialog:Close(addon_folder)
    else
        Dialog:Open(addon_folder)
    end
end

-- secure hook CHAT_MSG_WHISPER for testing purposes when the user sends themself a message
local PriceAnswerSentMessages = {}
hooksecurefunc("SendChatMessage", function(message, _, _, _, _, _, _, mine)
    if mine then
        PriceAnswerSentMessages[message] = 1
    end
end)

-- chat messages event handlers
function PriceAnswer:CHAT_MSG_CHANNEL(event, ...)
    if db.disableInCombat and UnitAffectingCombat("player") then return end
    
    local incomingMessage, senderName = ...
    if not incomingMessage:find(("^%s%%s"):format(L[db.trigger]:gsub("(%W)", "%%%1"))) then return end
    local zoneChannelID = select(7, ...)
    local channel = db.replyChannel.globalChannels == "GLOBAL_CHANNELS" and "CHANNEL" or "WHISPER"

    -- stop listening to the event while we process the incoming message
    self:UnregisterEvent(event)

    local outgoingMessageOne, outgoingMessageTwo = self:GetOutgoingMessage(incomingMessage) -- need to split returned strings; each message must be <= 255 characters

    if outgoingMessageOne ~= "" then
        SendChatMessage(outgoingMessageOne, channel, nil, channel == "WHISPER" and senderName or zoneChannelID)
    end

    if outgoingMessageTwo ~= "" then
        SendChatMessage(outgoingMessageTwo, channel, nil, channel == "WHISPER" and senderName or zoneChannelID)
    end

    if outgoingMessageOne == "" and outgoingMessageTwo == "" then
        SendChatMessage(format(L["Syntax: '%s N item' without quotes, N is an optional quantity, default 1, item is an item link or itemID"], L[db.trigger]), channel, nil, channel == "WHISPER" and senderName or zoneChannelID)
    end

    -- we are done processing the incoming message, listen to the  event again
    self:RegisterEvent(event)
end

function PriceAnswer:CHAT_MSG_SAY(event, ...)
    if db.disableInCombat and UnitAffectingCombat("player") then return end
    
    local incomingMessage, senderName = ...
    if not incomingMessage:find(("^%s%%s"):format(L[db.trigger]:gsub("(%W)", "%%%1"))) then return end

    -- stop listening to the event while we process the incoming message
    self:UnregisterEvent(event)

    local outgoingMessageOne, outgoingMessageTwo = self:GetOutgoingMessage(incomingMessage) -- need to split returned strings; each message must be <= 255 characters

    if outgoingMessageOne ~= "" then
        SendChatMessage(outgoingMessageOne, db.replyChannel.sayChannel, nil, db.replyChannel.sayChannel == "WHISPER" and senderName or nil)
    end

    if outgoingMessageTwo ~= "" then
        SendChatMessage(outgoingMessageTwo, db.replyChannel.sayChannel, nil, db.replyChannel.sayChannel == "WHISPER" and senderName or nil)
    end

    if outgoingMessageOne == "" and outgoingMessageTwo == "" then
        SendChatMessage(format(L["Syntax: '%s N item' without quotes, N is an optional quantity, default 1, item is an item link or itemID"], L[db.trigger]), db.replyChannel.sayChannel, nil, db.replyChannel.sayChannel == "WHISPER" and senderName or nil)
    end

    -- we are done processing the incoming message, listen to the  event again
    self:RegisterEvent(event)
end

function PriceAnswer:CHAT_MSG_YELL(event, ...)
    if db.disableInCombat and UnitAffectingCombat("player") then return end
    
    local incomingMessage, senderName = ...
    if not incomingMessage:find(("^%s%%s"):format(L[db.trigger]:gsub("(%W)", "%%%1"))) then return end

    -- stop listening to the event while we process the incoming message
    self:UnregisterEvent(event)

    local outgoingMessageOne, outgoingMessageTwo = self:GetOutgoingMessage(incomingMessage) -- need to split returned strings; each message must be <= 255 characters

    if outgoingMessageOne ~= "" then
        SendChatMessage(outgoingMessageOne, db.replyChannel.yellChannel, nil, db.replyChannel.yellChannel == "WHISPER" and senderName or nil)
    end

    if outgoingMessageTwo ~= "" then
        SendChatMessage(outgoingMessageTwo, db.replyChannel.yellChannel, nil, db.replyChannel.yellChannel == "WHISPER" and senderName or nil)
    end

    if outgoingMessageOne == "" and outgoingMessageTwo == "" then
        SendChatMessage(format(L["Syntax: '%s N item' without quotes, N is an optional quantity, default 1, item is an item link or itemID"], L[db.trigger]), db.replyChannel.yellChannel, nil, db.replyChannel.yellChannel == "WHISPER" and senderName or nil)
    end

    -- we are done processing the incoming message, listen to the  event again
    self:RegisterEvent(event)
end

function PriceAnswer:CHAT_MSG_GUILD(event, ...)
    if db.disableInCombat and UnitAffectingCombat("player") then return end
    
    local incomingMessage, senderName = ...
    if not incomingMessage:find(("^%s%%s"):format(L[db.trigger]:gsub("(%W)", "%%%1"))) then return end

    -- stop listening to the event while we process the incoming message
    self:UnregisterEvent(event)

    local outgoingMessageOne, outgoingMessageTwo = self:GetOutgoingMessage(incomingMessage) -- need to split returned strings; each message must be <= 255 characters

    if outgoingMessageOne ~= "" then
        SendChatMessage(outgoingMessageOne, db.replyChannel.guildChannel, nil, db.replyChannel.guildChannel == "WHISPER" and senderName or nil)
    end

    if outgoingMessageTwo ~= "" then
        SendChatMessage(outgoingMessageTwo, db.replyChannel.guildChannel, nil, db.replyChannel.guildChannel == "WHISPER" and senderName or nil)
    end

    if outgoingMessageOne == "" and outgoingMessageTwo == "" then
        SendChatMessage(format(L["Syntax: '%s N item' without quotes, N is an optional quantity, default 1, item is an item link or itemID"], L[db.trigger]), db.replyChannel.guildChannel, nil, db.replyChannel.guildChannel == "WHISPER" and senderName or nil)
    end

    -- we are done processing the incoming message, listen to the  event again
    self:RegisterEvent(event)
end

function PriceAnswer:CHAT_MSG_OFFICER(event, ...)
    if db.disableInCombat and UnitAffectingCombat("player") then return end
    
    local incomingMessage, senderName = ...
    if not incomingMessage:find(("^%s%%s"):format(L[db.trigger]:gsub("(%W)", "%%%1"))) then return end

    -- stop listening to the event while we process the incoming message
    self:UnregisterEvent(event)

    local outgoingMessageOne, outgoingMessageTwo = self:GetOutgoingMessage(incomingMessage) -- need to split returned strings; each message must be <= 255 characters

    if outgoingMessageOne ~= "" then
        SendChatMessage(outgoingMessageOne, db.replyChannel.officerChannel, nil, db.replyChannel.officerChannel == "WHISPER" and senderName or nil)
    end

    if outgoingMessageTwo ~= "" then
        SendChatMessage(outgoingMessageTwo, db.replyChannel.officerChannel, nil, db.replyChannel.officerChannel == "WHISPER" and senderName or nil)
    end

    if outgoingMessageOne == "" and outgoingMessageTwo == "" then
        SendChatMessage(format(L["Syntax: '%s N item' without quotes, N is an optional quantity, default 1, item is an item link or itemID"], L[db.trigger]), db.replyChannel.officerChannel, nil, db.replyChannel.officerChannel == "WHISPER" and senderName or nil)
    end

    -- we are done processing the incoming message, listen to the  event again
    self:RegisterEvent(event)
end

function PriceAnswer:CHAT_MSG_PARTY(event, ...)
    if db.disableInCombat and UnitAffectingCombat("player") then return end
    
    local incomingMessage, senderName = ...
    if not incomingMessage:find(("^%s%%s"):format(L[db.trigger]:gsub("(%W)", "%%%1"))) then return end

    -- stop listening to the event while we process the incoming message
    self:UnregisterEvent(event)

    local outgoingMessageOne, outgoingMessageTwo = self:GetOutgoingMessage(incomingMessage) -- need to split returned strings; each message must be <= 255 characters

    if outgoingMessageOne ~= "" then
        SendChatMessage(outgoingMessageOne, db.replyChannel.partyChannel, nil, db.replyChannel.partyChannel == "WHISPER" and senderName or nil)
    end

    if outgoingMessageTwo ~= "" then
        SendChatMessage(outgoingMessageTwo, db.replyChannel.partyChannel, nil, db.replyChannel.partyChannel == "WHISPER" and senderName or nil)
    end

    if outgoingMessageOne == "" and outgoingMessageTwo == "" then
        SendChatMessage(format(L["Syntax: '%s N item' without quotes, N is an optional quantity, default 1, item is an item link or itemID"], L[db.trigger]), db.replyChannel.partyChannel, nil, db.replyChannel.partyChannel == "WHISPER" and senderName or nil)
    end

    -- we are done processing the incoming message, listen to the  event again
    self:RegisterEvent(event)
end

--@version-retail@
function PriceAnswer:CHAT_MSG_INSTANCE_CHAT(event, ...)
    if db.disableInCombat and UnitAffectingCombat("player") then return end
    
    local incomingMessage, senderName = ...
    if not incomingMessage:find(("^%s%%s"):format(L[db.trigger]:gsub("(%W)", "%%%1"))) then return end

    -- stop listening to the event while we process the incoming message
    self:UnregisterEvent(event)

    local outgoingMessageOne, outgoingMessageTwo = self:GetOutgoingMessage(incomingMessage) -- need to split returned strings; each message must be <= 255 characters

    if outgoingMessageOne ~= "" then
        SendChatMessage(outgoingMessageOne, db.replyChannel.instanceChannel, nil, db.replyChannel.instanceChannel == "WHISPER" and senderName or nil)
    end

    if outgoingMessageTwo ~= "" then
        SendChatMessage(outgoingMessageTwo, db.replyChannel.instanceChannel, nil, db.replyChannel.instanceChannel == "WHISPER" and senderName or nil)
    end

    if outgoingMessageOne == "" and outgoingMessageTwo == "" then
        SendChatMessage(format(L["Syntax: '%s N item' without quotes, N is an optional quantity, default 1, item is an item link or itemID"], L[db.trigger]), db.replyChannel.instanceChannel, nil, db.replyChannel.instanceChannel == "WHISPER" and senderName or nil)
    end

    -- we are done processing the incoming message, listen to the  event again
    self:RegisterEvent(event)
end

function PriceAnswer:CHAT_MSG_COMMUNITIES_CHANNEL(event, ...)
    if db.disableInCombat and UnitAffectingCombat("player") then return end
    
    local incomingMessage, senderName = ...
    if not incomingMessage:find(("^%s%%s"):format(L[db.trigger]:gsub("(%W)", "%%%1"))) then return end

    -- stop listening to the event while we process the incoming message
    self:UnregisterEvent(event)

    local outgoingMessageOne, outgoingMessageTwo = self:GetOutgoingMessage(incomingMessage) -- need to split returned strings; each message must be <= 255 characters

    if outgoingMessageOne ~= "" then
        SendChatMessage(outgoingMessageOne, "WHISPER", nil, senderName)
    end

    if outgoingMessageTwo ~= "" then
        SendChatMessage(outgoingMessageTwo, "WHISPER", nil, senderName)
    end

    if outgoingMessageOne == "" and outgoingMessageTwo == "" then
        SendChatMessage(format(L["Syntax: '%s N item' without quotes, N is an optional quantity, default 1, item is an item link or itemID"], L[db.trigger]), "WHISPER", nil, senderName)
    end

    -- we are done processing the incoming message, listen to the  event again
    self:RegisterEvent(event)
end
--@end-version-retail@

function PriceAnswer:CHAT_MSG_RAID(event, ...)
    if db.disableInCombat and UnitAffectingCombat("player") then return end
    
    local incomingMessage, senderName = ...
    if not incomingMessage:find(("^%s%%s"):format(L[db.trigger]:gsub("(%W)", "%%%1"))) then return end

    -- stop listening to the event while we process the incoming message
    self:UnregisterEvent(event)

    local outgoingMessageOne, outgoingMessageTwo = self:GetOutgoingMessage(incomingMessage) -- need to split returned strings; each message must be <= 255 characters

    if outgoingMessageOne ~= "" then
        SendChatMessage(outgoingMessageOne, db.replyChannel.raidChannel, nil, db.replyChannel.raidChannel == "WHISPER" and senderName or nil)
    end

    if outgoingMessageTwo ~= "" then
        SendChatMessage(outgoingMessageTwo, db.replyChannel.raidChannel, nil, db.replyChannel.raidChannel == "WHISPER" and senderName or nil)
    end

    if outgoingMessageOne == "" and outgoingMessageTwo == "" then
        SendChatMessage(format(L["Syntax: '%s N item' without quotes, N is an optional quantity, default 1, item is an item link or itemID"], L[db.trigger]), db.replyChannel.raidChannel, nil, db.replyChannel.raidChannel == "WHISPER" and senderName or nil)
    end

    -- we are done processing the incoming message, listen to the  event again
    self:RegisterEvent(event)
end

function PriceAnswer:CHAT_MSG_RAID_WARNING(event, ...)
    if db.disableInCombat and UnitAffectingCombat("player") then return end
    
    local incomingMessage, senderName = ...
    if not incomingMessage:find(("^%s%%s"):format(L[db.trigger]:gsub("(%W)", "%%%1"))) then return end

    -- stop listening to the event while we process the incoming message
    self:UnregisterEvent(event)

    local outgoingMessageOne, outgoingMessageTwo = self:GetOutgoingMessage(incomingMessage) -- need to split returned strings; each message must be <= 255 characters

    if outgoingMessageOne ~= "" then
        SendChatMessage(outgoingMessageOne, db.replyChannel.raidWarningChannel, nil, db.replyChannel.raidWarningChannel == "WHISPER" and senderName or nil)
    end

    if outgoingMessageTwo ~= "" then
        SendChatMessage(outgoingMessageTwo, db.replyChannel.raidWarningChannel, nil, db.replyChannel.raidWarningChannel == "WHISPER" and senderName or nil)
    end

    if outgoingMessageOne == "" and outgoingMessageTwo == "" then
        SendChatMessage(format(L["Syntax: '%s N item' without quotes, N is an optional quantity, default 1, item is an item link or itemID"], L[db.trigger]), db.replyChannel.raidWarningChannel, nil, db.replyChannel.raidWarningChannel == "WHISPER" and senderName or nil)
    end

    -- we are done processing the incoming message, listen to the  event again
    self:RegisterEvent(event)
end

function PriceAnswer:CHAT_MSG_WHISPER(event, ...)
    if db.disableInCombat and UnitAffectingCombat("player") then return end
    
    local incomingMessage, senderName = ...
    if not incomingMessage:find(("^%s%%s"):format(L[db.trigger]:gsub("(%W)", "%%%1"))) then return end

    if PriceAnswerSentMessages[incomingMessage] then return end
    
    -- stop listening to the event while we process the incoming message
    self:UnregisterEvent(event)

    local outgoingMessageOne, outgoingMessageTwo = self:GetOutgoingMessage(incomingMessage) -- need to split returned strings; each message must be <= 255 characters

    if outgoingMessageOne ~= "" then
        SendChatMessage(outgoingMessageOne, "WHISPER", nil, senderName, nil, nil, nil, true)
    end
    if outgoingMessageTwo ~= "" then
        SendChatMessage(outgoingMessageTwo, "WHISPER", nil, senderName, nil, nil, nil, true)
    end

    if outgoingMessageOne == "" and outgoingMessageTwo == "" then
        SendChatMessage(format(L["Syntax: '%s N item' without quotes, N is an optional quantity, default 1, item is an item link or itemID"], L[db.trigger]), "WHISPER", nil, senderName, nil, nil, nil, true)
    end

    -- we are done processing the incoming message, listen to the  event again
    self:RegisterEvent(event)
end

function PriceAnswer:CHAT_MSG_BN_WHISPER(event, ...)
    if db.disableInCombat and UnitAffectingCombat("player") then return end
    
    local incomingMessage = ...
    local bnSenderID = select(13, ...)
    if not incomingMessage:find(("^%s%%s"):format(L[db.trigger]:gsub("(%W)", "%%%1"))) then return end

    -- stop listening to the event while we process the incoming message
    self:UnregisterEvent(event)

    local outgoingMessageOne, outgoingMessageTwo = self:GetOutgoingMessage(incomingMessage) -- need to split returned strings; each message must be <= 255 characters

    if outgoingMessageOne ~= "" then
        BNSendWhisper(bnSenderID, outgoingMessageOne)
    end

    if outgoingMessageTwo ~= "" then
        BNSendWhisper(bnSenderID, outgoingMessageTwo)
    end

    if outgoingMessageOne == "" and outgoingMessageTwo == "" then
        BNSendWhisper(bnSenderID, format(L["Syntax: '%s N item' without quotes, N is an optional quantity, default 1, item is an item link or itemID"], L[db.trigger]))
    end

    -- we are done processing the incoming message, listen to the  event again
    self:RegisterEvent(event)
end

-- no need to duplicate code for every event
function PriceAnswer:GetOutgoingMessage(incomingMessage)
    -- pattern for "price N item" incoming chat messages
    local pattern = "^" .. (L[db.trigger]:gsub("(%W)", "%%%1")) .. "%s*(%d*)%s*(.*)$"

    local itemCount, tail = strmatch(incomingMessage, pattern)

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
    local dbminbuyoutCopper = self:GetItemValue("dbminbuyout", itemString, itemCount)
    local dbmarketCopper = self:GetItemValue("dbmarket", itemString, itemCount)
    local dbregionmarketavgCopper = self:GetItemValue("dbregionmarketavg", itemString, itemCount)
    local dbhistoricalCopper = self:GetItemValue("dbhistorical", itemString, itemCount)
    local dbregionhistoricalCopper = self:GetItemValue("dbregionhistorical", itemString, itemCount)
    local destroyCopper = self:GetItemValue("destroy", itemString, itemCount)

    -- convert copper coins into human-readable strings "14g55s96c" or nil. must be >= 1c if it isn't nil
    local craftingString = self:ConvertToHumanReadable(craftingCopper)
    local dbminbuyoutString = self:ConvertToHumanReadable(dbminbuyoutCopper)
    local dbmarketString = self:ConvertToHumanReadable(dbmarketCopper)
    local dbregionmarketavgString = self:ConvertToHumanReadable(dbregionmarketavgCopper)
    local dbhistoricalString = self:ConvertToHumanReadable(dbhistoricalCopper)
    local dbregionhistoricalString = self:ConvertToHumanReadable(dbregionhistoricalCopper)
    local destroyString = self:ConvertToHumanReadable(destroyCopper)

    -- build the outgoing message
    local outgoingMessageOne = ""
    local outgoingMessageTwo = ""

    if db.tsmSources["dbmarket"] then
        if dbmarketString then
            outgoingMessageOne = L["Market"] .. " " .. dbmarketString
        end
    end

    if db.tsmSources["dbminbuyout"] then
        if dbminbuyoutString then
            outgoingMessageOne = outgoingMessageOne .. " " .. MINIMUM .. " " .. dbminbuyoutString
        end
    end

    if db.tsmSources["dbhistorical"] then
        if dbhistoricalString then
            outgoingMessageOne = outgoingMessageOne .. " " .. L["Historical"] .. " " .. dbhistoricalString
        end
    end

    if db.tsmSources["dbregionmarketavg"] then
        if dbregionmarketavgString then
            outgoingMessageTwo =  L["Region"] .. " " .. dbregionmarketavgString
        end
    end

    if db.tsmSources["dbregionhistorical"] then
        if dbregionhistoricalString then
            outgoingMessageTwo = outgoingMessageTwo .. " " .. L["Region Historical"] .. " " .. dbregionhistoricalString
        end
    end

    if db.tsmSources["crafting"] then
        if craftingString then
            outgoingMessageTwo = outgoingMessageTwo .. " " .. L["Craft"] .. " " .. craftingString
        end
    end

    if db.tsmSources["destroy"] then
        if destroyString then
            outgoingMessageTwo = outgoingMessageTwo .. " " .. L["Destroy"] .. " " .. destroyString
        end
    end

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
    
    if num_copper > 0 then
        gold = floor(num_copper / 10000)
        silver = (num_copper / 100) % 100
        copper = num_copper % 100

        if gold >= 1 then
            if db.formatLargeNumbers then
                gold = FormatLargeNumber(gold)
                gold_string = format("%sg", gold)
            else
                gold_string = format("%d" .. L["g"], gold)
            end
        end
        if silver >= 1 then
            silver_string = format("%d" .. L["s"], silver)
        end
        if copper >= 1 then
            copper_string = format("%d" .. L["c"], copper)
        end

        return gold_string .. silver_string .. copper_string
    end
    return nil
end