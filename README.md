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
- Hairline Ghost White key outlines on the Itasca `#141414` surface, drawn as
  a card: Kadunce's 10 px gutter at either side only, 18 px corners at the top,
  flush with the screen's bottom edge and lying over the window above. The
  dock's handle rides its top strip with 10 px clear above it and above the
  keys.
- Only key height changes, so the keys and the space bar never move sideways.
  The card is 35% to 55% of the screen's height in steps of one, saved as that
  share; the default, 45%, has square keys, which sets the key width.
- The width either side of the keys carries a scrub column, close to invisible
  until touched. Left is the edit history: down undoes and up redoes, a step per
  notch as the finger passes it, so sliding back cancels. Right is height: up
  is taller, a notch per percent, with the default marked. A notch holds until
  the finger is 70% of the way past it, and clicks with the keyboard's quiet
  tick.
- `123` and Tab fill the first two left edges. Shift fills the third, where a
  tap is one-shot Shift and a double tap locks Caps. Backspace and the muted
  Ghost White Enter share one aligned right edge; Enter fills the home-row gap
  and the enlarged `/` completes the third row without moving the letter grid.
- The punctuation keys share their standard shifted characters: comma/`<`,
  period/`>`, and slash/`?`. They stay in the accepted letter layout and avoid
  a `123` round trip for these common characters.
- Bottom controls are Ctrl, Alt, large Space, and a Tette Dot Meta key. The dot
  is the protected resting brand mark, not a generic text label. It resolves
  the user's live bare-Meta binding through KDE's global-shortcut service and
  invokes that configured action without hard-coding a particular applet.
- There is no pointer between this slice and the space-bar pointer, which
  replaces the retired edge hold; copy, cut and paste are Ctrl chords.
- A drag down on the handle carries the keys away, and a tap puts them away.
- Plasma's bottom panel yields while the keyboard is requested and restores
  its previous hiding mode afterward. Where the downstream Bottom Surface is
  installed the region is asked for instead of the panel being commanded, and
  the surface decides what giving it up means.
- A drag handle above that surface's application row raises the keyboard when
  nothing has asked for text. It is a layer surface of the keyboard's own,
  because the keyboard's window is an input panel and the compositor unmaps it
  exactly when the handle is needed. It reserves nothing, takes its width from
  the published dock extent, and leaves before the region goes solid. A pull
  never takes the focus from a text box that is ready to be typed into; only
  a cold start, with nothing ready, borrows it until the keyboard goes.
- The keys arrive from the screen's edge once the dock has left and given up
  its room. A pull on the handle or the dock carries them under the finger,
  opening past a quarter of the way or on a flick upward and going back down
  otherwise; any other raise brings them up on their own.

## Superseded by the 22 September direction

J built this candidate and used it before its product contract was tested, and
four of that contract's interaction hypotheses did not survive the use. The suite
concept, `../kadunce/docs/SHUFFLE-KEYBOARD-1.0-CONCEPT.md`, is the product
contract and now records what replaces them. Nothing below is built yet, and this
list exists so the current candidate's behavior is not mistaken for the target.

- **Edge hold surfaces stop being the pointer.** The space bar becomes it: press
  and slide, armed by about ten pixels of travel rather than by a timer, so an
  ordinary space is never lost. The keys step back but are never replaced or
  disabled, so there is no mode to leave. A control at the space bar's right end
  latches the surface, which today's precision mode deliberately never does.
- **Both edges change owner.** They become scrub columns: multi-step undo and
  redo on the left, key height on the right, each notched and close to invisible
  until touched. Undo and redo were the only edit gestures worth keeping; copy
  and cut return to modifier chords.
- **The draggable top grab goes.** Height moves to the right scrub column, with a
  marked default, because a continuous drag loses the one size already known to
  be right. Show and hide then owns the top edge alone.

One more item follows from the suite rather than from this list:
`bottomsurfacecoordinator` asking Plasma's bottom panel to yield is replaced by
asking the downstream Bottom Surface, which owns that region; the arrangement is
specified in `../shuffle/docs/BOTTOM-SURFACE-CONTRACT.md` and this repository
keeps its current behavior where no such surface answers. That replacement is
built, and the drag handle above the dock is built with it.

Without haptics on the device, a notch holds briefly before it gives and marks
itself with a short click through the touch sounds this build already has.

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
