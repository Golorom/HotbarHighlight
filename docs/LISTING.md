# Listing text

Text for the project pages on CurseForge and Wago.

| Field | Text |
|---|---|
| Name | Hotbar Highlight |
| Summary | A visual aid addon. Hold a modifier and the action bar bound to it glows while the others fade. Made for the default UI. |
| Category | Action Bars |
| Game version | World of Warcraft Forever, interface 16001 |
| License | MIT |
| Source | https://github.com/Golorom/HotbarHighlight |
| Issues | https://github.com/Golorom/HotbarHighlight/issues |
| Donation link | https://boosty.to/goromajur/donate |
| Logo | `docs/images/thumbnail-512.png` (square, also as `thumbnail-1024.png`). Wide version `docs/images/wide-1280x640.png`. |
| Screenshots | `.previews/1-alt-ctrl-held.png`, `.previews/2-alt-shift-held.png` |

## Description

A visual aid addon. Hold Shift, Ctrl or Alt and the action bar bound to that modifier glows while the others fade.

Made for the default UI. A custom UI or an action bar addon may not work.

**Features**

- Finds each bar's modifier from your key bindings. No setup.
- Soft glow or thin line in any color. The other bars fade as much as you set.
- Highlight around the whole bar or only around the visible buttons.
- Short key labels such as S1 and AC1. Move, resize and fade them.
- Pet bar and stance bar key labels in the same size and place as on the action bars.
- Bars without key bindings are left alone. Modifiers no bar uses do nothing.
- Visual only.
- Covers Action Bars 1 to 8, the pet bar and the stance bar.

Settings open with `/hh` or from Options, AddOns, Hotbar Highlight. `/hh status` lists what the addon found on your bars.

Free and open source. Donations are welcome at https://boosty.to/goromajur/donate.

## After the page exists

1. Put the project's ID into `HotbarHighlight.toc` as `## X-Curse-Project-ID` and `## X-Wago-ID`.
2. Add the keys to the repository under Settings, Secrets and variables, Actions, as `CF_API_KEY` and `WAGO_API_TOKEN`.
3. The next release uploads to both sites.

## WowUp

The WowUp Hub lists addons straight from GitHub releases. It has no page to fill in.

- Game version. It reads the TOC. `## Interface: 16001` marks the addon as WoW Forever. Each release also carries `release.json` with the flavor `forever`.
- Icon. The repository's social preview image. Upload `docs/images/thumbnail-1024.png` under Settings, General, Social preview.
- Screenshots. The `.previews` folder as it is at the release.
- Category. The repository topic `action-bars`.
- Donation link. `.github/FUNDING.yml`.
