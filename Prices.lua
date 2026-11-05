local _, addon = ...

local PriceAnswer = addon.PriceAnswer
local L = LibStub("AceLocale-3.0"):GetLocale("PriceAnswer")
local isStandard = WOW_PROJECT_ID == WOW_PROJECT_MAINLINE

-- Keep the original keys so existing source selections survive the provider change.
local categories = {
	{ key = "minbid", label = "Lowest Bid", yaaha = "GetMinBid" },
	{ key = "dbminbuyout", label = "Cheapest Auction", tsm = "dbminbuyout", yaaha = "GetMinBuyout", simple = "mbo", am = "GetLowestPrice", atr = true },
	{ key = "dbrecent", label = "Current Market Value", tsm = "dbrecent", yaaha = "GetCurrentMarketValue", simple = "avgday", aucLabel = "Daily Average" },
	{ key = "midweek", label = "3-Day Market Value", yaaha = "GetMidweekMarketValue", simple = "avg3", aucLabel = "3-Day Average" },
	{ key = "weekly", label = "7-Day Market Value", yaaha = "GetWeeklyMarketValue", simple = "avg7", aucLabel = "7-Day Average" },
	{ key = "dbmarket", label = "14-Day Market Value", tsm = "dbmarket", yaaha = "GetBiweeklyMarketValue", market = true, am = "GetMarketPrice", oe = "market" },
	{ key = "monthly", label = "30-Day Market Value", yaaha = "GetMonthlyMarketValue" },
	{ key = "dbhistorical", label = "60-Day Market Value", tsm = "dbhistorical", yaaha = "GetBimonthlyMarketValue" },
	{ key = "dbregionmarketavg", label = "Region Market Value", tsm = "dbregionmarketavg", oe = "region" },
	{ key = "dbregionhistorical", label = "Region Historical Value", tsm = "dbregionhistorical" },
	{ key = "oerealm", label = "4-Day Realm Median", oe = "market", retail = true },
	{ key = "crafting", label = "Crafting Cost", tsm = "crafting", yaaha = "GetCraftingValue" },
	{ key = "destroy", label = "Disenchant/Mill/Prospect Value", tsm = "destroy", yaaha = "GetDisenchantValue", yaahaLabel = "Disenchant Value" },
	{ key = "saleaverage", label = "Observed Average Sale Value", yaaha = "GetRealmRollingAverageSaleValue" },
	{ key = "vendorsell", label = "Sell to vendor", tsm = "vendorsell" }
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

function PriceAnswer:GetPriceCategoryLabels()
	local labels = {}
	for _, category in ipairs(categories) do
		if not category.retail or isStandard then
			labels[category.key] = L[category.label]
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
		if self.db.profile.tsmSources[category.key] and (not category.retail or isStandard) then
			local value, provider, label, metric
			if tsmAllowed and tsm and category.tsm then
				value = call(tsm.GetCustomPriceValue, category.tsm, itemString)
				if positive(value) then
					provider = "TSM"
					label = call(tsm.GetPriceSourceDescription, category.tsm)
				end
			end
			if not positive(value) and yaaha and category.yaaha then
				value = call(yaaha[category.yaaha], itemID)
				if positive(value) then
					provider = "YAAHA"
					label = L[category.yaahaLabel or category.label]
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
					label = L[category.market and "Market Value" or category.aucLabel or category.label]
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
				if positive(value) then provider = "Auctionator" end
			end
			if not positive(value) and category.oe and type(oe) == "table" then
				value = oe[category.oe]
				if positive(value) then
					provider = "Oribos Exchange"
					label = L[category.oe == "market" and "4-Day Realm Median" or "Region Median"]
					metric = category.oe
				end
			end
			if not positive(value) and category.key == "vendorsell" then
				value = select(11, C_Item.GetItemInfo(itemLink or itemID))
				if positive(value) then provider = L["Vendor"] end
			end
			if positive(value) and provider then
				-- OE's realm price can fill two categories; emit that observation once.
				local identity = provider .. ":" .. (metric or category.key)
				if not used[identity] then
					used[identity] = true
					prices[#prices + 1] = { value = value, label = type(label) == "string" and label or L[category.label], provider = provider }
				end
			end
		end
	end
	return prices
end