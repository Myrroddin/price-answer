# Description

Reply to price checks automatically using TSM or an external addon's item values.

## Table of Contents
- [Description](#description)
- [Requirements](#requirements)
- [Supported WoW versions and price sources](#supported-wow-versions-and-price-sources)
- [Price sources priority](#price-sources-priority)
- [Supported external addons](#supported-external-addons)
	- [Auctionator and AHDB](#auctionator-and-ahdb)
	- [Auctioneer](#auctioneer)
	- [Oribos Exchange](#oribos-exchange)
- [Open the settings](#open-the-settings)
- [Asking for a price check](#asking-for-a-price-check)
- [Chat channels listened](#chat-channels-listened)
- [TradeSkillMaster prices](#tradeskillmaster-prices)
- [Questions & answers](#questions--answers)
- [Bugs and suggestions](#bugs-and-suggestions)
- [Translate](#translate)

## Requirements

Price Answer requires **you** to have [TradeSkillMaster](https://www.tradeskillmaster.com/install) installed, but users sending you price inquiries do not need TSM.

## Supported WoW versions and price sources


| WoW Version                | TSM Price Sources Available | External Addon Price Sources Supported |
|----------------------------|-----------------------------|----------------------------------------|
| Retail (Mainline)          | All TSM sources, Oribos Exchange (oerealm) | Auctionator, AHDB (dbminbuyout), Oribos Exchange |
| Mists of Pandaria Classic  | All TSM sources             | Auctionator, AHDB (dbminbuyout)        |
| Season of Discovery        | All TSM sources             | Auctionator, AHDB (dbminbuyout)        |
| Fresh/Fresh Hardcore       | All TSM sources             | Auctionator, AHDB (dbminbuyout)        |
| Classic Era (non-Fresh)    | Limited TSM sources         | Auctionator (atrvalue), Auctioneer (aucminbuyout, aucmarket, aucappraiser), AHDB (ahdbminbuyout) |

**Notes:**
- Oribos Exchange (oerealm) is supported in Retail/Mainline only.
- External price sources are used if TSM data is unavailable or you choose not to use the TSM desktop app.

## Price sources priority


1. Native TradeSkillMaster price sources (dbminbuyout, dbmarket, dbrecent, dbregionmarketavg, dbhistorical, dbregionhistorical, crafting, destroy, oerealm)
2. External addon price sources (Auctionator, Auctioneer, AHDB, Oribos Exchange)

Price Answer will use external addon prices if TSM data is unavailable or you choose not to use the TSM desktop app. TSM's price sources are significantly better than external addons. Only available price sources for your WoW version/addons are sent in replies.

## Supported external addons


Auctionator, Auctioneer, Auction House DataBase (AHDB), and Oribos Exchange prices are supported. These are mapped to the equivalent TSM price sources where possible. Not all price sources are available for all World of Warcraft versions, regardless of additional addons.

### Auctionator and AHDB

- Provides a minimum buyout, i.e., the least expensive single auction of an item. Mapped to TSM's minimum buyout (`dbminbuyout`).

### Auctioneer

- Provides a minimum buyout, i.e., the least expensive single auction of an item. Mapped to TSM's minimum buyout (`dbminbuyout`).
- Provides a trending market value of an item over time. Mapped to TSM's market value (`dbmarket`).
- Provides a recent price average of an item based on the last scan of the auction house. Mapped to TSM's recent value (`dbrecent`).

### Oribos Exchange
- Provides 3-day realm average price (`oerealm`). Supported in Retail/Mainline only.

## Open the settings

- `/priceanswer`
- `/prans`
- `Esc > Options > AddOns > Price Answer`

## Asking for a price check

People send the following commands to trigger price checks. Thanks to Bearthazar on Curseforge for the better pattern matching in version 1.09, where spaces do not matter. (**EXCEPTION:** when passing both N and a numerical **itemID**, ***a space MUST exist*** between N and the itemID!!) The trigger `price` can be changed in the options.

- `price N item`
- `priceNitem`
- `price Nitem`
- `price item`

`N` is an optional quantity (default 1), `item` is a numerical itemID, itemLink, or item name. If an item name is sent, ***YOU*** must have the item in your inventory.

## Chat channels listened

- General, Trade, Local Defence
- Say, Yell, Guild, Officer
- Raid, Raid Warning
- Whisper, BN Whisper
- Instance (Mists Classic & Retail)
- Community (Retail)

## TradeSkillMaster prices

- Min buyout
- Market value (14-day realm trend)
- Recent (market value of an item from the last data snapshot)
- Region market average (Mists and Retail)
- Historical (60-day extended market trend) (Fresh, Fresh Hardcore, Mists, and Retail)
- Region historical (60-day extended market trend) (Fresh, Fresh Hardcore, Mists, and Retail)
- Crafting cost (at least one same-realm, same-faction character must know the recipe)
- Destroy (DE, milling, prospecting) value

## Questions & answers

There is a Help tab in Price Answer's settings with more information.

## Bugs and suggestions

[GO HERE](https://github.com/Myrroddin/price-answer/issues)

## Translate

[GO HERE](https://legacy.curseforge.com/wow/addons/price-answer/localization)