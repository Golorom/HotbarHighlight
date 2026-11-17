# Development

## Rules

1. Looks only. No key binding, no secure attributes, no moving or resizing the game's frames, no casting, no console variables.
2. Nothing is ever sent to other players: no chat, emotes, markers or addon messages.
3. No required dependencies and no bundled libraries.
4. Every part starts through `Start` in `Core.lua`, so one failure is reported and the rest still run.

The test "source scan" enforces 1 and 2 by searching every file for the calls involved.

## Tests

Lua 5.1, from the repository root:

```
lua5.1 tests/run.lua
```

The tests load the four files into a stand-in for the game's functions (`tests/run.lua`, `fixture`). The default fixture is five bars on a 12-key grid, one bar per modifier layer, plus a bar with no keys. A pass shows the logic holds together; it does not show the real frames behave like the stand-in. Anything about the real client has to be checked in the game: `/hh status`, then BugSack.

Add a test with each change. When the game is found to behave differently from the stand-in, change the stand-in first, watch the test fail, then fix the code.

## In-game check list

1. `/hh status`: every bar you use is found, with the layer you expect.
2. Hold each modifier in turn out of combat, then in combat on a training dummy.
3. Open and close Edit Mode while holding a modifier.
4. Rebind a key and look at the label.
5. BugSack: no errors naming `HotbarHighlight`.

## Releases

1. Set `## Version:` in `HotbarHighlight.toc` and add a `## <version>` section at the top of `CHANGELOG.md`.
2. Commit, then tag `v<version>` and push the tag.
3. The Release workflow runs the tests, checks that the tag matches the TOC, builds `HotbarHighlight-v<version>.zip` (the addon in a `HotbarHighlight` folder, without `tests`, `docs` and `.github`) and publishes it as a GitHub release with that changelog section as its notes.

## Layout

```
HotbarHighlight.toc   file list and metadata
Core.lua  Bars.lua  Labels.lua  Options.lua
Textures/             the glow's eight pieces (a new or renamed file needs a game restart)
tests/run.lua         stand-in and tests
docs/                 this file and HOW-IT-WORKS.md
.github/workflows/    tests on every push, release on a version tag
```
