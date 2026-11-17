# Changelog

## 0.3.0 (2026-11-17)

Added
- Key label look: where the label sits in its button (a corner, a side or the center, with left/right and down/up offsets), its size in percent, and its opacity. Whatever look a label has from the game or from another addon is the base, and these settings go on top, so an addon that sizes or places the same labels is not fought. A label's place changes out of combat; a change made in a fight shows when it ends.
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
