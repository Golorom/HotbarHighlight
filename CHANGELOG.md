# Changelog

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
