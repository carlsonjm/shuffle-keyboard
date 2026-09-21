# Shuffle Keyboard

Shuffle Keyboard is a touch-first keyboard and precision desktop surface for
KDE Plasma 6. It keeps input delivery in the mature Qt Virtual Keyboard and
KWin input-method stack while owning the contracted Shuffle layout, gestures,
height, panel handoff, and presentation.

The implementation is based on Plasma Keyboard 6.7.5. It does not implement a
custom input engine.

## Current candidate

- Four large QWERTY rows with one invariant character pitch and the physically
  validated iPad-baseline stagger: Q at 1.00 units, A at 1.25, and Z at 1.75.
- Hairline Ghost White key outlines on the Itasca `#141414` surface. The
  typing block derives its width from row height so ordinary keys remain
  square; a manually chosen height remains persisted.
- `123` and Tab fill the first two left edges. Shift fills the third, where a
  tap is one-shot Shift and a double tap locks Caps. Backspace and the muted
  Ghost White Enter share one aligned right edge; Enter fills the home-row gap
  and the enlarged `/` completes the third row without moving the letter grid.
- Bottom controls are Ctrl, Alt, large Space, and a Tette Dot Meta key. The dot
  is the protected resting brand mark, not a generic text label. It resolves
  the user's live bare-Meta binding through KDE's global-shortcut service and
  invokes that configured action without hard-coding a particular applet.
- The typing block is derived from the selected row height, keeping ordinary
  keys square instead of stretching them across the panel. It is centered so
  either edge supplies an unboxed Shuffle/edit hold surface.
- Holding that surface temporarily disables and dims the visible keyboard while
  the full footprint becomes a precision surface. Releasing returns immediately
  to typing. A tap on either edge clicks at the current pointer position, so a
  natural double tap selects the word under the pointer. Two- and three-finger
  taps provide Copy and Cut; horizontal swipes provide Undo/Redo.
- Persisted, directly draggable height with live KWin workspace updates.
- Plasma's bottom panel yields while the keyboard is requested and restores
  its previous hiding mode afterward.

## Four-row iPad baseline

The same executable also supplies **iPad Layout Baseline** as a second Plasma
virtual keyboard. It uses the identical Qt Virtual Keyboard/KWin delivery path
and the same four-row panel footprint as Shuffle, but substitutes conventional
iPad-style key geometry and presentation:

- A fixed character pitch across all typing rows, with Q at 1.00 units,
  A at 1.25 units, and Z at 1.75 units.
- Tab and Delete flanking QWERTY without compressing the letter keys.
- Caps Lock and a large Go key filling the home-row edges.
- Full Shift keys flanking Z–M, comma, period, and slash.
- iPad-style bottom-row proportions with a large centered Space key.

The emoji and microphone positions are visible but intentionally inactive;
emoji and dictation infrastructure are outside the Shuffle 1.0 contract. The
baseline exists to isolate layout accuracy from input delivery and to support
a direct physical A/B comparison with Shuffle. The first comparison reported
essentially no misses on this fixed-pitch geometry, which is now the geometry
used by the Shuffle candidate.

See [the feasibility record](docs/FEASIBILITY.md) for the foundation decision
and test evidence.

## Build

On an Arch-family Plasma 6 development system:

```sh
cmake -S . -B build -G Ninja -DBUILD_TESTING=OFF -DCMAKE_BUILD_TYPE=RelWithDebInfo
cmake --build build
```

The executable is `build/bin/shuffle-keyboard`.

## Install into a test prefix

Do not replace the active desktop keyboard while developing. Install into a
staging prefix first:

```sh
cmake --install build --prefix "$PWD/stage"
```

For a real-device acceptance install, use the exact steps supplied with the
candidate being tested. KWin must start the binary as its virtual keyboard;
running it as a normal application intentionally fails unless preview mode is
enabled for an isolated test.
