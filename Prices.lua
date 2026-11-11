local _, addon = ...

local PriceAnswer = addon.PriceAnswer
local L = LibStub("AceLocale-3.0"):GetLocale("PriceAnswer")
local MERCHANT = MERCHANT
local SELL_PRICE = SELL_PRICE
local isStandard = WOW_PROJECT_ID == WOW_PROJECT_MAINLINE

-- Keep the original keys so existing source selections survive the provider change.
local categories = {
	{ key = "dbminbuyout", label = "Cheapest Auction", tsm = "dbminbuyout", yaaha = "minBuyout", simple = "mbo", aucSource = "aucminbuyout", am = "GetLowestPrice", atr = true },
	{ key = "dbrecent", label = "Current Market Value", tsm = "dbrecent", yaaha = "currentMarketValue", simple = "avgday", aucLabel = "Daily Average" },
	{ key = "midweek", label = "3-Day Market Value", yaaha = "midweekMarketValue", simple = "avg3", aucLabel = "3-Day Average" },
	{ key = "weekly", label = "7-Day Market Value", yaaha = "weeklyMarketValue", simple = "avg7", aucLabel = "7-Day Average" },
	{ key = "dbmarket", label = "14-Day Market Value", tsm = "dbmarket", yaaha = "biweeklyMarketValue", market = true, aucSource = "aucmarket", am = "GetMarketPrice", oe = "market" },
	{ key = "monthly", fallbackLabel = "30-Day Market Value", yaaha = "monthlyMarketValue" },
	{ key = "dbhistorical", label = "60-Day Market Value", tsm = "dbhistorical", yaaha = "bimonthlyMarketValue" },
	{ key = "dbregionmarketavg", label = "Region Market Value", tsm = "dbregionmarketavg", oe = "region", regional = true },
	{ key = "dbregionhistorical", label = "Region Historical Value", tsm = "dbregionhistorical", regional = true },
	{ key = "oerealm", label = "4-Day Realm Median", oe = "market", retail = true },
	{ key = "crafting", label = "Crafting Cost", tsm = "crafting", yaaha = "crafting" },
	{ key = "destroy", label = "Disenchant/Mill/Prospect Value", tsm = "destroy", yaaha = "breakdown" },
	{ key = "vendorsell", globalLabel = SELL_PRICE }
}

local function call(func, ...)
	if type(func) ~= "function" then return nil end
	local ok, value = pcall(func, ...)
	if ok then return value end
	return nil
end

local function positive(value)
	return type(value) == "number" and value > 0 and value < math.huge
end

local function useTSM()
	if WOW_PROJECT_ID ~= WOW_PROJECT_CLASSIC then return true end
	local season = C_Seasons and call(C_Seasons.GetActiveSeason)
	-- Hardcore and Fresh are represented as seasons by Blizzard too.
	return type(season) == "number" and season > 0
end

local function categoryLabel(category)
	return category.globalLabel or L[category.label or category.fallbackLabel]
end

local function sourceDescription(func, key)
	local description = call(func, key)
	return type(description) == "string" and description ~= "" and description or nil
end

local function yaahaDescription(category)
	return category.yaaha and YAAHA_API and sourceDescription(YAAHA_API.GetPriceSourceDescription, category.yaaha) or nil
end

-- External-source translations are useful even on nonseasonal Era, where
-- native TSM prices are excluded. Query values directly from their providers.
local externalLabels = {
	aucminbuyout = "Auctioneer - Minimum Buyout",
	aucmarket = "Auctioneer - Market Value",
	atrvalue = "Auctionator - Auction Value",
	oerealm = "Oribos Exchange Realm Price",
	oeregion = "Oribos Exchange Region Price"
}

local function externalDescription(key)
	if not key then return nil end
	local description = TSM_API and sourceDescription(TSM_API.GetPriceSourceDescription, key)
	return description or (externalLabels[key] and L[externalLabels[key]])
end

local function externalCategoryDescription(category)
	if AucAdvanced and (category.market or category.simple) then
		return externalDescription(category.aucSource)
	end
	if AuctionMaster and AuctionMaster.API and category.am then
		return nil
	end
	if category.atr and Auctionator then
		local description = externalDescription("atrvalue")
		if description then return description end
	end
	if isStandard and category.oe and OEMarketInfo then
		return externalDescription(category.oe == "market" and "oerealm" or "oeregion")
	end
	return nil
end

local function categoryAvailable(category, tsmAllowed)
	return (not category.retail or isStandard) and (not category.regional or tsmAllowed)
end

-- Keep options in the same order as prices without duplicating the category list.
function PriceAnswer:GetPriceCategoryOrder()
	local keys = {}
	for i, category in ipairs(categories) do keys[i] = category.key end
	return keys
end

function PriceAnswer:GetPriceCategoryLabels()
	local labels = {}
	local tsmAllowed = useTSM()
	for _, category in ipairs(categories) do
		if categoryAvailable(category, tsmAllowed) then
			local description
			if tsmAllowed and TSM_API and category.tsm then
				description = sourceDescription(TSM_API.GetPriceSourceDescription, category.tsm)
			end
			labels[category.key] = description or yaahaDescription(category) or externalCategoryDescription(category)
				or ((category.label or category.globalLabel) and categoryLabel(category))
		end
	end
	return labels
end

function PriceAnswer:GetPrices(itemID, itemLink, itemString)
	local prices = {}
	local tsm = TSM_API
	local yaaha = YAAHA_API
	local auctioneer = AucAdvanced
	local am = AuctionMaster and AuctionMaster.API
	local atr = Auctionator and Auctionator.API and Auctionator.API.v1
	local simple = auctioneer and call(auctioneer.GetModule, "Stat", "Simple")
	local simplePrices = simple and call(simple.GetPriceArray, itemLink or itemID)
	local oe = isStandard and call(OEMarketInfo, itemLink or itemID, {})
	local tsmAllowed = useTSM()
	if tsmAllowed and tsm then
		local converted = call(tsm.ToItemString, itemLink or itemID)
		if type(converted) == "string" then itemString = converted end
	end
	local used = {}

	for _, category in ipairs(categories) do
		if self.db.profile.addonPriceSources[category.key] and categoryAvailable(category, tsmAllowed) then
			local value, provider, label, metric, providerInLabel
			if tsmAllowed and tsm and category.tsm then
				value = call(tsm.GetCustomPriceValue, category.tsm, itemString)
				if positive(value) then
					provider = "TSM"
					label = sourceDescription(tsm.GetPriceSourceDescription, category.tsm)
				end
			end
			if not positive(value) and yaaha and category.yaaha then
				value = call(yaaha.GetPriceSourceValue, category.yaaha, itemID)
				if positive(value) then
					provider = "YAAHA"
					label = yaahaDescription(category)
					providerInLabel = label ~= nil
				end
			end
			if not positive(value) and auctioneer then
				if category.market then
					value = call(auctioneer.API and auctioneer.API.GetMarketValue, itemLink or itemID)
				elseif category.simple and type(simplePrices) == "table" then
					value = simplePrices[category.simple]
				end
				if positive(value) then
					provider = "Auctioneer"
					label = externalDescription(category.aucSource)
					providerInLabel = label ~= nil
					label = label or L[category.market and "Market Value" or category.aucLabel or category.label]
				end
			end
			if not positive(value) and am and category.am then
				value = call(am[category.am], itemLink or itemID)
				if positive(value) then
					provider = "AuctionMaster"
					label = L[category.market and "Market Value" or category.label]
				end
			end
			if not positive(value) and atr and category.atr then
				if itemLink then
					value = call(atr.GetAuctionPriceByItemLink, "PriceAnswer", itemLink)
				else
					value = call(atr.GetAuctionPriceByItemID, "PriceAnswer", itemID)
				end
				if positive(value) then
					provider = "Auctionator"
					label = externalDescription("atrvalue")
					providerInLabel = label ~= nil
				end
			end
			if not positive(value) and category.oe and type(oe) == "table" then
				value = oe[category.oe]
				if positive(value) then
					provider = "Oribos Exchange"
					label = externalDescription(category.oe == "market" and "oerealm" or "oeregion")
					providerInLabel = label ~= nil
					metric = category.oe
				end
			end
			if not positive(value) and category.key == "vendorsell" then
				value = select(11, C_Item.GetItemInfo(itemLink or itemID))
				if positive(value) then provider = MERCHANT end
			end
			if positive(value) and provider then
				-- OE's realm price can fill two categories; emit that observation once.
				local identity = provider .. ":" .. (metric or category.key)
				if not used[identity] then
					used[identity] = true
					prices[#prices + 1] = { value = value, label = label or categoryLabel(category), provider = provider, providerInLabel = providerInLabel }
				end
			end
		end
	end
	return prices
end
