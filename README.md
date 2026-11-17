# Hotbar Highlight

[WoW: Forever] A visual aid addon that highlights the hotbar based on the currently pressed modifier or selector key.

If your action bars are layers of the same keys (a 12-button mouse grid with Shift, Ctrl and Alt switching between bars, for example), this shows which layer you are on: while you hold a modifier, the bar bound to it gets a soft glow around it and the other bound bars fade. It can also shorten the key labels on the buttons, so `s-1` reads `S1`.

Interface 16001 (World of Warcraft: Forever). Slash command: `/hh`.

Status: 0.3.0. Early, and played on one setup only (five bars on a 12-button mouse grid, default interface). Please report what you see on yours.

## What it does

- **Finds each bar's layer by itself.** A bar's layer is the set of modifiers most of its buttons' key bindings share. Buttons bound to Shift-1 through Shift-= make that bar the Shift layer. Nothing to set up; rebinding keys updates it at once.
- **Highlights the bar you are on.** Hold Shift, Ctrl, Alt or a mix: the bar of that layer gets a soft glow in a color you pick (or a thin line), the other bound bars fade to an opacity you choose. Let go and everything is as it was, including any opacity a bar had before.
- **Stays out of the way.** Bars with no key bindings are never touched. Modifiers that no bar uses change nothing, so Alt as a self-cast key or Shift while typing in chat does not make the bars flicker. Edit Mode shows the bars as they are.
- **Shortens key labels.** One letter per modifier, then the key: `S1`, `C1`, `AS1`, `AC1`. Or the key alone (`1`), since the highlighted bar already tells you the modifier. Or leave the game's labels untouched.
- **Lets you style key labels.** Put them in any corner, on a side or in the center of the button, nudge them, make them bigger or smaller, and fade them.

It covers Action Bars 1 to 8, the pet bar and the stance bar of the default interface.

## What it does not do

It changes how bars look and nothing else. It does not bind keys, change what a button does, move or resize bars or buttons, cast anything, or send anything to other players. The tests check this on every run.

It works with the game's own action bars. Bar replacement addons (Bartender, Dominos, ElvUI and the like) use their own frames and are not covered.

## Settings

Options, AddOns, Hotbar Highlight, or `/hh`.

| Setting | Default | Meaning |
|---|---|---|
| Enabled | on | Off restores bars and key labels to the game's own. |
| Other bars' opacity | 40% | How visible the other bound bars stay while one is highlighted. 100% does not fade them. |
| Highlight around the bar | on | Off: the bar only stays bright while the others fade. |
| Highlight goes around | the whole bar | Or only the buttons shown, for a bar set to fewer icons or with empty slots hidden. |
| Highlight style | soft glow | Soft glow: a light around the bar that fades outward. Thin line: a plain frame. |
| Highlight color | gold | Any color, from the game's color picker. |
| Highlight opacity | 90% | How strong the glow or line is. |
| Glow size, line thickness | 18 px, 2 px | How far the glow reaches; how thick the line is. |
| Inner glow | 14% | How far the glow reaches in under the bar's edge, as a share of a button's size. It fills the gaps the buttons' round corners leave. 0 turns it off. |
| With no modifier held | every bar normal | Or: keep the unmodified bar highlighted and the others faded until you hold a modifier. |
| Only in combat | off | Highlight and fade only during a fight. |
| Key labels | short | Short (`S1`), key only (`1`), or the game's own (`s-1`). |
| Key label place, left/right, down/up | the game's own, 0, 0 | A corner, a side or the center of the button. The offsets, in pixels, move the label from that place, or from where the game puts it. |
| Key label size, opacity | 100%, 100% | In percent of what the label has without this addon. |
| One choice per bar | auto | Auto reads the layer from the bar's keys. Or fix a layer, or leave the bar alone. |

## Commands

| Command | Does |
|---|---|
| `/hh` | opens the settings (out of combat) |
| `/hh status` | lists each bar: whether it was found, its layer and where that came from, how many buttons have a key |
| `/hh on`, `/hh off` | turns the addon on or off |

## Install

Copy the folder into `World of Warcraft\_forever_\Interface\AddOns\` and name it `HotbarHighlight`. Restart the game after adding the files.

From a release: download `HotbarHighlight-<version>.zip` from the Releases page and unpack it into `AddOns`. Addon managers that install from a GitHub address (such as WowUp's "Install from URL") may accept this repository's address once a release exists; that has not been tried with the Forever client.

No other addon is required. [BugSack](https://www.curseforge.com/wow/addons/bugsack) with [!BugGrabber](https://www.curseforge.com/wow/addons/bug-grabber) is recommended: if something goes wrong it shows the error text to include in a report.

## Reporting a problem

Open an issue with the output of `/hh status`, the BugSack text if there is any, and which bars and key bindings you use.

## Documentation

- [docs/HOW-IT-WORKS.md](docs/HOW-IT-WORKS.md): the design, file by file, and what it relies on in the game.
- [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md): rules, tests, releases.
- [CHANGELOG.md](CHANGELOG.md).

## License

MIT, see [LICENSE](LICENSE).
