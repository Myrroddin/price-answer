# Price Answer

Automatically reply to item price checks using available pricing addons. TradeSkillMaster is optional. Players requesting prices do not need any addon.

## Supported clients

Classic Era, active Classic seasons, Burning Crusade Classic, WoW Forever, Mists Classic, and Retail/Mainline.

Providers must support the client you are playing. Price Answer checks for their APIs and skips unavailable functions or data. Oribos Exchange is used only on Retail/Mainline.

## Price priority

Each selected price category independently tries these providers in order:

1. TradeSkillMaster, except on Classic Era without an active season.
2. YAAHA.
3. Auctioneer.
4. AuctionMaster.
5. Auctionator.
6. Oribos Exchange (Retail/Mainline only).

Missing, zero, invalid, or failed price queries fall through to the next provider for that category. One reply can therefore contain prices from several providers. Classic Era without an active season skips TSM entirely. Blizzard also identifies Hardcore and Fresh realms as seasons; they receive TSM priority when the client reports an active season.

Vendor sell prices use TSM where allowed, with the game's cached item information as the final fallback. Without any pricing addon, cached vendor sell prices can still be returned. Categories without data are omitted; if no selected category has data, Price Answer sends no reply.

## Price categories

Use the **Price categories** tab to select which values to include. Existing selections are retained.

| Provider | Available price categories |
| --- | --- |
| TradeSkillMaster | Minimum buyout, recent, market, historical, region market, region historical, crafting, destroy, vendor sell |
| YAAHA | Minimum bid and buyout; current, 3-, 7-, 14-, 30-, and 60-day market values; crafting cost; disenchant value; observed average sale value |
| Auctioneer | Minimum buyout, daily average, 3- and 7-day averages through its Simple statistics module; aggregate market value through its public API |
| AuctionMaster | Lowest buyout and market price |
| Auctionator | Minimum buyout |
| Oribos Exchange | Four-day realm median and regional median |

Provider statistics are not interchangeable. Replies name the provider and use its actual metric: for example, AuctionMaster's market price is labeled **Market Value**, rather than claiming it is a 14-day average. TSM's localized source descriptions are used when available; other labels use Price Answer's translations. YAAHA's disenchant estimate is labeled **Disenchant Value**, without implying it includes milling or prospecting.

The Oribos Exchange realm category can also supply the market-value fallback. If both selections resolve to that same observation, it appears only once. Auctionator does not fill market or historical categories with its minimum buyout.

Amounts are multiplied by the requested quantity. Item links are preserved for providers that support equipment variants; YAAHA's public price functions accept item IDs. Availability depends on each provider's scans, downloaded data, known recipes, and supported client APIs.

Regular chat replies always use the bundled ChatThrottleLib and are divided into messages of at most 255 bytes. Battle.net whispers use the client's separate Battle.net API.

## Open the settings

- `/priceanswer`
- `/prans`
- Esc → Options → AddOns → Price Answer

## Asking for a price check

Players can use the following commands to trigger price checks. Spaces do not matter. (**Exception:** when passing both N and a numerical **itemID**, a space **must** exist between N and the itemID.) The trigger `price` can be changed in the options.

- `price N item`
- `priceNitem`
- `price Nitem`
- `price item`

`N` is an optional quantity (default 1), `item` is an itemID, itemLink, or item name. If an item name is used, the item must be cached by the game client (either from the current session or existing cache data). If it is not cached, use an item link or itemID instead.

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
