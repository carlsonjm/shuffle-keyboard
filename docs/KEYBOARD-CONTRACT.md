# Shuffle Keyboard

Shuffle Keyboard is the touch keyboard and precision pointer Shuffle 1.0
requires. On a supported 10–13 inch touch device it types into any application
and points at anything, with no physical keyboard or mouse. This document says
what it is. Every input it handles, and what each does, is
[`INPUT.md`](INPUT.md).

## What it owns

Shuffle owns the layout, height, precision surface, showing and hiding, and
presentation. It owns no input engine. A touched key goes to Qt Virtual
Keyboard, Plasma Keyboard's input-method client hands the result to KWin, and
KWin delivers it through the application's own text-input path. Qt and KWin own
locale, keymaps and application compatibility.
[`FEASIBILITY.md`](FEASIBILITY.md) records why this base was chosen.

The precision surface moves the pointer through the desktop's RemoteDesktop
portal, which owns consent and the pointer device. Plasma asks the person once
and remembers the answer.

## The card

The keyboard is a card: the Itasca `#141414` surface with a hairline border and
10 px rounded top corners. It keeps Kadunce's 10 px gutter at either side and
nowhere else. It sits flush with the screen's bottom edge and lies over the
window above, since a gutter there would only cost rows.

Its top strip carries the handle: 6 px thick, with 10 px clear above it and
10 px between it and the keys. The handle is nearly white at rest and white
under the finger. Where the Bottom Surface is installed it takes the place and
width of the dock's application row, so the bar pulled up from the dock is the
bar that holds the keys. Otherwise it is 160 px wide and centred. What it does
when touched is [`INPUT.md`](INPUT.md) § Handle.

Keys have hairline outlines, open spacing and floating Ghost White labels. A
key that is on (Shift, Caps, Ctrl, Alt, a symbol layer) fills. There are no
skeuomorphic keys, dense outlines or permanent toolbars.

## Layout

The key block is 12.5 units wide. Every character key is one unit, at one pitch
on every row. Q begins at 1.00 units, A at 1.25 and Z at 1.75. This geometry was
settled on the device ([`FEASIBILITY.md`](FEASIBILITY.md) § Row geometry) and is
re-opened with evidence, not with a preference.

| Row | Keys, with widths in units |
| --- | --- |
| 1 | `123` 1, Q to P, Backspace 1.5 |
| 2 | Tab 1.25, A to L, Enter 2.25 |
| 3 | Shift 1.75, Z to M, comma, period, slash 1.75 |
| 4 | Ctrl 1.5, Alt 1.5, Space 8, Tette Dot 1.5 |

Backspace, Enter, slash and the Tette Dot end on one right edge, and none of
them moves a letter. Enter fills the home row's gap and is muted Ghost White
with dark text. Comma, period and slash show their shifted characters, `<`, `>`
and `?`, above their own, so the commonest marks need no trip to `123`. Shift
carries both one-shot Shift and Caps. There is no Caps key, no permanent number
row and no arrow cluster.

The Tette Dot is a white dot: the protected resting brand mark, not a text
label. It stands for the bare Meta key as the person has bound it, read live
from KDE's global shortcuts rather than naming an applet.

The space bar is the widest key and carries the trackpad mark at its right end.
What each key does is [`INPUT.md`](INPUT.md) § Keys.

`123` swaps the letters for two symbol layers, and Shift moves between them.
The first holds the digits and common punctuation. The second holds the
remaining brackets and marks; Tab, Esc, Del, Home, End, Page Up and Page Down;
and the four arrows. Both keep the card's shape, with no overlap, clipping or
dead gaps.

## Height

Only key height changes. Key width is fixed, so the keys, the space bar and
both scrub columns keep their places at every height.

The card is 32% to 52% of the screen's height, in steps of one percent, and is
saved as that share. The default, 42%, gives square keys. That key sets the key
width, and the scrub columns take the width left either side. At 42% a browser
above the keys keeps room for its own minimum height.

The keys hold no screen space of their own. The Active card makes room for them
(§ Showing and hiding), so a shorter keyboard gives that card back height: the
person trades accuracy for screen rather than picking a key size.

## Scrub columns

The width either side of the keys carries a scrub column, a vertical control
that is a faint line until a finger arrives. The left column is the edit
history; the right is key height ([`INPUT.md`](INPUT.md) § Scrub columns).
Neither is on the top edge, which belongs to showing and hiding.

Touched, a column shows its notches with the current one lit, what it reads
above them (the undo or redo icon, or the height as a percentage), and its name
beneath. The height column's default notch is always bright. Each notch acts as
the finger passes it, so the result shows while the finger is still down and a
scrub can take itself back before it ends.

The device has no haptics, so a notch is felt two other ways: it holds a little
past halfway before it gives, as a detent does, and it clicks with the
keyboard's quiet tick. A system without Qt Multimedia loses the click and
nothing else.

## Precision surface

The trackpad mark at the space bar's right end latches the whole keyboard as a
trackpad; [`INPUT.md`](INPUT.md) § Precision surface is what each touch does.
While latched, the keys dim and do not type, and they stay up whatever the
pointer does. The mark stays live, and lit. The surface is the keyboard's
full footprint below the handle, scrub columns included. Until the portal has
granted pointer control, it says so in place of pointing.

The precision surface does not duplicate the system's Shuffle gestures, and
editing stays with the history column and modifier chords.

## Showing and hiding

The keys come up from the screen's bottom edge and go back into it: under the
finger when a pull brings them or the handle takes them, and on their own
otherwise. Keys going because typing ended, or because an application asked the
compositor to put them away, leave the same way before the window goes. Asked
for again on the way out, they come back from where they are.

They rise only once the dock has left and given up its room, so they never rise
into it.

Before each motion with a destination, and on a press of the handle, the keys
tell Kadunce where they will rest and when (`keyboardHeading`). The Active card
follows them, and its application is resized once, at rest, not every frame.
With no Kadunce nothing answers and nothing changes. A request for the keys made
on the person's behalf, from the handle or the precision surface, goes through
Kadunce when it is running, so Kadunce knows it was asked; otherwise it goes to
the compositor directly.

### The bottom of the screen

The region follows keys on screen, not requests for them. While keys are shown,
the Keyboard asks the Bottom Surface for the region, and the surface decides
what giving it up means. The region goes back once the keys have gone. Where no
Bottom Surface answers, Plasma's bottom panels autohide while the keys are up
and return to their previous hiding mode afterwards. `bottomsurfacecoordinator`
is this whole boundary; the surface's side of it is the Bottom Surface contract
in the `shuffle` repository.

### The handle above the dock

Where the Bottom Surface is installed, a handle sits directly on top of the dock
while the keys are down, as wide as the dock's application row and on the
dock's display. It is a surface of the Keyboard's own, because the Keyboard's
window is an input panel and the compositor unmaps it exactly when the handle is
needed.

While shown, the handle reserves its own 6 px, so windows stop above it. It
takes touches over the bar only, leaving the rest of that gap to whatever is
beneath. It goes while the keys are up, and before the bottom strip goes solid
black for a full-screen window. It keeps its reservation through the blackout,
so windows are not resized each time the strip darkens. On an ordinary Plasma
panel there is no handle.

A raise from the handle never takes the focus from a text box that is ready to
be typed into. Only a cold start, with nothing ready, borrows the focus with a
field nobody sees until the keys go; the focus then returns to where it was.

## Engineering constraints

- Build on the chosen foundation: a Shuffle front end over Qt Virtual Keyboard,
  Plasma Keyboard's input-method client and KWin's text-input delivery. Build no
  input engine unless mature system infrastructure cannot meet this contract.
- Verify Qt/KDE, GTK, browsers, Chromium/Electron and terminals.
- Treat as blockers: dropped characters, wrong keymaps, focus loss, meaningful
  latency, unreliable show and hide, or a keyboard that moves a card or resizes
  any window but the Active card making its room.
- Keep pointer, editing, height, keyboard and system gestures in explicit,
  non-overlapping ownership.
- Support lock and sign-in surfaces only where the system API permits safe
  integration.

## 1.0 boundaries

Shuffle 1.0 does not implement autocorrect, prediction, swipe typing,
dictation, custom dictionaries, AI writing, a multilingual IME or emoji
infrastructure. Mature system capability may be integrated where it does not
compromise input reliability.

## Acceptance

A supported touch device types quickly without loss or wrong mapping, changes
key height, enters and leaves the precision surface without focus loss, points
and edits reliably, and returns immediately to typing. A history scrub can be
taken back inside the gesture, and the notch hold reads as feedback rather than
as delay on the device itself. The pass is
[`PHYSICAL_ACCEPTANCE.md`](PHYSICAL_ACCEPTANCE.md).
