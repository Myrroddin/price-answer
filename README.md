# Description

Automatically reply to price checks using TradeSkillMaster or external addon data.

## Table of Contents

- [Description](#description)
- [Requirements](#requirements)
- [Supported WoW versions and price sources](#supported-wow-versions-and-price-sources)
- [TradeSkillMaster prices](#tradeskillmaster-prices)
- [Price sources priority](#price-sources-priority)
	- [Auctionator and Auction House DataBase (AHDB)](#auctionator-and-auction-house-database-ahdb)
	- [Auctioneer](#auctioneer)
	- [Oribos Exchange](#oribos-exchange)
- [Open the settings](#open-the-settings)
- [Asking for a price check](#asking-for-a-price-check)
- [Chat channels monitored](#chat-channels-monitored)
- [Questions & answers](#questions--answers)
- [Bugs and suggestions](#bugs-and-suggestions)
- [Translate](#translate)

## Requirements

Price Answer requires **you** to have [TradeSkillMaster](https://support.tradeskillmaster.com/tsm-desktop-application/how-do-i-set-up-the-tsm-desktop-application) installed.  
Users requesting price checks do **not** need TSM.

## Supported WoW versions and price sources

| WoW Version                | TSM Price Sources Available | External Addon Price Sources Supported |
|----------------------------|-----------------------------|----------------------------------------|
| Retail (Mainline)          | All TSM sources             | Auctionator, AHDB, Oribos Exchange     |
| Mists of Pandaria Classic  | All TSM sources             | Auctionator, AHDB                      |
| Titan Reforged (China)     | All TSM sources             | Auctionator, AHDB                      |
| Season of Discovery        | All TSM sources             | Auctionator, Auctioneer, AHDB          |
| Fresh/Fresh Hardcore       | All TSM sources             | Auctionator, Auctioneer, AHDB          |
| BCC Anniversary            | All TSM sources             | Auctionator, Auctioneer, AHDB          |
| Classic Era (vanilla)      | Limited TSM sources         | Auctionator, Auctioneer, AHDB          |

**Notes**

- Auctioneer for TBC Anniversary requires either [Auctioneer BCC Fix](https://www.curseforge.com/wow/addons/auctioneer-bcc-fix-unofficial) or [Auctioneer Crusade](https://www.curseforge.com/wow/addons/auctioneer-crusade).
- Auctioneer for Classic Era, Hardcore, Fresh, and Seasons requires the [original Auctioneer](https://www.curseforge.com/wow/addons/auctioneer).
- External price sources are used if TSM data is unavailable or if you are not using the TSM Desktop Application.
- External price sources are mapped to the equivalent TSM price sources where possible. Not all price sources are available for all World of Warcraft versions, regardless of additional addons.
- Vanilla Classic Era requires an external addon to provide price data to TSM. Only `crafting` and `destroy` from TSM are directly available, although with the usual validity restrictions as with all WoW versions.

## TradeSkillMaster prices

- Min buyout
- Market value (14-day realm trend)
- Recent (market value of an item from the last data snapshot)
- Region market average (market trend across the US or EU)
- Historical (60-day extended market trend)
- Region historical (60-day extended regional market trend)
- Crafting cost (at least one of your same-realm, same-faction characters must know the recipe)
- Destroy (DE, milling, prospecting) value

## Price sources priority

1. Native TradeSkillMaster price sources (dbminbuyout, dbmarket, dbrecent, dbregionmarketavg, dbhistorical, dbregionhistorical, crafting, destroy)
2. External addon price sources (Auctionator, Auctioneer, AHDB, Oribos Exchange)

### Auctionator and Auction House DataBase (AHDB)

- Provides a minimum buyout, i.e., the least expensive single auction of an item. Mapped to TSM's minimum buyout (`dbminbuyout`).

### Auctioneer

Auctioneer is supported in Classic-era variants which retain the pre-8.3 auction house system.

- Classic Era, Hardcore, Fresh, and Seasons: supported using the [original Auctioneer](https://www.curseforge.com/wow/addons/auctioneer).
- Burning Crusade Anniversary: requires either [Auctioneer BCC Fix](https://www.curseforge.com/wow/addons/auctioneer-bcc-fix-unofficial) or [Auctioneer Crusade](https://www.curseforge.com/wow/addons/auctioneer-crusade).
- Not supported in Mists Classic or Retail/Mainline.

Provides:

- A minimum buyout, i.e., the least expensive single auction of an item. Mapped to TSM's minimum buyout (`dbminbuyout`).
- A trending market value of an item over time. Mapped to TSM's market value (`dbmarket`).
- A recent price average of an item based on the last scan of the auction house. Mapped to TSM's recent value (`dbrecent`).

### Oribos Exchange

- Provides 3-day realm average price (`oerealm`). Supported in Retail/Mainline only.

## Open the settings

- `/priceanswer`
- `/prans`
- Esc → Options → AddOns → Price Answer

## Asking for a price check

Players can use the following commands to trigger price checks. Thanks to Bearthazar on Curseforge for the better pattern matching in version 1.09, where spaces do not matter. (**Exception:** when passing both N and a numerical **itemID**, a space **must** exist between N and the itemID.) The trigger `price` can be changed in the options.

- `price N item`
- `priceNitem`
- `price Nitem`
- `price item`

`N` is an optional quantity (default 1), `item` is a numerical itemID, itemLink, or item name. If an item name is used, the item must already be cached by the game client. If it is not cached, use an item link or itemID instead.

## Chat channels monitored

- General
- Trade
- Local Defence
- Say, Yell, Guild, Officer
- Raid, Raid Warning
- Whisper, BN Whisper
- Instance
- Community (Retail)

## Questions & answers

There is a Help tab in Price Answer's settings with more information.

## Bugs and suggestions

[GO HERE](https://github.com/Myrroddin/price-answer/issues)

## Translate

[GO HERE](https://legacy.curseforge.com/wow/addons/price-answer/localization)