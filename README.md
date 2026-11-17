# Hotbar Highlight

[WoW: Forever] A visual aid addon that highlights the hotbar based on the currently pressed modifier or selector key.

Many players put the same keys on several action bars and switch between them with Shift, Ctrl or Alt. A 12-button mouse is the usual case. After a while it gets hard to tell which bar the next press will hit. Hotbar Highlight shows you. Hold a modifier and the bar that belongs to it glows while the others fade. It can also make the key labels on the buttons shorter, so `s-1` reads `S1`.

It is made for the game's default interface. With a custom UI or an action bar addon it may do nothing, or look wrong, and I can't promise it will work there.

Made for World of Warcraft Forever (interface 16001). Type `/hh` in game to open the settings.

This is version 1.0.0. So far it has been played on one setup, five bars on a 12-button mouse grid with the default interface. If something looks off on yours, please tell me.

## What it does

- **It works out which bar is which by itself.** It looks at the keys bound to a bar's buttons. If most of them use Shift, that bar is your Shift bar. There is nothing to set up, and when you rebind keys it follows.
- **It highlights the bar you are on.** Hold Shift, Ctrl, Alt or a mix of them. The matching bar gets a soft glow in a color you pick, or a thin line if you prefer. The other bars fade as much as you like. Let go and everything is back the way it was.
- **It stays out of the way.** Bars with no key bindings are never touched. Modifiers that no bar uses do nothing, so holding Alt to cast on yourself or Shift while typing in chat will not make your bars flicker. Edit Mode shows your bars as they really are.
- **It shortens key labels.** One letter per modifier and then the key, like `S1`, `C1`, `AS1`. You can also show the key alone, since the glowing bar already tells you the modifier. Or leave the game's labels as they are.
- **It lets you style key labels.** Put them in any corner, on a side or in the middle of the button. Nudge them, make them bigger or smaller, fade them.

It covers Action Bars 1 to 8, the pet bar and the stance bar of the default interface.

## What it does not do

It changes how your bars look and nothing else. It does not bind keys, change what a button does, move or resize bars or buttons, cast anything, or send anything to other players. The tests check this on every run.

It only knows the game's own action bars. Bar addons such as Bartender, Dominos or ElvUI use their own frames, so Hotbar Highlight will not find them.

## Settings

Open them from Options, AddOns, Hotbar Highlight, or type `/hh`.

| Setting | Default | What it means |
|---|---|---|
| Enabled | on | Turn it off and bars and key labels go back to the game's own. |
| Other bars' opacity | 40% | How visible the other bars stay while one is highlighted. At 100% they do not fade. |
| Highlight around the bar | on | Turn it off and the bar just stays bright while the others fade. |
| Highlight goes around | the whole bar | You can also have it go around only the buttons you can see. Handy for a bar set to fewer icons or with empty slots hidden. |
| Highlight style | soft glow | A light around the bar that fades outward, or a plain thin line. |
| Highlight color | gold | Any color from the game's color picker. |
| Highlight opacity | 90% | How strong the glow or line is. |
| Glow size | 18 px | How far the glow reaches. |
| Line thickness | 2 px | How thick the thin line is. |
| Inner glow | 14% | How far the glow reaches in under the bar's edge, as a share of a button's size. It fills the little gaps left by the buttons' round corners. Set it to 0 to turn it off. |
| With no modifier held | every bar normal | You can also keep the bar without a modifier highlighted until you hold one. |
| Only in combat | off | Highlight and fade only during a fight. |
| Key labels | short | Short like `S1`, the key alone like `1`, or the game's own like `s-1`. |
| Key label place | the game's own | A corner, a side or the middle of the button. |
| Key label left/right and down/up | 0 | Moves the label by that many pixels from its place. |
| Key label size and opacity | 100% | Compared with what the label has without this addon. |
| One choice per bar | auto | Auto reads the modifier from the bar's keys. You can also set it by hand or tell the addon to leave that bar alone. |

## Commands

| Command | What it does |
|---|---|
| `/hh` | Opens the settings. Works out of combat. |
| `/hh status` | Lists every bar with what was found, which modifier it belongs to and how many buttons have a key. |
| `/hh on` and `/hh off` | Turns the addon on or off. |

## Install

Download the newest `HotbarHighlight` zip from the [Releases page](https://github.com/Golorom/HotbarHighlight/releases) and unpack it into `World of Warcraft\_forever_\Interface\AddOns\`. The folder has to be named `HotbarHighlight`. Restart the game afterwards.

Addon managers that can install from a GitHub address, such as WowUp with its Install from URL, may accept this repository's address. I have not tried that with the Forever client.

You don't need any other addon. I do recommend [BugSack](https://www.curseforge.com/wow/addons/bugsack) together with [!BugGrabber](https://www.curseforge.com/wow/addons/bug-grabber). If something goes wrong they show the error text, which helps a lot in a report.

## Reporting a problem

Please open an issue and include what `/hh status` prints, the BugSack text if there is any, and which bars and key bindings you use.

## Support

Hotbar Highlight is free and will stay free. If it makes your game nicer and you want to say thanks, you can do that at [boosty.to/goromajur](https://boosty.to/goromajur) with the Donate button. If your card was issued outside Russia, choose USD or EUR at checkout.

## Documentation

- [How it works](docs/HOW-IT-WORKS.md) explains the design file by file and what it relies on in the game.
- [Development](docs/DEVELOPMENT.md) covers the rules, the tests and how releases are made.
- [Changelog](CHANGELOG.md)

## License

MIT. See [LICENSE](LICENSE).
