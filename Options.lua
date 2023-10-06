local PriceAnswer = LibStub("AceAddon-3.0"):GetAddon("PriceAnswer")
local L = LibStub("AceLocale-3.0"):GetLocale("PriceAnswer")
local addon_version = GetAddOnMetadata("PriceAnswer", "Version")
local TSM_API = TSM_API
local isMainline = WOW_PROJECT_ID == WOW_PROJECT_MAINLINE -- not any "classic" version of the game

function PriceAnswer:GetOptions()
    local db = self.db.global
    local options = {
        type = "group",
        order = 10,
        name = L["Price Answer"] .. " " .. addon_version,
        childGroups = "tab",
        args = {
            lineBreak1 = {
                type = "header",
                order = 10,
                name = "",
            },
            enableAddOn = {
                order = 20,
                name = ENABLE,
                desc = L["Enables / disables the AddOn"],
                descStyle = "inline",
                width = 1.5,
                type = "toggle",
                get = function() return db.enableAddOn end,
                set = function(info, value)
                    db.enableAddOn = value
                    if value then
                        self:OnEnable()
                    else
                        self:OnDisable()
                    end
                end
            },
            disableInCombat = {
                order = 30,
                name = L["Disable in combat"],
                desc = L["Stops watching chat channels while you are in combat"],
                descStyle = "inline",
                width = 1.5,
                type = "toggle",
                get = function() return db.disableInCombat end,
                set = function(info, value) db.disableInCombat = value end
            },
            formatLargeNumbers = {
                order = 40,
                name = L["Format large gold numbers"],
                desc = L["Turns 9999g into 9,999g"],
                descStyle = "inline",
                width = 1.5,
                type = "toggle",
                get = function() return db.formatLargeNumbers end,
                set = function(info, value) db.formatLargeNumbers = value end
            },
            lineBreak2 = {
                order = 50,
                type = "header",
                name = "",
            },
            incomingMessagesTab = {
                order = 60,
                name = L["Incoming messages"],
                type = "group",
                args = {
                    watchedChatChannels = {
                        type = "multiselect",
                        name = L["Watched chat channels"],
                        order = 10,
                        values = function()
                            local channels = {
                                ["CHAT_MSG_CHANNEL"]                = GLOBAL_CHANNELS,
                                ["CHAT_MSG_SAY"]                    = CHAT_MSG_SAY,
                                ["CHAT_MSG_YELL"]                   = CHAT_MSG_YELL,
                                ["CHAT_MSG_GUILD"]                  = CHAT_MSG_GUILD,
                                ["CHAT_MSG_OFFICER"]                = CHAT_MSG_OFFICER,
                                ["CHAT_MSG_PARTY"]                  = CHAT_MSG_PARTY,
                                ["CHAT_MSG_RAID"]                   = CHAT_MSG_RAID,
                                ["CHAT_MSG_WHISPER"]                = CHAT_MSG_WHISPER,
                                ["CHAT_MSG_BN_WHISPER"]             = CHAT_MSG_BN_WHISPER,
                                ["CHAT_MSG_RAID_WARNING"]           = CHAT_MSG_RAID_WARNING,
                            }
                            if isMainline then
                                channels["CHAT_MSG_COMMUNITIES_CHANNEL"]    = CLUB_FINDER_COMMUNITIES
                                channels["CHAT_MSG_INSTANCE_CHAT"]          = CHAT_MSG_INSTANCE_CHAT
                            end
                            return channels
                        end,
                        get = function(info, key_name)
                            if db.watchedChatChannels[key_name] then
                                self:RegisterEvent(tostring(key_name))
                            else
                                self:UnregisterEvent(tostring(key_name))
                            end
                            return db.watchedChatChannels[key_name]
                        end,
                        set = function(info, key_name, value)
                            db.watchedChatChannels[key_name] = value
                            if db.watchedChatChannels[key_name] then
                                self:RegisterEvent(tostring(key_name))
                            else
                                self:UnregisterEvent(tostring(key_name))
                            end
                        end
                    },
                    lineBreak3 = {
                        order = 20,
                        type = "header",
                        name = "",
                    },
                    trigger = {
                        type = "input",
                        name = L["The trigger"],
                        desc = L["Any symbol, word, or phrase that triggers sending price answers"],
                        order = 30,
                        width = "full",
                        validate = function(info, value)
                            value = value:trim()
                            value = strlen(value) > 0 and value or nil
                            if value then
                                return true
                            else
                                self:Print(L["The trigger must be one or more non-space characters, a word, or a phrase (can contain spaces between words in the phrase)"])
                                return false
                            end
                        end,
                        get = function() return db.trigger end,
                        set = function(info, value) db.trigger = value:trim() end
                    }
                }
            },
            outgoingMessagesTab = {
                order = 70,
                type = "group",
                name = L["Outgoing messages"],
                args = {
                    sayChannel = {
                        type = "select",
                        style = "dropdown",
                        name = SAY,
                        desc = L["How do you want to answer this channel"],
                        order = 10,
                        values = {
                            ["WHISPER"]                         = WHISPER,
                            ["SAY"]                             = SAY,
                        },
                        get = function()  return db.replyChannel.sayChannel end,
                        set = function(info, value) db.replyChannel.sayChannel = value end
                    },
                    yellChannel = {
                        type = "select",
                        style = "dropdown",
                        name = YELL,
                        desc = L["How do you want to answer this channel"],
                        order = 20,
                        values = {
                            ["WHISPER"]                         = WHISPER,
                            ["YELL"]                            = YELL,
                        },
                        get = function() return db.replyChannel.yellChannel end,
                        set = function(info, value) db.replyChannel.yellChannel = value end
                    },
                    guildChannel = {
                        type = "select",
                        style = "dropdown",
                        name = GUILD,
                        desc = L["How do you want to answer this channel"],
                        order = 30,
                        values = {
                            ["GUILD"]                           = GUILD,
                            ["WHISPER"]                         = WHISPER,
                        },
                        get = function() return db.replyChannel.guildChannel end,
                        set = function(info, value) db.replyChannel.guildChannel = value end
                    },
                    officerChannel = {
                        type = "select",
                        style = "dropdown",
                        name = OFFICER,
                        desc = L["How do you want to answer this channel"],
                        order = 40,
                        values = {
                            ["OFFICER"]                     = OFFICER,
                            ["WHISPER"]                     = WHISPER,
                        },
                        get = function() return db.replyChannel.officerChannel end,
                        set = function(info, value) db.replyChannel.officerChannel = value end
                    },
                    partyChannel = {
                        type = "select",
                        style = "dropdown",
                        name = PARTY,
                        desc = L["How do you want to answer this channel"],
                        order = 50,
                        values = {
                            ["PARTY"]                           = PARTY,
                            ["WHISPER"]                         = WHISPER,
                        },
                        get = function() return db.replyChannel.partyChannel end,
                        set = function(info, value) db.replyChannel.partyChannel = value end
                    },
                    raidChannel = {
                        type = "select",
                        style = "dropdown",
                        name = RAID,
                        desc = L["How do you want to answer this channel"],
                        order = 60,
                        values = {
                            ["RAID"]                            = RAID,
                            ["WHISPER"]                         = WHISPER,
                        },
                        get = function() return db.replyChannel.raidChannel end,
                        set = function(info, value) db.replyChannel.raidChannel = value end
                    },
                    raidWarningChannel = {
                        type = "select",
                        style = "dropdown",
                        name = RAID_WARNING,
                        desc = L["How do you want to answer this channel"],
                        order = 70,
                        values = {
                            ["RAID"]                            = RAID,
                            ["WHISPER"]                         = WHISPER,
                            ["RAID_WARNING"]                    = RAID_WARNING,
                        },
                        get = function() return db.replyChannel.raidWarningChannel end,
                        set = function(info, value) db.replyChannel.raidWarningChannel = value end
                    },
                    instanceChannel = {
                        type = "select",
                        style = "dropdown",
                        name = INSTANCE,
                        desc = L["How do you want to answer this channel"],
                        order = 80,
                        values = {
                            ["INSTANCE"]                        = INSTANCE,
                            ["WHISPER"]                         = WHISPER,
                        },
                        get = function() return db.replyChannel.instanceChannel end,
                        set = function(info, value) db.replyChannel.instanceChannel = value end,
                        hidden = function() return not isMainline end,
                        disabled = function() return not isMainline end
                    }
                }
            },
            tsmOptionsTab = {
                order = 80,
                name = L["TSM price sources"],
                type = "group",
                args = {
                    tsmSources = {
                        type = "multiselect",
                        name = L["Sources' gold values sent in the reply, if valid"],
                        order = 10,
                        values = {
                            ["dbmarket"]                        = TSM_API.GetPriceSourceDescription("dbmarket"),
                            ["dbminbuyout"]                     = TSM_API.GetPriceSourceDescription("dbminbuyout"),
                            ["destroy"]                         = TSM_API.GetPriceSourceDescription("destroy"),
                            ["dbregionmarketavg"]               = TSM_API.GetPriceSourceDescription("dbregionmarketavg"),
                            ["dbhistorical"]                    = TSM_API.GetPriceSourceDescription("dbhistorical"),
                            ["dbregionhistorical"]              = TSM_API.GetPriceSourceDescription("dbregionhistorical"),
                            ["crafting"]                        = TSM_API.GetPriceSourceDescription("crafting"),
                            ["dbrecent"]                        = TSM_API.GetPriceSourceDescription("dbrecent"),
                        },
                        get = function(info, key_name) return db.tsmSources[key_name] end,
                        set = function(info, key_name, value) db.tsmSources[key_name] = value end
                    }
                }
            },
            helpTab = {
                order = 90,
                name = HELP_LABEL,
                type = "group",
                args = {
                    builtIntoTSMQ = {
                        order = 10,
                        type = "description",
                        name = "* " .. L["Q: Why isn't this addon built into TradeSkillMaster?"]
                    },
                    builtIntoTSMA = {
                        order = 20,
                        type = "description",
                        name = "* " .. L["A: That cannot be done without breaking TradeSkillMaster"]
                    },
                    spacer1 = {
                        order = 25,
                        type = "description",
                        name = ""
                    },
                    craftingQ = {
                        order = 30,
                        type = "description",
                        name = "* " .. L["Q: The item can be crafted, but I'm not sending crafting costs?"]
                    },
                    craftingA = {
                        order = 40,
                        type = "description",
                        name = "* " .. L["A: At least one of your same-faction, same-realm characters must know the recipe"]
                    },
                    spacer2 = {
                        order = 45,
                        type = "description",
                        name = ""
                    },
                    communitiesQ = {
                        order = 50,
                        type = "description",
                        name = "* " .. L["Q: Where is the option to send messages to community chat?"]
                    },
                    communitiesA = {
                        order = 60,
                        type = "description",
                        name = "* " .. L["A: AddOns are not permitted to send messages to community channels; whispering the sender is the only option"]
                    },
                    spacer3 = {
                        order = 65,
                        type = "description",
                        name = ""
                    },
                    senderTSMQ = {
                        order = 70,
                        type = "description",
                        name = "* " .. L["Q: Does the person sending the price chack need TradeSkillMaster for Price Answer to work?"]
                    },
                    senderTSMA = {
                        order = 80,
                        type = "description",
                        name = "* " .. L["A: No, which is the point. You need TradeSkillMaster for Price Answer to work"]
                    },
                    spacer4 = {
                        order = 85,
                        type = "description",
                        name = ""
                    },
                    coinsQ = {
                        order = 90,
                        type = "description",
                        name = "* " .. L["Q: Is there no option to use coins instead of g, s, c?"]
                    },
                    coinsA = {
                        order = 100,
                        type = "description",
                        name = "* " .. L["A: Sending chat messages does not allow for colour codes; all coins would look the same"]
                    },
                    spacer5 = {
                        order = 105,
                        type = "description",
                        name = ""
                    },
                    coloursQ = {
                        order = 110,
                        type = "description",
                        name = "* " .. L["Q: But I can see colours in my chat window?"]
                    },
                    coloursA = {
                        order = 120,
                        type = "description",
                        name = "* " .. L["A: True, because adding a message to your chat window allows colours, whereas sending a chat message to someone else does not"]
                    },
                    spacer6 = {
                        order = 125,
                        type = "description",
                        name = ""
                    },
                    disableTSMpricesQ = {
                        order = 130,
                        type = "description",
                        name = "* " .. L["Q: What happens if I toggle off all TradeSkillMaster prices?"]
                    },
                    disableTSMpricesA = {
                        order = 140,
                        type = "description",
                        name = "* " .. L["A: The AddOn will process the incoming message, and erroneously tell the sender their syntax is wrong. You should leave one or more TSM prices enabled"]
                    }
                }
            }
        }
    }
    return options
end