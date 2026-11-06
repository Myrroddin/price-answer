local _, addon = ...

-- constants
local BN_WHISPER = BN_WHISPER
local CHAT_CHANNELS = CHAT_CHANNELS
local CLUB_FINDER_COMMUNITIES = CLUB_FINDER_COMMUNITIES
local ENABLE = ENABLE
local GENERAL_LABEL = GENERAL_LABEL
local GLOBAL_CHANNELS = GLOBAL_CHANNELS
local GUILD = GUILD
local HELP_LABEL = HELP_LABEL
local INSTANCE_CHAT = INSTANCE_CHAT
local LANGUAGES_LABEL = LANGUAGES_LABEL
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
		if key ~= currentKey and db.addonPriceSources[key] then return true end
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
			width = "relative",
			relWidth = 0.5,
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

local function BuildWatchedChannelArgs()
	local keys = {
		"CHAT_MSG_CHANNEL", "CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_GUILD",
		"CHAT_MSG_OFFICER", "CHAT_MSG_PARTY", "CHAT_MSG_RAID", "CHAT_MSG_RAID_WARNING",
		"CHAT_MSG_WHISPER", "CHAT_MSG_BN_WHISPER", "CHAT_MSG_INSTANCE_CHAT", "CHAT_MSG_COMMUNITIES_CHANNEL"
	}
	local names, args = GetWatchedChannelValues(), {}
	for i, key in ipairs(keys) do
		if names[key] then
			args[key] = {
				order = i, type = "toggle", name = names[key],
				width = "relative", relWidth = 1 / 4,
				get = function() return GetProfileDB().watchedChatChannels[key] end,
				set = function(_, value)
					if not value and not HasOtherWatchedChatChannel(GetProfileDB(), key) then
						PriceAnswer:Print(L["You must enable at least one watched chat channel"])
						return
					end
					GetProfileDB().watchedChatChannels[key] = value
					if value and PriceAnswer:IsEnabled() then
						PriceAnswer:RegisterEvent(key, function(event, ...) PriceAnswer:HandleChatEvent(event, ...) end)
					else
						PriceAnswer:UnregisterEvent(key)
					end
				end
			}
		end
	end
	return args
end

local function BuildQuestionLanguageArgs()
	local names, keys, args = PriceAnswer:GetQuestionLanguages(), {}, {}
	for key in pairs(names) do keys[#keys + 1] = key end
	table.sort(keys, function(a, b)
		if a == "enUS" then return b ~= "enUS" end
		if b == "enUS" then return false end
		return a < b
	end)
	args.description = {
		order = 0, type = "description", width = "relative", relWidth = 1,
		name = L["Recognize these languages independently of your game language. English and your game language are enabled by default"]
	}
	for i, key in ipairs(keys) do
		args[key] = {
			order = i, type = "toggle", name = names[key],
			width = "relative", relWidth = 1 / 4,
			disabled = function() return GetProfileDB().naturalQuestions == false end,
			get = function() return PriceAnswer:IsQuestionLanguageEnabled(key) end,
			set = function(_, value) GetProfileDB().questionLanguages[key] = value end
		}
	end
	return args
end

local function BuildPriceCategoryArgs()
	local args = {
		description = {
			order = 0, type = "description", width = "relative", relWidth = 1,
			name = L["Sources' gold values sent in the reply, if valid"]
		}
	}
	for i, key in ipairs(PriceAnswer:GetPriceCategoryOrder()) do
		args[key] = {
			order = i, type = "toggle", width = "relative", relWidth = 1 / 3,
			name = function() return PriceAnswer:GetPriceCategoryLabels()[key] or key end,
			hidden = function() return PriceAnswer:GetPriceCategoryLabels()[key] == nil end,
			get = function() return GetProfileDB().addonPriceSources[key] end,
			set = function(_, value)
				if not value and not HasOtherPriceCategory(GetProfileDB(), key) then
					PriceAnswer:Print(L["You must enable at least one price category"])
					return
				end
				GetProfileDB().addonPriceSources[key] = value
			end
		}
	end
	return args
end

local function BuildHelpArgs()
	local questions = {
		{ "Q: Why isn't this addon built into TradeSkillMaster?", "A: Price Answer works with several pricing addons independently" },
		{ "Q: The item can be crafted, but I'm not sending crafting costs?", "A: TSM or YAAHA must know a recipe and have prices for its materials" },
		{ "Q: Where is the option to send messages to community chat?", "A: AddOns are not permitted to send messages to community channels; whispering the sender is the only option", retail = true },
		{ "Q: Does the person requesting a price check need a pricing addon?", "A: No. Only the person running Price Answer needs a supported pricing addon" },
		{ "Q: Is there no option to use coins instead of g, s, c?", "A: Sending chat messages does not allow for colour codes; all coins would look the same" },
		{ "Q: But I can see colours in my chat window?", "A: True, because adding a message to your chat window allows colours, whereas sending a chat message to someone else does not" },
		{ "Q: What happens if a selected price category has no data?", "A: Missing prices are omitted. If no selected category has data, no reply is sent" }
	}
	local args = {}
	for i, question in ipairs(questions) do
		args["question" .. i] = {
			order = i, type = "description", width = "relative", relWidth = 1,
			name = L[question[1]] .. "\n" .. L[question[2]] .. "\n ",
			hidden = function() return question.retail and not isStandard end
		}
	end
	return args
end

function PriceAnswer:GetOptions()
	if options then return options end
	options = {
		type = "group", name = L["Price Answer"] .. " " .. addon_version,
		childGroups = "tab",
		args = {
			generalTab = {
				order = 10, type = "group", name = GENERAL_LABEL,
				args = {
					enableAddOn = {
						order = 20,
						name = ENABLE,
						desc = L["Enables / disables the AddOn"],
						type = "toggle",
						width = "relative", relWidth = 1 / 3,
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
						width = "relative", relWidth = 1 / 3,
						get = function() return GetProfileDB().disableInCombat end,
						set = function(_, value) GetProfileDB().disableInCombat = value end
					},
					formatLargeNumbers = {
						order = 40,
						name = L["Format large gold numbers"],
						desc = L["Turns 9999g into 9,999g"],
						type = "toggle",
						width = "relative", relWidth = 1 / 3,
						get = function() return GetProfileDB().formatLargeNumbers end,
						set = function(_, value) GetProfileDB().formatLargeNumbers = value end
					},
				}
			},
			incomingMessagesTab = {
				order = 20, type = "group", name = L["Incoming messages"],
				args = {
					watchedChatChannels = {
						order = 10, type = "group", inline = true, name = CHAT_CHANNELS,
						args = BuildWatchedChannelArgs()
					},
					trigger = {
						type = "input",
						name = L["The trigger"],
						desc = L["Any symbol, word, or phrase that triggers sending price answers"],
						order = 30,
						width = "relative", relWidth = 1,
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
					},
					questionTrigger = {
						order = 40,
						type = "toggle",
						width = "relative", relWidth = 0.5,
						name = L["Allow ? requests"],
						desc = L["Also recognize ? as a price request prefix"],
						get = function() return GetProfileDB().questionTrigger end,
						set = function(_, value) GetProfileDB().questionTrigger = value end
					},
					naturalQuestions = {
						order = 50,
						type = "toggle",
						width = "relative", relWidth = 0.5,
						name = L["Recognize price questions"],
						desc = L["Answer recognized price questions containing exactly one item link"],
						get = function() return GetProfileDB().naturalQuestions end,
						set = function(_, value) GetProfileDB().naturalQuestions = value end
					},
					questionLanguages = {
						order = 60, type = "group", inline = true, name = LANGUAGES_LABEL,
						args = BuildQuestionLanguageArgs()
					}
				}
			},
			outgoingMessagesTab = {
				order = 30, type = "group", name = L["Outgoing messages"],
				args = BuildOutgoingMessageArgs()
			},
			priceOptionsTab = {
				order = 40, type = "group", name = L["Price categories"],
				args = BuildPriceCategoryArgs()
			},
			helpTab = {
				order = 50, type = "group", name = HELP_LABEL,
				args = BuildHelpArgs()
			}
		}
	}
	return options
end