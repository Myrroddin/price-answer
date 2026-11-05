local _, addon = ...

-- constants
local BN_WHISPER = BN_WHISPER
local CLUB_FINDER_COMMUNITIES = CLUB_FINDER_COMMUNITIES
local DISABLE = DISABLE
local ENABLE = ENABLE
local GLOBAL_CHANNELS = GLOBAL_CHANNELS
local GUILD = GUILD
local HELP_LABEL = HELP_LABEL
local INSTANCE_CHAT = INSTANCE_CHAT
local JUST_OR = JUST_OR
local LibStub = LibStub
local OFFICER = OFFICER
local PARTY = PARTY
local RAID = RAID
local RAID_WARNING = RAID_WARNING
local SAY = SAY
local WHISPER = WHISPER
local YELL = YELL

local isStandard = WOW_PROJECT_ID == WOW_PROJECT_MAINLINE

-- Lua functions
local GetAddOnMetadata = C_AddOns.GetAddOnMetadata
local pairs = pairs
local strlen = strlen
local strtrim = strtrim
local type = type

-- addon references
local PriceAnswer = addon.PriceAnswer
local L = LibStub("AceLocale-3.0"):GetLocale("PriceAnswer")
local addon_version = GetAddOnMetadata("PriceAnswer", "Version") or ""

-- locals
local options

-- Fetch the current profile for every callback, including after profile switches.
local function GetProfileDB()
	return PriceAnswer.db.profile
end

-- returns the list of chat events monitored by the addon (built once per call, includes retail-only channels)
local function GetWatchedChannelValues()
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
		["CHAT_MSG_RAID_WARNING"] = RAID_WARNING,
		["CHAT_MSG_INSTANCE_CHAT"] = INSTANCE_CHAT
	}
	if isStandard then
		channels["CHAT_MSG_COMMUNITIES_CHANNEL"] = CLUB_FINDER_COMMUNITIES
	end
	return channels
end

local function HasOtherWatchedChatChannel(db, currentKey)
	for key in pairs(GetWatchedChannelValues()) do
		if key ~= currentKey and db.watchedChatChannels[key] then
			return true
		end
	end
	return false
end

local function HasOtherPriceCategory(db, currentKey)
	for key in pairs(PriceAnswer:GetPriceCategoryLabels()) do
		if key ~= currentKey and db.tsmSources[key] then return true end
	end
	return false
end

local function BuildOutgoingMessageArgs()
	local channelOptions = {
		{ key = "CHAT_MSG_GUILD", name = GUILD, order = 10, values = { WHISPER = WHISPER, GUILD = GUILD } },
		{ key = "CHAT_MSG_OFFICER", name = OFFICER, order = 20, values = { WHISPER = WHISPER, OFFICER = OFFICER } },
		{ key = "CHAT_MSG_PARTY", name = PARTY, order = 30, values = { WHISPER = WHISPER, PARTY = PARTY } },
		{ key = "CHAT_MSG_RAID", name = RAID, order = 40, values = { WHISPER = WHISPER, RAID = RAID } },
		{ key = "CHAT_MSG_RAID_WARNING", name = RAID_WARNING, order = 50, values = { WHISPER = WHISPER, RAID = RAID, RAID_WARNING = RAID_WARNING } },
		{ key = "CHAT_MSG_INSTANCE_CHAT", name = INSTANCE_CHAT, order = 60, values = { WHISPER = WHISPER, INSTANCE_CHAT = INSTANCE_CHAT } }
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
			get = function()
				return GetProfileDB().replyChannel[opt.key]
			end,
			set = function(_, value)
				GetProfileDB().replyChannel[opt.key] = value
			end,
			hidden = opt.hidden,
			disabled = opt.disabled
		}
	end

	return args
end

function PriceAnswer:GetOptions()
	if options then return options end -- build options table once and reuse it
	options = {
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
				get = function() return GetProfileDB().enableAddOn end,
				set = function(_, value)
					GetProfileDB().enableAddOn = value
					if value then
						self:Enable()
					else
						self:Disable()
					end
				end
			},
			disableInCombat = {
				order = 30,
				name = L["Disable in combat"],
				desc = L["Prevents the AddOn from responding to messages while you are in combat"],
				type = "toggle",
				get = function() return GetProfileDB().disableInCombat end,
				set = function(_, value) GetProfileDB().disableInCombat = value end
			},
			formatLargeNumbers = {
				order = 40,
				name = L["Format large gold numbers"],
				desc = L["Turns 9999g into 9,999g"],
				type = "toggle",
				get = function() return GetProfileDB().formatLargeNumbers end,
				set = function(_, value) GetProfileDB().formatLargeNumbers = value end
			},
			lineBreak2 = {
				order = 50,
				type = "header",
				name = ""
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
						values = GetWatchedChannelValues,
						get = function(_, key_name)
							return GetProfileDB().watchedChatChannels[key_name]
						end,
						set = function(_, key_name, value)
							if (not value) and not HasOtherWatchedChatChannel(GetProfileDB(), key_name) then
								self:Print(L["You must enable at least one watched chat channel"])
								return
							end
							GetProfileDB().watchedChatChannels[key_name] = value
							if value and self:IsEnabled() then
								self:RegisterEvent(key_name, function(event, ...) self:HandleChatEvent(event, ...) end)
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
							value = type(value) == "string" and strtrim(value) or ""
							value = strlen(value) > 0 and value or nil
							if value then
								return true
							else
								self:Print(L["The trigger must be one or more non-space characters, a word, or a phrase (can contain spaces between words in the phrase)"])
								return false
							end
						end,
						get = function()
							return GetProfileDB().trigger == "price" and L["price"] or GetProfileDB().trigger
						end,
						set = function(_, value)
							GetProfileDB().trigger = type(value) == "string" and strtrim(value) or GetProfileDB().trigger
						end
					}
				}
			},
			outgoingMessagesTab = {
				order = 70,
				type = "group",
				name = L["Outgoing messages"],
				args = BuildOutgoingMessageArgs()
			},
			tsmOptionsTab = {
				order = 80,
				name = L["Price categories"],
				type = "group",
				args = {
					tsmSources = {
						type = "multiselect",
						name = L["Sources' gold values sent in the reply, if valid"],
						order = 10,
						values = function() return self:GetPriceCategoryLabels() end,
						get = function(_, key_name)
							return GetProfileDB().tsmSources[key_name]
						end,
						set = function(_, key_name, value)
							if (not value) and not HasOtherPriceCategory(GetProfileDB(), key_name) then
								self:Print(L["You must enable at least one price category"])
								GetProfileDB().tsmSources.vendorsell = true
								return
							end
							GetProfileDB().tsmSources[key_name] = value
						end
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
						name = "* " .. L["A: Price Answer works with several pricing addons independently"]
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
						name = "* " .. L["A: TSM or YAAHA must know a recipe and have prices for its materials"]
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
						hidden = function() return not isStandard end,
						disabled = function() return not isStandard end
					},
					communitiesA = {
						order = 80,
						type = "description",
						name = "* " .. L["A: AddOns are not permitted to send messages to community channels; whispering the sender is the only option"],
						hidden = function() return not isStandard end,
						disabled = function() return not isStandard end
					},
					spacer3 = {
						order = 90,
						type = "description",
						name = ""
					},
					senderTSMQ = {
						order = 100,
						type = "description",
						name = "* " .. L["Q: Does the person requesting a price check need a pricing addon?"]
					},
					senderTSMA = {
						order = 110,
						type = "description",
						name = "* " .. L["A: No. Only the person running Price Answer needs a supported pricing addon"]
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
						name = "* " .. L["Q: What happens if a selected price category has no data?"]
					},
					disableTSMpricesA = {
						order = 200,
						type = "description",
						name = "* " .. L["A: Missing prices are omitted. If no selected category has data, no reply is sent"]
					}
				}
			}
		}
	}
	return options
end