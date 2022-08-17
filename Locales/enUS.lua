local silent = true
--@debug@
silent = false
--@end-debug@
local L = LibStub("AceLocale-3.0"):NewLocale("PriceAnswer", "enUS", true, silent)
--@debug@
L["How do you want to answer this channel"] = true
L["Any symbol, word, or phrase that triggers sending price answers"] = true
L["Enables / disables the AddOn"] = true
L["Sources' gold values sent in the reply, if valid"] = true
L["The trigger"] = true
L["The trigger must be one or more non-space characters, a word, or a phrase (can contain spaces between words in the phrase)"] = true
L["TSM price sources"] = true
L["Watched chat channels"] = true
L["You must enable at least one watched chat channel"] = true
L["Disable in combat"] = true
L["Stops watching chat channels while you are in combat"] = true
L["Incoming messages"] = true
L["Outgoing messages"] = true
L["price"] = true
L["Market"] = true
L["Min"] = true
L["Region"] = true
L["Historical"] = true
L["Region Historical"] = true
L["Craft"] = true
L["Destroy"] = true
L["Price Answer"] = true
L["Syntax: '%s N item' without quotes, N is an optional quantity, default 1, item is an item link or itemID"] = true
L["g"] = true
L["s"] = true
L["c"] = true
L["Format large gold numbers"] = true
L["Turns 9999g into 9,999g"] = true
L["Q: Why isn't this addon built into TradeSkillMaster?"] = true
L["A: That cannot be done without breaking TradeSkillMaster"] = true
L["Q: The item can be crafted, but I'm not sending crafting costs?"] = true
L["A: At least one of your same-faction, same-realm characters must know the recipe"] = true
L["Q: Where is the option to send messages to community chat?"] = true
L["A: AddOns are not permitted to send messages to community channels; whispering is the sender is the only option"] = true
L["Q: Does the person sending the price chack need TradeSkillMaster for Price Answer to work?"] = true
L["A: No, which is the point. You need TradeSkillMaster for Price Answer to work"] = true
L["Q: Is there no option to use coins instead of g, s, c?"] = true
L["A: Sending chat messages does not allow for colour codes; {rt2} is how all coins would appear"] = true
L["Q: But I can see colours in my chat window?"] = true
L["A: True, because adding a message to your chat window allows colours, whereas sending a chat message to someone else does not"] = true
L["Q: What happens if I toggle off all TradeSkillMaster prices?"] = true
L["A: The AddOn will process the incoming message, and erroneously tell the sender their syntax is wrong. You should leave one or more TSM prices enabled"] = true
--@end-debug@

--@localization(locale="enUS", format="lua_additive_table", same-key-is-true=true)@