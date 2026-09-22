# Shuffle Keyboard physical acceptance

Use a supported 10–13 inch touch device in its normal Plasma Wayland session.
Complete this pass without a physical keyboard or mouse after setup.

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
5. Tap a text field. The keyboard should replace the normal bottom panel.
To stop the test at any time, return to **Virtual Keyboard**, select **None**,
and apply. The keyboard was intentionally left disabled before this acceptance
pass.

## Pass / Fail / Note

Record one line for each item as `Pass`, `Fail`, or `Note: …`.

- **Invocation:** Tapping text fields opens the keyboard every time.
- **Dismissal:** Tapping the centered top grab handle closes it; tapping a text
  field opens it again.
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
- **Layers:** Tap Shift for one-shot capitalization; double-tap it for Caps
  Lock; tap it again to unlock. `123` exposes numbers/symbols, Shift on that
  layer exposes the remaining symbols and desktop navigation keys, and `ABC`
  returns immediately.
- **Row stagger:** Q begins at 1.00 units, A at 1.25, and Z at 1.75. Every
  character key keeps the same pitch across all three rows.
- **Lower row:** The lower row reads Shift, Z–M, comma, period, slash without
  clipping or unexpectedly narrow targets. Tap Shift followed by comma,
  period, and slash; they enter `<`, `>`, and `?` respectively, then return
  Shift to neutral after each character.
- **Right controls:** Backspace and Enter share one aligned right edge. Enter
  fills the home-row gap, is muted Ghost White with dark text, and neither
  control moves QWERTY.
- **Bottom row:** The order is Ctrl, Alt, large Space, Tette Dot; the dot works
  as the modifier-only `Meta` shortcut and opens Tettegouche.
- **Square geometry:** Ordinary QWERTY keys are square and keep one fixed pitch.
  There is no horizontal adjustment rail.
- **Layer fit:** Both symbol layers preserve the unified shape with no overlap,
  clipping, unexpectedly narrow targets, or dead gaps that interrupt typing.
- **Height:** On first launch, ordinary keys are approximately square. Drag the
  centered top grab to both comfortable extremes. The app workspace follows
  the edge continuously, and the chosen height survives a close/reopen.
> The height, Shuffle-surface, Shuffle-transition, pointer-button and
> edit-gesture steps below test the superseded interaction. They stay until the
> 22 September direction is built, because they are the pass for the candidate
> that exists; `../README.md` names what replaces each. Do not treat a pass here
> as evidence for the direction, or a conflict with it as a defect in this build.

- **Shuffle surfaces:** The centered keyboard leaves unoutlined hold space on
  both edges. Either edge enters the same precision mode.
- **Shuffle transition:** Hold that blank surface; the precision surface
  appears only while held, dims and disables the visible keys, and accepts
  pointer gestures over the complete keyboard footprint. Release returns to
  typing. It never remains latched.
- **Pointer buttons:** Move the pointer while holding either edge, then release.
  A short tap on either edge clicks at the pointer; two quick taps select the
  word under it. While the precision surface is held, a short one-finger tap
  also clicks, a hold-drag selects text or moves an item, and a two-finger tap
  produces a secondary click.
- **Edit gestures:** On the blank surface, a two-finger tap copies, a
  three-finger tap cuts, a left swipe undoes, and a right swipe redoes. None
  fire while typing on an adjacent key.
- **Touch reach:** Type several sentences at normal speed. Note any intended
  key that lands left or right of the target.

## The handle above the dock

These need the Bottom Surface installed. On an ordinary Plasma panel there is
no handle, which is the supported result and not a failure.

- **It is there:** A translucent light bar sits directly on top of the dock,
  as wide as the row of application icons, with the same even gap above it to
  the window as below it to the icons. Windows stop above it rather than
  running under it.
- **It grows with the row:** Open another application. The line widens with
  the row and stays centered on it.
- **It raises:** Tap the line with nothing selected for typing. The keyboard
  comes up.
- **It raises on a pull:** Put a finger on the line and drag upward. The
  keyboard comes up before the finger has gone far.
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

## Row geometry is settled

The fixed pitch and the Q/A/Z stagger were chosen by an on-device comparison
against a conventional four-row iPad layout built on this keyboard's exact
delivery path. That comparison found essentially no misses on the fixed pitch,
and Shuffle adopted the same geometry, so it is not re-run and the comparison
keyboard has been removed. A miss pattern found in this pass is therefore a
finding about the Shuffle layout itself, not a question about which geometry to
use.

Include the application name and exact observed behavior in every failure note.
