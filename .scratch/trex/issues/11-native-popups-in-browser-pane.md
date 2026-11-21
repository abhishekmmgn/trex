# 11: Native popups open in a Browser Pane

**What to build:** Clicking a native `<select>` (and the other built-in popups listed below) in a Browser Pane opens something the user can see and pick from. Today nothing opens. Example: https://ui.shadcn.com/docs/components/base/native-select. shadcn's regular Select opens fine, because it is made of ordinary page elements.

**Blocked by:** None

**Status:** needs-triage

## Why it happens

kb runs Chrome with `--headless=new` and draws the page from `Page.startScreencast` frames. On macOS, Chrome normally shows these popups as native widgets outside the page (a select's dropdown is an `NSMenu`). Headless Chrome has no window or native widgets, so the popup never exists. The page still gets `mousedown` and the element gets focus, so it looks clickable, but nothing opens. This is not a trex or kb bug, it is headless Chrome.

Checked on 2026-11-21 against headless Chrome 158 started like kb (CDP clicks, then a screenshot and the element's state):

| Element | In a Browser Pane |
|---|---|
| `<select>` (single) | Broken: no dropdown, `:open` stays false, ArrowDown + Enter does not change the value |
| `<input type=date/time/datetime-local/month>` | Picker broken: clicking the calendar or clock icon shows nothing. Typing into the fields works |
| `<input list>` with `<datalist>` | Broken: no suggestions while typing |
| `<input type=file>` | Broken: no file dialog. CDP can catch it (`Page.setInterceptFileChooserDialog` fires `Page.fileChooserOpened`), so kb could offer its own |
| Right-click context menu | Broken: no menu |
| `title` tooltips | Broken: none show on hover |
| Autofill and saved-password dropdowns | Probably broken (not tested) |
| `<input type=color>` | Works: Chrome draws the picker inside the page |
| `<select multiple>`, `<select size=N>` | Work: the list box is drawn inside the page |
| `select { appearance: base-select }` (customizable select) | Works: the picker is in the page's top layer |
| `alert`/`confirm`/`prompt`/`beforeunload` | kb already handles these (`Page.javascriptDialogOpening` in its `devtools.rs`) |

Agents are not affected for `<select>`: `kb ctl select` sets the value in the page directly.

## Plan (chosen by the user)

kb shows its own picker. When the user clicks a `<select>` in the pane, kb reads its options and shows a small list in the pane. Choosing one sets the value with the input and change events `kb ctl select` already sends. The page's own styling is untouched. The same approach can later cover the date picker, datalist suggestions and the file dialog. Under ADR-0001 this is an upstream kb PR, like tickets 05 and 08.

Rejected:
- Injecting `select, ::picker(select) { appearance: base-select }` into every page. It works, but it changes how every select looks, so the pane no longer shows the real UI.
- Injecting a script that draws its own dropdown in the page. This changes the page's DOM behind the site's back and can break sites.

- [ ] kb: picker for a clicked `<select>` (options, current value, disabled options, `<optgroup>`), setting the value with input and change events
- [ ] kb: keyboard on a focused `<select>` (arrows, Enter, Escape) opens or drives the same picker
- [ ] Decide with the user whether the date picker, datalist, file dialog and context menu come in the same PR or later

## Comments

- 2026-11-21: the user reported that the native select on ui.shadcn.com doesn't open. Not a priority: record it now and fix it later. The user chose the plan above (kb shows its own picker).
