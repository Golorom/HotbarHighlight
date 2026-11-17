# Changelog

## 1.0.0 (2026-11-17)

First release. Everything below was played in the game on World of Warcraft: Forever before it went out.

- While you hold Shift, Ctrl, Alt or a mix of them, the action bar whose keys use those modifiers gets a soft glow (or a thin line) and the other bound bars fade.
- Each bar's layer is read from its key bindings. A bar can also be given a layer by hand or left alone.
- The highlight goes around the whole bar or only around the buttons shown.
- Key labels: short text (`S1`, `AC1`), the key alone, or the game's own; their place in the button, offsets, size and opacity.
- Settings page (Options, AddOns, Hotbar Highlight) and `/hh`.

Since 0.3.0: the label offsets also work from the game's own place, and each label is moved on its own.

## 0.3.0 (2026-11-17)

Added
- Key label look: where the label sits in its button (a corner, a side or the center), left/right and down/up offsets that also work from the game's own place, its size in percent, and its opacity. Each label is moved on its own; if any refuse, a chat line and `/hh status` say how many and why. Whatever look a label has from the game or from another addon is the base, and these settings go on top, so an addon that sizes or places the same labels is not fought. A label's place changes out of combat; a change made in a fight shows when it ends.
- Highlight area: around the whole bar (as before), or only around the buttons shown, for a bar set to fewer icons or with empty slots hidden.

## 0.2.1 (2026-11-17)

Fixed
- The glow's inner corners. The buttons' corners are round and the glow's inner edge was straight, so the world showed through at the bar's corners and where two buttons meet at an edge. The glow now also reaches a little way in under the bar's edge and sits one layer below the bar, so the buttons cover it except in those gaps. Setting: Inner glow (14% of a button's size; 0 turns it off).

## 0.2.0 (2026-11-17)

0.1.0 was played in the game and worked: layers found from the keys, highlight and fade, short labels.

Added
- Soft glow around the highlighted bar, fading outward; it is the default. The thin line stays as a style.
- Highlight color from the game's color picker (a list of six colors on a client without it), highlight opacity, glow size.

Changed
- The saved color is now `aarrggbb`; a color name saved by 0.1.0 is converted.

## 0.1.0 (2026-11-17)

First version.

- Each bar's layer is read from its key bindings; a per-bar setting can fix it or leave the bar alone.
- While a layer's modifiers are held: a border around its bar, the other bound bars faded.
- Key labels: short (`S1`, `AC1`), key only, or the game's own.
- Settings page and `/hh`, `/hh status`, `/hh on`, `/hh off`.
- Tests against a stand-in for the game. Not yet played in the game.
