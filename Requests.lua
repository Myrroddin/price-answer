local _, addon = ...
local PriceAnswer = addon.PriceAnswer

local LFG_LIST_LANGUAGE_ENUS = LFG_LIST_LANGUAGE_ENUS
local LFG_LIST_LANGUAGE_DEDE = LFG_LIST_LANGUAGE_DEDE
local LFG_LIST_LANGUAGE_ESES = LFG_LIST_LANGUAGE_ESES
local LFG_LIST_LANGUAGE_ESMX = LFG_LIST_LANGUAGE_ESMX
local LFG_LIST_LANGUAGE_FRFR = LFG_LIST_LANGUAGE_FRFR
local LFG_LIST_LANGUAGE_ITIT = LFG_LIST_LANGUAGE_ITIT
local LFG_LIST_LANGUAGE_KOKR = LFG_LIST_LANGUAGE_KOKR
local LFG_LIST_LANGUAGE_PTBR = LFG_LIST_LANGUAGE_PTBR
local LFG_LIST_LANGUAGE_RURU = LFG_LIST_LANGUAGE_RURU
local LFG_LIST_LANGUAGE_ZHCN = LFG_LIST_LANGUAGE_ZHCN
local LFG_LIST_LANGUAGE_ZHTW = LFG_LIST_LANGUAGE_ZHTW

-- Recognition is independent of the UI language. Each template must describe a
-- complete request; {item} is replaced only after removing a real item link.
local languages = {
	enUS = { name = LFG_LIST_LANGUAGE_ENUS, phrases = {
		"what is {item} worth", "what's {item} worth", "how much for {item}",
		"how much is {item}", "how much is {item} worth", "what does {item} cost",
		"how much does {item} cost", "what is the price of {item}", "what's the price of {item}",
		"what are {item} worth", "how much are {item}", "how much are {item} worth",
		"how much can i sell {item} for", "price check {item}", "pc {item}", "{item} price check"
	} },
	deDE = { name = LFG_LIST_LANGUAGE_DEDE, phrases = {
		"was ist {item} wert", "wie viel ist {item} wert", "wieviel ist {item} wert",
		"was kostet {item}", "wie viel kostet {item}", "wieviel kostet {item}"
	} },
	esES = { name = LFG_LIST_LANGUAGE_ESES, phrases = {
		"cuánto vale {item}", "cuanto vale {item}", "cuánto cuesta {item}",
		"cuanto cuesta {item}", "cuál es el precio de {item}", "cual es el precio de {item}"
	} },
	esMX = { name = LFG_LIST_LANGUAGE_ESMX, phrases = {
		"cuánto vale {item}", "cuanto vale {item}", "cuánto cuesta {item}",
		"cuanto cuesta {item}", "cuál es el precio de {item}", "cual es el precio de {item}"
	} },
	frFR = { name = LFG_LIST_LANGUAGE_FRFR, phrases = {
		"combien vaut {item}", "combien coûte {item}", "combien coute {item}",
		"quel est le prix de {item}", "combien pour {item}"
	} },
	itIT = { name = LFG_LIST_LANGUAGE_ITIT, phrases = {
		"quanto vale {item}", "quanto costa {item}", "qual è il prezzo di {item}"
	} },
	koKR = { name = LFG_LIST_LANGUAGE_KOKR, phrases = {
		"{item} 얼마인가요", "{item} 얼마에요", "{item} 얼마예요", "{item} 시세가 얼마인가요"
	} },
	ptBR = { name = LFG_LIST_LANGUAGE_PTBR, phrases = {
		"quanto vale {item}", "quanto custa {item}", "qual é o preço de {item}",
		"qual e o preco de {item}"
	} },
	ruRU = { name = LFG_LIST_LANGUAGE_RURU, phrases = {
		"сколько стоит {item}", "сколько за {item}", "какая цена у {item}"
	} },
	zhCN = { name = LFG_LIST_LANGUAGE_ZHCN, phrases = {
		"{item}多少钱", "{item}值多少钱", "{item}什么价格", "{item}什么价"
	} },
	zhTW = { name = LFG_LIST_LANGUAGE_ZHTW, phrases = {
		"{item}多少錢", "{item}值多少錢", "{item}什麼價格", "{item}什麼價"
	} }
}

local uppercase = "ÀÁÂÃÄÅÆÇÈÉÊËÌÍÎÏÐÑÒÓÔÕÖØÙÚÛÜÝÞŸŒŠŽАБВГДЕЁЖЗИЙКЛМНОПРСТУФХЦЧШЩЪЫЬЭЮЯ"
local lowercase = "àáâãäåæçèéêëìíîïðñòóôõöøùúûüýþÿœšžабвгдеёжзийклмнопрстуфхцчшщъыьэюя"
local lowerCharacters, lowerMap = {}, {}
for character in lowercase:gmatch("[\194-\244][\128-\191]*") do
	lowerCharacters[#lowerCharacters + 1] = character
end
local index = 0
for character in uppercase:gmatch("[\194-\244][\128-\191]*") do
	index = index + 1
	lowerMap[character] = lowerCharacters[index]
end

local function lower(text)
	local result = text:gsub("[\194-\244][\128-\191]*", function(character)
		return lowerMap[character] or character
	end)
	-- Windows' locale-dependent string.lower can alter UTF-8 lead bytes.
	return (result:gsub("[A-Z]", function(character)
		return string.char(string.byte(character) + 32)
	end))
end

-- Match ASCII whitespace explicitly: locale-dependent %s can consume bytes
-- inside UTF-8 text (for example the non-breaking-space byte in Chinese glyphs).
local function trim(text)
	return (text:gsub("^[ \t\r\n]+", ""):gsub("[ \t\r\n]+$", ""))
end

local function normalize(text)
	text = lower(text):gsub("’", "'"):gsub(" ", " ")
	text = text:gsub("？", "?"):gsub("！", "!"):gsub("。", ".")
	text = trim(text:gsub("[ \t\r\n]+", " "))
	text = text:gsub("^¿[ \t\r\n]*", ""):gsub("[?!.]+$", "")
	text = trim(text)
	return (text:gsub("[ \t\r\n]*{item}[ \t\r\n]*", "{item}"))
end

local function languageKey(locale)
	if locale == "enGB" then return "enUS" end
	return locale
end

local currentLanguage = languageKey(GetLocale())
for _, language in pairs(languages) do
	for i, phrase in ipairs(language.phrases) do language.phrases[i] = normalize(phrase) end
end

function PriceAnswer:GetQuestionLanguages()
	local names = {}
	for key, language in pairs(languages) do names[key] = language.name end
	return names
end

function PriceAnswer:IsQuestionLanguageEnabled(key)
	local enabled = self.db.profile.questionLanguages[key]
	if enabled ~= nil then return enabled end
	return key == "enUS" or key == currentLanguage
end

local function extractLink(text)
	local first, last = text:find("|Hitem:%d+[^|]*|h.-|h")
	if not first or not last then return nil end
	local before, after = text:sub(1, first - 1), text:sub(last + 1)
	-- Include the color wrapper when present, so providers receive the original link.
	local color = before:match("|c%x%x%x%x%x%x%x%x$")
	if color then first = first - #color; before = before:sub(1, -#color - 1) end
	if after:sub(1, 2) == "|r" then last = last + 2; after = after:sub(3) end
	-- Multiple links, other hyperlink types, and literal placeholders are ambiguous.
	if before:find("|H", 1, true) or after:find("|H", 1, true)
		or before:find("{item}", 1, true) or after:find("{item}", 1, true) then return nil end
	return text:sub(first, last), before, after
end

local function parseExplicit(input)
	if input == "" then return nil end
	local link, before, after = extractLink(input)
	if link then
		before = trim(before)
		if trim(after) ~= "" or (before ~= "" and not before:match("^%d+$")) then return nil end
		return link, tonumber(before) or 1
	end
	if input:find("|H", 1, true) then return nil end
	if input:match("^%d+$") then return input, 1 end
	local quantity, item = input:match("^(%d+)[ \t\r\n]+(.+)$")
	if not item then quantity, item = input:match("^(%d+)([^%d \t\r\n].*)$") end
	return item or input, tonumber(quantity) or 1
end

-- Return the item text/link and quantity, or nil for an unrecognized request.
-- One uninterrupted number is always an item ID, never quantity + item ID.
function PriceAnswer:ParseRequest(message)
	if type(message) ~= "string" then return nil end
	local profile = self.db.profile
	local text = trim(message)
	local L = LibStub("AceLocale-3.0"):GetLocale("PriceAnswer")
	local trigger = profile.trigger == "price" and L["price"] or profile.trigger
	local input
	if trigger ~= "" and lower(text:sub(1, #trigger)) == lower(trigger) then
		input = trim(text:sub(#trigger + 1))
	elseif profile.questionTrigger ~= false and text:sub(1, 1) == "?" then
		input = trim(text:sub(2))
	end
	if input then
		local item, quantity = parseExplicit(input)
		if item then return item, quantity end
	end
	if profile.naturalQuestions == false then return nil end
	local link, before, after = extractLink(text)
	if not link then return nil end
	local prefix, quantity = before:match("^(.-)(%d+)[ \t\r\n]*$")
	local question = normalize((prefix or before) .. "{item}" .. after)
	for key, language in pairs(languages) do
		if self:IsQuestionLanguageEnabled(key) then
			for _, phrase in ipairs(language.phrases) do
				if question == phrase then return link, tonumber(quantity) or 1 end
			end
		end
	end
	return nil
end