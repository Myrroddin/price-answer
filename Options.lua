-- Localize frequently used globals and constants for performance
local GetAddOnMetadata, TSM_API, LibStub = C_AddOns.GetAddOnMetadata, TSM_API, LibStub
local strlen, ENABLE, DISABLE, JUST_OR = strlen, ENABLE, DISABLE, JUST_OR
local SAY, YELL, GUILD, OFFICER, PARTY, RAID, WHISPER, BN_WHISPER = SAY, YELL, GUILD, OFFICER, PARTY, RAID, WHISPER, BN_WHISPER
local RAID_WARNING, INSTANCE_CHAT, CLUB_FINDER_COMMUNITIES, HELP_LABEL = RAID_WARNING, INSTANCE_CHAT, CLUB_FINDER_COMMUNITIES, HELP_LABEL
local isMainline, isMists = WOW_PROJECT_ID == WOW_PROJECT_MAINLINE, WOW_PROJECT_ID == WOW_PROJECT_MISTS_CLASSIC

local PriceAnswer = LibStub("AceAddon-3.0"):GetAddon("PriceAnswer")
local L = LibStub("AceLocale-3.0"):GetLocale("PriceAnswer")
local addon_version = GetAddOnMetadata("PriceAnswer", "Version")

-- Cache TSM price source descriptions at startup
local TSMPriceSourceDescriptions = {}
local TSMPriceSourceKeys = TSM_API.GetPriceSourceKeys and TSM_API.GetPriceSourceKeys() or {
	"dbmarket", "dbminbuyout", "destroy", "dbregionmarketavg", "dbhistorical", "dbregionhistorical", "crafting", "dbrecent"
}
for _, key in ipairs(TSMPriceSourceKeys) do
	if TSM_API.GetPriceSourceDescription then
		TSMPriceSourceDescriptions[key] = TSM_API.GetPriceSourceDescription(key)
	end
end

function PriceAnswer:GetOptions()
	local db = self.db.profile
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
				name = ENABLE .. " " .. JUST_OR .. " " .. DISABLE,
				desc = L["Enables / disables the AddOn"],
				type = "toggle",
				get = function() return db.enableAddOn end,
				set = function(_, value)
					db.enableAddOn = value
					if value then
						self:Enable()
					else
						self:Disable()
					end
				end
			},
			formatLargeNumbers = {
				order = 30,
				name = L["Format large gold numbers"],
				desc = L["Turns 9999g into 9,999g"],
				type = "toggle",
				get = function() return db.formatLargeNumbers end,
				set = function(_, value) db.formatLargeNumbers = value end
			},
			lineBreak2 = {
				order = 40,
				type = "header",
				name = ""
			},
			incomingMessagesTab = {
				order = 50,
				name = L["Incoming messages"],
				type = "group",
				args = {
					watchedChatChannels = {
						type = "multiselect",
						name = L["Watched chat channels"],
						order = 10,
						values = function()
							local channels = {
								["CHAT_MSG_CHANNEL"] = GLOBAL_CHANNELS,
								["CHAT_MSG_SAY"] = SAY,
								["CHAT_MSG_YELL"] = YELL,
								["CHAT_MSG_GUILD"] = GUILD,
								["CHAT_MSG_OFFICER"] = OFFICER,
								["CHAT_MSG_PARTY"] = PARTY,
								["CHAT_MSG_RAID"] = RAID,
								["CHAT_MSG_WHISPER"] = WHISPER,
								["CHAT_MSG_BN_WHISPER"] = BN_WHISPER,
								["CHAT_MSG_RAID_WARNING"] = RAID_WARNING
							}
							if isMists or isMainline then
								channels["CHAT_MSG_INSTANCE_CHAT"] = INSTANCE_CHAT
							end
							if isMainline then
								channels["CHAT_MSG_COMMUNITIES_CHANNEL"] = CLUB_FINDER_COMMUNITIES
							end
							return channels
						end,
						get = function(_, key_name)
							return db.watchedChatChannels[key_name]
						end,
						set = function(_, key_name, value)
							db.watchedChatChannels[key_name] = value
							if db.watchedChatChannels[key_name] then
								self:RegisterEvent(key_name, "HandleChatEvent")
							else
								self:UnregisterEvent(key_name)
							end
						end
					},
					lineBreak3 = {
						order = 20,
						type = "header",
						name = ""
					},
					trigger = {
						type = "input",
						name = L["The trigger"],
						desc = L["Any symbol, word, or phrase that triggers sending price answers"],
						order = 30,
						width = "full",
						validate = function(_, value)
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
						set = function(_, value) db.trigger = value:trim() end
					}
				}
			},
			outgoingMessagesTab = {
				order = 60,
				type = "group",
				name = L["Outgoing messages"],
				args = function()
					local channelOptions = {
						{ key = "CHAT_MSG_SAY", name = SAY, order = 10, values = { WHISPER = WHISPER, SAY = SAY } },
						{ key = "CHAT_MSG_YELL", name = YELL, order = 20, values = { WHISPER = WHISPER, YELL = YELL } },
						{ key = "CHAT_MSG_GUILD", name = GUILD, order = 30, values = { WHISPER = WHISPER, GUILD = GUILD } },
						{ key = "CHAT_MSG_OFFICER", name = OFFICER, order = 40, values = { WHISPER = WHISPER, OFFICER = OFFICER } },
						{ key = "CHAT_MSG_PARTY", name = PARTY, order = 50, values = { WHISPER = WHISPER, PARTY = PARTY } },
						{ key = "CHAT_MSG_RAID", name = RAID, order = 60, values = { WHISPER = WHISPER, RAID = RAID } },
						{ key = "CHAT_MSG_RAID_WARNING", name = RAID_WARNING, order = 70, values = { WHISPER = WHISPER, RAID = RAID, RAID_WARNING = RAID_WARNING } },
						{ key = "CHAT_MSG_INSTANCE_CHAT", name = INSTANCE_CHAT, order = 80, values = { WHISPER = WHISPER, INSTANCE_CHAT = INSTANCE_CHAT }, hidden = function() return not (isMists or isMainline) end, disabled = function() return not (isMists or isMainline) end }
					}
					local args = {}
					for i = 1, #channelOptions do
						local opt = channelOptions[i]
						args[opt.key] = {
							type = "select",
							style = "dropdown",
							name = opt.name,
							desc = L["How do you want to answer this channel"],
							order = opt.order,
							values = opt.values,
							get = function() return db.replyChannel[opt.key] end,
							set = function(_, value) db.replyChannel[opt.key] = value end,
							hidden = opt.hidden,
							disabled = opt.disabled
						}
					end
					return args
				end
			},
			tsmOptionsTab = {
				order = 70,
				name = L["TSM price sources"],
				type = "group",
				args = {
					tsmSources = {
						type = "multiselect",
						name = L["Sources' gold values sent in the reply, if valid"],
						order = 10,
						values = function()
							local sources = {}
							for _, key in ipairs(TSMPriceSourceKeys) do
								sources[key] = TSMPriceSourceDescriptions[key] or key
							end
							if isMainline and TSM_API.GetPriceSourceDescription then
								sources["oerealm"] = TSM_API.GetPriceSourceDescription("oerealm")
							end
							return sources
						end,
						get = function(_, key_name) return db.tsmSources[key_name] end,
						set = function(_, key_name, value) db.tsmSources[key_name] = value end
					}
				}
			},
			helpTab = {
				order = 80,
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
						order = 30,
						type = "description",
						name = ""
					},
					craftingQ = {
						order = 40,
						type = "description",
						name = "* " .. L["Q: The item can be crafted, but I'm not sending crafting costs?"]
					},
					craftingA = {
						order = 50,
						type = "description",
						name = "* " .. L["A: At least one of your same-faction, same-realm characters must know the recipe"]
					},
					spacer2 = {
						order = 60,
						type = "description",
						name = ""
					},
					communitiesQ = {
						order = 70,
						type = "description",
						name = "* " .. L["Q: Where is the option to send messages to community chat?"],
						hidden = function() return not isMainline end,
						disabled = function() return not isMainline end
					},
					communitiesA = {
						order = 80,
						type = "description",
						name = "* " .. L["A: AddOns are not permitted to send messages to community channels; whispering the sender is the only option"],
						hidden = function() return not isMainline end,
						disabled = function() return not isMainline end
					},
					spacer3 = {
						order = 90,
						type = "description",
						name = ""
					},
					senderTSMQ = {
						order = 100,
						type = "description",
						name = "* " .. L["Q: Does the person sending the price chack need TradeSkillMaster for Price Answer to work?"]
					},
					senderTSMA = {
						order = 110,
						type = "description",
						name = "* " .. L["A: No, which is the point. You need TradeSkillMaster for Price Answer to work"]
					},
					spacer4 = {
						order = 120,
						type = "description",
						name = ""
					},
					coinsQ = {
						order = 130,
						type = "description",
						name = "* " .. L["Q: Is there no option to use coins instead of g, s, c?"]
					},
					coinsA = {
						order = 140,
						type = "description",
						name = "* " .. L["A: Sending chat messages does not allow for colour codes; all coins would look the same"]
					},
					spacer5 = {
						order = 150,
						type = "description",
						name = ""
					},
					coloursQ = {
						order = 160,
						type = "description",
						name = "* " .. L["Q: But I can see colours in my chat window?"]
					},
					coloursA = {
						order = 170,
						type = "description",
						name = "* " .. L["A: True, because adding a message to your chat window allows colours, whereas sending a chat message to someone else does not"]
					},
					spacer6 = {
						order = 180,
						type = "description",
						name = ""
					},
					disableTSMpricesQ = {
						order = 190,
						type = "description",
						name = "* " .. L["Q: What happens if I toggle off all TradeSkillMaster prices?"]
					},
					disableTSMpricesA = {
						order = 200,
						type = "description",
						name = "* " .. L["A: The AddOn will process the incoming message, and erroneously tell the sender their syntax is wrong. You should leave one or more TSM prices enabled"]
					}
				}
			}
		}
	}
	return options
end