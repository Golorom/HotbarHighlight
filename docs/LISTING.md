# Listing text

Text for the project pages on CurseForge and Wago. Paste it and adjust as you like.

| Field | Text |
|---|---|
| Name | Hotbar Highlight |
| Summary | Hold a modifier and the action bar that belongs to it glows while the others fade. Made for the default UI. |
| Category | Action Bars |
| Game version | World of Warcraft Forever, interface 16001 |
| License | MIT |
| Source | https://github.com/Golorom/HotbarHighlight |
| Issues | https://github.com/Golorom/HotbarHighlight/issues |

## Description

Many players put the same keys on several action bars and switch between them with Shift, Ctrl or Alt. A 12-button mouse is the usual case. After a while it gets hard to tell which bar the next press will hit.

Hotbar Highlight shows you. Hold a modifier and the bar that belongs to it glows while the others fade. Let go and everything is back the way it was.

**Made for the default interface.** It works with the game's own action bars, 1 to 8 plus the pet and stance bars. With a custom UI or an action bar addon such as Bartender, Dominos or ElvUI it may do nothing or look wrong, and I can't promise it will work there.

**Nothing to set up.** The addon looks at the keys bound to each bar and works out which modifier the bar belongs to. Rebind your keys and it follows. You can also set a bar by hand or tell the addon to leave it alone.

**It stays out of the way.** Bars with no key bindings are never touched. Modifiers that no bar uses do nothing, so holding Alt to cast on yourself or Shift while typing will not make your bars flicker.

**Your look.** Pick a soft glow or a thin line, any color, and how much the other bars fade. The highlight can go around the whole bar or only around the buttons you can see.

**Shorter key labels.** `s-1` becomes `S1` and `a-c-1` becomes `AC1`, or just `1` if you like. You can put the label in any corner or in the middle of the button, nudge it, resize it and fade it.

**Looks only.** It does not bind keys, change what a button does, move bars or buttons, cast anything, or send anything to other players.

Open the settings from Options, AddOns, Hotbar Highlight, or type `/hh`. If something does not show, `/hh status` lists what the addon found on your bars.

Free and open source. If you want to say thanks, you can do that at https://boosty.to/goromajur. If your card was issued outside Russia, choose USD or EUR at checkout.

## After the page exists

1. Put the project's ID into `HotbarHighlight.toc` as `## X-Curse-Project-ID` with the number, and `## X-Wago-ID` with the ID from the Wago developer dashboard.
2. Add the keys to the repository under Settings, Secrets and variables, Actions, as new repository secrets named `CF_API_KEY` and `WAGO_API_TOKEN`.
3. The next release then uploads to both sites as well. That is the job called publish in the Release workflow.
