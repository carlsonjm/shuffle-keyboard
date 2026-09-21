# Shuffle Keyboard physical acceptance

Use a supported 10–13 inch touch device in its normal Plasma Wayland session.
Complete this pass without a physical keyboard or mouse after setup.

## Install and enable

1. Open a terminal and run:

   ```sh
   cd /home/ghostiepost/Projects/Itasca/shuffle-keyboard
   cmake -S . -B build -G Ninja -DBUILD_TESTING=OFF -DCMAKE_BUILD_TYPE=RelWithDebInfo
   cmake --build build
   cmake --install build --prefix /home/ghostiepost/.local
   kbuildsycoca6
   ```

2. Open **System Settings → Keyboard → Virtual Keyboard**.
3. Select **Shuffle Keyboard** and choose **Apply**. The same install also adds
   **iPad Layout Baseline** for the comparison pass below.
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
  clipping or unexpectedly narrow targets.
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

## Four-row baseline comparison

1. In **System Settings → Keyboard → Virtual Keyboard**, select
   **iPad Layout Baseline** and choose **Apply**.
2. Use the same panel height and type the same two sentences without correcting
   mistakes.
3. Switch back to **Shuffle Keyboard**, repeat once, then record:

- **Footprint:** Both keyboards occupy the same four-row panel height.
- **Fixed pitch:** Q, A, and Z-row character keys have the same width; Tab,
  Caps Lock, Shift, Delete, and Go do not compress their neighboring letters.
- **Stagger:** A begins one-quarter key right of Q, and Z begins three-quarters
  of a key right of Q.
- **Q row:** Note every intended key and the key actually hit.
- **A row:** Note every intended key and the key actually hit.
- **Z row:** Note every intended key and the key actually hit.
- **Reach:** Note which layout requires less horizontal hand movement.
- **Controls:** Note whether Delete, Go, either Shift, Space, `.?123`, and the
  hide key are comfortably sized and placed.
- **Delivery:** No character is lost, duplicated, reordered, or incorrectly
  mapped on either layout.

The emoji and microphone keys are inert in this 1.0 baseline. That is expected,
not a failure.

Initial physical result: the fixed-pitch baseline produced essentially no
misses. Shuffle now uses the same pitch and stagger, so further comparison is
focused on its edge controls and mode transition rather than re-evaluating the
input engine.

Include the application name and exact observed behavior in every failure note.
