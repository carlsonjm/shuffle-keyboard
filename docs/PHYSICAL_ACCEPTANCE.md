# Shuffle Keyboard physical acceptance

Use a supported 10–13 inch touch device in its normal Plasma Wayland session.
Complete this pass without a physical keyboard or mouse after setup, except
where a check asks for one.

## Install and enable

1. Open a terminal and run:

   ```sh
   /home/ghostiepost/Projects/Shuffle/shuffle-keyboard/install-keyboard.sh
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
- **Put away:** Put the keys away from their handle ten times, by tap and by
  drag. They go every time, and a text field brings them back every time.
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
- **Space:** Type a paragraph at speed. Every tap on the space bar types one
  space, and none latches the trackpad.
- **Layers:** Run quickly through Shift, Caps, `123`, the second symbols layer
  and `ABC` several times. Each behaves as `INPUT.md` § Keys says, and nothing
  is left stuck on.
- **Row stagger:** Q begins at 1.00 units, A at 1.25, and Z at 1.75. Every
  character key keeps the same pitch across all three rows.
- **Lower row:** The lower row reads Shift, Z–M, comma, period, slash without
  clipping or unexpectedly narrow targets. Tap Shift followed by comma,
  period, and slash; they enter `<`, `>`, and `?` respectively, then return
  Shift to neutral after each character.
- **Right controls:** Backspace, Enter, slash and the Tette Dot end on one
  right edge. Enter fills the home-row gap and is muted Ghost White with dark
  text, and no right-edge key moves a letter.
- **Bottom row:** The order is Ctrl, Alt, large Space, Tette Dot; the dot works
  as the modifier-only `Meta` shortcut and opens Tettegouche.
- **Square geometry:** At the default height, ordinary letter keys are square.
  At every other height only key height differs: no key, the space bar or a
  scrub column moves sideways.
- **Layer fit:** Both symbol layers preserve the unified shape with no overlap,
  clipping, unexpectedly narrow targets, or dead gaps that interrupt typing.
- **Height:** Scrub the right column to both ends and back to the bright
  default notch. The keys follow notch by notch, the reading matches, and the
  window above makes room at each height. The chosen height survives putting
  the keys away, bringing them back, and signing out and in.
- **History scrub:** Type a sentence in a KDE app and in a browser, scrub the
  left column several notches toward undo, then part of the way back before
  lifting. Exactly the notches still passed stay undone.
- **Notch feel:** Each notch in either column clicks and holds briefly before it
  gives. Note whether the hold reads as feedback or as delay.
- **Terminal history:** In a terminal, the left column changes nothing and
  interrupts nothing.
- **Latch:** Tap the trackpad mark. The keys dim and stop typing, and they stay
  up while the pointer clicks into other applications. Tap the mark again:
  typing resumes at once, into whatever the last click focused.
- **Pointer:** While latched, point, click, drag to select text, drag an item,
  scroll a long page and right-click, in a KDE app and in a browser. Each lands
  where the pointer is, and none needs a second try.
- **Pointer permission:** The first latch asks once for permission to control
  the pointer. After it is allowed it is not asked again, including after
  signing out and in.
- **Touch reach:** Type several sentences at normal speed. Note any intended
  key that lands left or right of the target.

## The handle above the dock

These need the Bottom Surface installed. On an ordinary Plasma panel there is
no handle, which is the supported result and not a failure.

- **It is there:** A nearly white bar sits directly on top of the dock,
  as wide as the row of application icons, with the same even gap above it to
  the window as below it to the icons. Windows stop above it rather than
  running under it.
- **It grows with the row:** Open another application. The line widens with
  the row and stays centered on it.
- **It raises:** Tap the line with nothing selected for typing. The keyboard
  comes up.
- **It raises on a pull:** Put a finger on the line and drag upward. The
  keyboard comes up before the finger has gone far.
- **It works straight after signing in:** Sign in and, before touching any text
  field, pull the handle. The keyboard comes up the first time.
- **It keeps the focus where it is:** Tap into a text box, put the keyboard
  away, then pull the handle. What you type goes into that same box.
- **It gives the focus back:** Raise the keyboard from the handle, dismiss it,
  and type on a physical keyboard. The text goes to the application that had
  the focus before, and nothing is lost.
- **It gets out of the way:** With the keyboard up, the line is gone.
- **It comes back:** Dismiss the keyboard. The line returns with the dock.
- **It leaves before the dark:** Put a window full screen until the bottom
  strip goes solid black. The line goes first; there is never a black strip
  with a line floating over it.
- **It does not take taps that are not for it:** Tap in the same gap but well
  to the left and to the right of the line. Whatever is underneath gets the
  tap and the keyboard stays down.
- **Reaching for it:** Pull the bar up ten times at a natural speed and note
  how many attempts miss, and whether a miss lands on an application icon
  instead. A pull is the gesture; a tap has to land on the bar itself.

## Notes

The row geometry is settled ([`FEASIBILITY.md`](FEASIBILITY.md) § Row
geometry), so a miss pattern found in this pass is a finding about the Shuffle
layout itself, not a question about which geometry to use.

Include the application name and exact observed behavior in every failure note.
