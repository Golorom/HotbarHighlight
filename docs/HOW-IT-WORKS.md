# How it works

Four files, loaded in this order.

| File | Holds |
|---|---|
| `Core.lua` | Constants, saved settings and their repair, key parsing, the guarded start of each part. |
| `Bars.lua` | The list of bars, layer detection, the held layer, fade and border. |
| `Labels.lua` | Key label text. |
| `Options.lua` | The settings page and `/hh`. |

Everything hangs off one private table (the addon's namespace, called `HH` in the code). The only global is the saved variable `HotbarHighlightDB`, plus the slash command entries the game requires.

## Layers

A layer is the modifier part of a key binding in the game's own order: `NONE`, `SHIFT`, `CTRL`, `ALT`, `ALT-SHIFT`, `ALT-CTRL`, `CTRL-SHIFT`, `ALT-CTRL-SHIFT`. `HH.SplitKey("ALT-SHIFT-1")` gives `ALT-SHIFT` and `1`. Left and right modifiers count as the modifier. The minus key is handled (`SHIFT--` is Shift and `-`).

`HH.BARS` lists each bar with the frame names it may have (the main bar is `MainActionBar` on newer builds and `MainMenuBar` on older ones), its buttons' global names and their binding commands (`ACTIONBUTTON1`, `MULTIACTIONBAR1BUTTON1`, `BONUSACTIONBUTTON1` for the pet bar, `SHAPESHIFTBUTTON1` for the stance bar).

`HH.Layout()` runs at login, on `UPDATE_BINDINGS` and when a setting changes. For each bar it reads every button's keys with `GetBindingKey`, counts the layers, and takes the one most buttons share (a tie goes to the layer listed first). A bar with no keys has no layer. A per-bar setting can fix the layer or exclude the bar.

## The highlight

`HH.Held()` builds the held layer from `IsAltKeyDown`, `IsControlKeyDown` and `IsShiftKeyDown`. While an edit box has keyboard focus it answers `NONE`.

`HH.Apply()` runs on `MODIFIER_STATE_CHANGED`, on entering and leaving combat, when a bar or Edit Mode is shown or hidden, and after `Layout`. It is active when the addon is on, Edit Mode is closed, the combat-only setting allows it, and some bar has the held layer. Then:

- the bar of the held layer: its own opacity, and the highlight around it;
- bars of other layers: `SetAlpha(dim / 100)`; the opacity each had before is remembered and put back when the fade ends;
- bars with no layer: untouched.

While a modifier is held, an `OnUpdate` check runs five times a second and re-applies if the held layer changed without an event (the game window lost focus with the key down). With nothing held there is no `OnUpdate`.

## What it relies on in the game

- `SetAlpha` on the game's bar frames is not a protected call, so it is allowed in combat.
- The highlight frames are children of `UIParent`, anchored to the bar. They are not children of the bar, so the bar's own layout code never meets them. They are made in `Layout`, normally outside combat.
- The soft glow is eight textures outside the bar's edges: four sides and four corners (`Textures\Glow*.tga`, 32 x 32, white, with opacity falling off as the square of the distance from the bar). Each piece has its own file, so none depends on turning a texture around. `SetVertexColor` gives the color and opacity; the glow size sets each side's depth and each corner's width and height. The thin line is four solid textures on a second frame; only one of the two frames shows.
- `HookScript` on a bar's `OnShow` and `OnHide`, and on `EditModeManagerFrame`, to follow visibility.
- The key label is each button's `HotKey` font string. Its `SetText` is hooked with `hooksecurefunc`, so the game's write runs first and unchanged; the hook then writes the short text. A flag stops the hook from answering its own write. Only text is written: font, color, size and anchors are the game's.
- A button with no key keeps the game's text, which is its range dot.

None of this was confirmed line by line against the Forever client's interface source, but 0.1.0 ran in that client: the five standard bars and the pet bar were found, faded and labelled as intended. `/hh status` reports what was found, which is the first thing to check when something does not show.

## Secret values

On Forever some values are "secret" to addon code in combat. Nothing this addon reads is expected to be secret (key bindings, modifier state, a bar's opacity), but each read is checked with `issecretvalue` where it exists: a secret modifier state counts as not held, a secret opacity as 1.

## Not covered

Bar replacement addons, the extra action button, vehicle and override bars, and per-button highlighting.
