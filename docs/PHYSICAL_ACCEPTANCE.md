# Shuffle Keyboard physical acceptance

Use a supported 10–13 inch touch device in its normal Plasma Wayland session.
Complete this pass without a physical keyboard or mouse after setup, except
where a check asks for one.

## Install and enable

1. Open a terminal in this checkout and run:

   ```sh
   ./install-keyboard.sh
   ```

   It builds, replaces the copy in your own prefix, and checks that what
   landed is what was built. No password, and nothing outside your home
   directory. The Keyboard you are typing on is still the previous copy until
   you have signed out and back in, which the script says as well.

2. Open **System Settings → Keyboard → Virtual Keyboard**.
3. Select **Shuffle Keyboard** and choose **Apply**.
4. If it does not become available immediately, sign out and sign back in once.
5. Tap a text field. The keys come up and the bottom panel or dock steps aside.

To stop the test at any time, return to **Virtual Keyboard**, select **None**,
and apply.

## Pass / Fail / Note

Record one line for each item as `Pass`, `Fail`, or `Note: …`. What each input
does is [`INPUT.md`](INPUT.md); these checks test it on the device.

- **Every input:** Go through `INPUT.md` row by row by touch, then again with a
  mouse wherever a row can take a click. Each row does what it says. Name any
  that does not.
- **Invocation:** Tapping text fields opens the keyboard every time.
- **Put away:** Put the keys away with Hide ten times. They go every time, and
  a text field brings them back every time.
- **Panel handoff:** The normal bottom panel yields without overlap or visible
  bouncing and returns after dismissal.
- **Dock handoff:** With the Bottom Surface installed instead, raising the
  keyboard slides the dock down and out rather than blinking it away, and
  dismissing brings it back with a small settle. Nothing is ever left holding
  space it is not using, and the dock never arrives on top of anything.
- **Fast text:** Type a sentence quickly in a KDE/Qt app, a GTK app, Firefox,
  Chromium or an Electron app, and a terminal. No character is lost,
  duplicated, reordered, or wrongly mapped.
- **Repeated letters:** Type `bookkeeper committee coffee` at normal speed.
  Every repeated letter registers without deliberately slowing the second tap.
- **Overlapping thumbs:** Type `the quick brown fox` as fast as you can with
  both thumbs, letting the next thumb land before the last one lifts. Every
  letter arrives, in order.
- **Space:** Type a paragraph at speed. Every tap on the space bar types one
  space; none latches the trackpad and none starts the caret trackpad.
- **Caret trackpad:** In a KDE app, a browser and a terminal, hold the space
  bar, then move the cursor left, right, up and down; then do the same by
  sliding along it. The cursor follows, nothing is typed, and the keys return
  at lift with the cursor where it was left.
- **Delete scrub:** In a KDE app and a browser, drag left from Delete across
  five characters, slide back two and lift. Exactly three are deleted. In a
  terminal the count shows on the key and three Backspaces arrive. Flick left
  from Delete: one word goes.
- **Flicks:** Flick each key in the top row down for its digit, and comma,
  period, slash and every mark on the symbols layer for its shift. Each types
  the grey character above it, and a flick never types the key's own character
  as well. Then type a sentence fast with two thumbs: no flick fires by
  accident.
- **Modifiers:** In a chat box, tap Shift then Go: a new line, nothing sent.
  In a form, Shift then Tab moves to the previous field. Tap Shift, then slide
  along the space bar: the text selects. Open a menu and flick `123` down: it
  closes.
- **Accents:** Hold e, slide to `é` and lift. It types `é`; lifting off the
  accents types nothing.
- **Layers:** Run quickly through Shift, Caps, `123`, the emoji panel and `ABC`
  several times. Each behaves as `INPUT.md` § Keys says, and nothing is left
  stuck on.
- **Row stagger:** Q begins at 1 unit, A at 1.25, and Z at 1.75, and the gap
  between T and Y sits at the card's centre. Every character key keeps the
  same pitch across all three rows.
- **Rows:** The rows read as `KEYBOARD-CONTRACT.md` § Layout lists them,
  without clipping or unexpectedly narrow targets. Tap Shift followed by
  comma, period and slash; they enter `<`, `>` and `?`, then return Shift to
  neutral after each character.
- **Right controls:** Delete, Go, the slash and Hide end on one right edge. Go
  fills the home-row gap and is muted Ghost White with dark text, and no
  right-edge key moves a letter.
- **Bottom row:** The order is Ctrl, Alt, large Space, Tette Dot, Hide. The dot
  works as the modifier-only `Meta` shortcut and opens Tettegouche.
- **Square geometry:** Ordinary letter keys are square, or narrowed together
  only as far as the twelve-and-a-half-unit block needs to fit the card.
- **Layer fit:** The symbols layer and the emoji panel keep the card's shape
  with no overlap, clipping, unexpectedly narrow targets, or dead gaps that
  interrupt typing.
- **Top strip:** Nothing is drawn above the keys, and touching the strip does
  nothing.
- **Latch:** Tap the trackpad mark. The keys dim and stop typing, and they stay
  up while the pointer clicks into other applications. Tap the mark again:
  typing resumes at once, into whatever the last click focused. Latch again
  and tap Hide: the keys go and stay away, and the next text field brings
  them back for typing. Do the same with the tray entry.
- **Pointer:** While latched, point, click, drag to select text, drag an item,
  scroll a long page and right-click, in a KDE app and in a browser. Each lands
  where the pointer is, and none needs a second try.
- **Pointer permission:** The first latch asks once for permission to control
  the pointer. After it is allowed it is not asked again, including after
  signing out and in.
- **Touch reach:** Type several sentences at normal speed. Note any intended
  key that lands left or right of the target.

## Raised from the tray entry

- **It rises:** With nothing selected for typing, tap Keyboard in Control Center
  or the tray. Control Center closes, the keys rise, and the card above makes
  room as they rise rather than after they arrive.
- **It works straight after signing in:** Sign in and, before touching any text
  field, tap the entry. The keys come up the first time.
- **It keeps the focus where it is:** Tap into a text box, put the keys away,
  then tap the entry. What you type goes into that same box.
- **It puts them away:** With the keys up, tap the entry. They slide down.
- **Nothing sits on the dock:** With the Bottom Surface installed and the keys
  down, there is no bar on top of the dock, and a maximized window reaches
  down to the dock itself.

## Notes

The row geometry is settled ([`FEASIBILITY.md`](FEASIBILITY.md) § Row
geometry), so a miss pattern found in this pass is a finding about the Shuffle
layout itself, not a question about which geometry to use.

Include the application name and exact observed behavior in every failure note.
