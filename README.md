# Description

Reply to price checks automatically using TSM or an external addon's item values.

## Requirements

Price Answer requires **you** to have [TradeSkillMaster](https://www.tradeskillmaster.com/install) installed, but users sending you price inquiries do not need TSM.

## Supported WoW versions and price sources

* Fresh and Fresh Harcore Classic (full prices from the TSM desktop app)
* Mists of Pandaria Classic (full prices from the TSM desktop app)
* Retail (full prices from the TSM desktop app)
* Classic Era, non-Fresh, Season of Discovery, and Anniversary (external addon, see below)

## Price sources priority

1. Any native to TradeSkillMaster
2. External addons

Price Answer will look for external addon prices even for WoW versions with full TSM support ***if you choose not use the TSM desktop app.*** TSM's price sources are *signicantly* better than using an external addon. Any price sources which are not available are not sent in Price Answer's reply to the price request.

## Supported external addons

Auctionator, Auctioneer, and Auction House DataBase (AHDB) prices are supported, and are mapped to the equivalent TSM price sources. Not all price sources are available for all World of Warcraft versions, regardless of additional addons.

### Auctionator and AHDB

* Provides a minimum buyout, IE: the least expensive ***single*** auction of an item. Mapped to TSM's minimum buyout of `dbminbuyout`.

### Auctioneer

* Provides a minimum buyout, IE: the least expensive ***single*** auction of an item. Mapped to TSM's minimum buyout of `dbminbuyout`.
* Provides a trending market value of an item over time. Mapped to TSM's market value of `dbmarket`.
* Provides a recent price average of an item based on the last scan of the auction house. Mapped to TSM's recent value of `dbrecent`.

## Open the settings

* `/priceanswer`
* `/prans`
* `Esc > Options > AddOns > Price Answer`

## Asking for a price check

People send the following commands to trigger price checks. Thanks to Bearthazar on Curseforge for the better pattern matching in version 1.09, where spaces do not matter. (**EXCEPTION:** when passing both N and a numerical **itemID**, ***a space MUST exist*** between N and the itemID!!) The trigger `price` can be changed in the options.

* `price N item`
* `priceNitem`
* `price Nitem`
* `price item`

`N` is an optional quantity (default 1), `item` is a numerical itemID, itemLink, or item name. If an item name is sent, ***YOU*** must have the item in your inventory.

## Chat channels listened

* General
* Trade
* Local Defence
* Say
* Yell
* Guild
* Officer
* Raid
* Raid Warning
* Whisper
* BN Whisper
* Instance (Mists Classic & Retail)
* Community (Retail)

## TradeSkillMaster prices:

* Min buyout
* Market value (14-day realm trend)
* Recent (market value of an item from the last data snapshot)
* Region market average (Mists and Retail)
* Historical (60-day extended market trend) (Mists and Retail)
* Region historical (60-day extended market trend) (Mists and Retail)
* Crafting cost (at least one same-realm, same-faction character needs to know the recipe)
* Destroy (DE, milling, prospecting) value

## Questions & answers

There is a Help tab in Price Answer's settings with more information.

## Bugs and suggestions

[GO HERE](https://github.com/Myrroddin/price-answer/issues)

## Translate

[GO HERE](https://legacy.curseforge.com/wow/addons/price-answer/localization)