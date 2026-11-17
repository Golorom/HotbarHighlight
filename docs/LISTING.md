# Listing text

For creating the project pages on CurseForge and Wago. Paste and adjust.

**Name:** Hotbar Highlight

**Summary (one line):** Shows which action bar your held modifier keys belong to: that bar glows, the others fade. Short, movable key labels.

**Category:** Action Bars

**Game version:** World of Warcraft: Forever (interface 16001)

**License:** MIT

**Source:** https://github.com/Golorom/HotbarHighlight

**Issues:** https://github.com/Golorom/HotbarHighlight/issues

## Description

If your action bars are layers of the same keys, for example a 12-button mouse grid with Shift, Ctrl and Alt switching between bars, Hotbar Highlight shows which layer you are on.

**While you hold a modifier**
- the bar bound to it gets a soft glow in a color you pick, or a thin line;
- the other bound bars fade to an opacity you choose;
- let go, and everything is as it was.

**Nothing to set up.** Each bar's layer is read from the keys bound to its buttons. Rebinding updates it at once. A bar can also be given a layer by hand or left alone.

**Stays out of the way.** Bars with no key bindings are never touched. Modifiers that no bar uses change nothing, so Alt as a self-cast key or Shift while typing does not make the bars flicker. Edit Mode shows the bars as they are.

**Key labels.** `s-1` becomes `S1`, `a-c-1` becomes `AC1`, or just `1`. Put the label in any corner, on a side or in the center of the button, nudge it, resize it, fade it.

**Only looks.** It does not bind keys, change what a button does, move bars or buttons, cast anything, or send anything to other players.

Works with the game's own action bars (1 to 8, pet and stance). Bar replacement addons use their own frames and are not covered.

Settings: Options, AddOns, Hotbar Highlight, or `/hh`. `/hh status` lists what was found on your bars.

Free and open source. If you want to say thanks: https://boosty.to/goromajur (with a card issued outside Russia, choose USD or EUR at checkout).

## After the page exists

1. Put the project's ID in `HotbarHighlight.toc`: `## X-Curse-Project-ID: <number>` and `## X-Wago-ID: <id from the Wago developer dashboard>`.
2. Add the keys to the repository: Settings, Secrets and variables, Actions, New repository secret, named `CF_API_KEY` and `WAGO_API_TOKEN`.
3. The next release uploads there too (job "publish" in the Release workflow).
