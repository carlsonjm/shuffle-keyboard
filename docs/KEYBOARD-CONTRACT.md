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
8 px rounded top corners, the suite's paper tier, as are its keys and the
precision surface. It keeps Kadunce's 10 px gutter at either side and
nowhere else. It sits flush with the screen's bottom edge and lies over the
window above, since a gutter there would only cost rows.

The card is monochrome: Itasca's surface, Ghost White `#F8F8FF` and grey
hairlines, with no accent colour. Keys have hairline outlines, open spacing
and floating Ghost White labels. A key that is on (Shift, Caps, Ctrl, Alt)
fills. There are no skeuomorphic keys, dense outlines or permanent toolbars.

Its top strip, 10 px above a 6 px band and 10 px below it, is kept clear for
word predictions, which come after 1.0 (§ 1.0 boundaries). Nothing is drawn
there and a touch there does nothing. There is no handle: the Hide key puts the
keys away.

## Layout

The key block is the original footprint: twelve and a half units wide and
centred in the card, with the card's surface clear at either side, where the
hands hold the device. Every character key is one unit, at one pitch on every
row, except the slash, which fills the bottom row's end. Q begins at 1 unit, A
at 1.25 and Z at 1.75: the home row a quarter unit right of the top row and the
bottom row a further half. So placed, the gap between the hands, between T and
Y, sits at the card's centre ([`FEASIBILITY.md`](FEASIBILITY.md) § Row
geometry). The footprint, pitch and stagger are re-opened with evidence, not
with a preference.

| Row | Keys, with widths in units |
| --- | --- |
| 1 | `123` 1, Q to P, Delete 1.5 |
| 2 | Tab 1.25, A to L, Go 2.25 |
| 3 | Shift 1.75, Z to M, comma, period, slash 1.75 |
| 4 | Ctrl 1.5, Alt 1.5, Space 6.5, Tette Dot 1.5, Hide 1.5 |

Delete, Go, the slash and Hide end on one right edge, and none of them moves a
letter. There is no Caps key, no right Shift, no arrow key and no permanent
number row.

Labels:

- **Delete** is a left arrow with a stem.
- **Go** is Enter. It fills the home row's gap and is muted Ghost White with
  dark text.
- **Shift** carries one-shot Shift and Caps.
- **Hide** is a keyboard over a downward chevron.

Every letter, the comma, the period and the slash show a second character
small and grey above their own, and a flick down types it
([`INPUT.md`](INPUT.md) § Flicks). The top row carries the digits, the home row
`!` to `(`, and the bottom row `)` `~` `` ` `` `€` `£` `§` `…`, then the
comma, period and slash their ANSI shifts `<` `>` `?`, which Shift also types.
`123` carries Esc the same way, small and grey above it, since it sits where a
keyboard puts Esc.

The Tette Dot is a white dot: the protected resting brand mark, not a text
label. It sits right of the space bar and stands for the bare Meta key as the
person has bound it, read live from KDE's global shortcuts rather than naming
an applet.

The space bar is the widest key and carries the trackpad mark at its right end.
What each key does is [`INPUT.md`](INPUT.md) § Keys.

`123` swaps the letters for one symbols layer, and reads `ABC` while it shows.
Its top row holds the digits. Its home row holds Esc in Tab's place, then the
marks the letters leave out, `-` `=` `[` `]` `\` `;` `'` `` ` `` `/`, each with
its ANSI shift small and grey above it for a flick down: `_` `+` `{` `}` `|`
`:` `"` `~` `?`. Its bottom row holds Emoji in Shift's place, then `!` to `)`.
Delete is Backspace on every layer. The layer keeps the card's shape, with no
overlap, clipping or dead gaps.

Emoji swaps the three upper rows for an emoji panel, a sideways-scrolling grid
under a row of categories. The bottom row stays, its first key reading `ABC`
to return to the letters.

## Height

The card is 44% of the screen's height, always, set by J on 1 October 2026 for
room to test. The person does not change it: Shuffle's window roll gives the
Active card its room (§ Showing and hiding), so there is no screen to win back
with shorter keys. At 45% the room left above the keys was shorter than a
browser makes itself (J, 26 September).

At 44% the four rows set the key height, and a character key is as wide as it
is tall. Where twelve and a half square units would not fit inside the card's
gutters, every key narrows together until they do, and the pitch stays one on
every row.

## Editing

Editing is on the keys, not beside them:

- **The caret trackpad.** Holding the space bar, or sliding along it, turns the
  key block into a surface that moves the text cursor with arrow keys, so it
  works wherever arrow keys do, terminals included.
- **The delete scrub.** A drag left from Delete marks characters to delete; a
  flick left deletes a word.
- **Modifier chords**: Ctrl, Z undoes and Ctrl, Shift, Z redoes, as the
  application defines them. A pending Shift, Ctrl or Alt reaches the
  application with every key that types no letter, Go, Tab, the space bar,
  Esc, Delete and each caret step, so keybinds such as Shift+Enter work and
  Shift with the caret trackpad selects.

There is no history scrub. What each does is [`INPUT.md`](INPUT.md) § Caret
trackpad and § Delete.

## Precision surface

The trackpad mark at the space bar's right end latches the whole keyboard as a
trackpad; [`INPUT.md`](INPUT.md) § Precision surface is what each touch does.
While latched, the keys dim and do not type, and they stay up whatever the
pointer does. The mark stays live, and lit, and so does Hide, undimmed.
Putting the keys away, with Hide or the tray entry, ends the latch, and they
stay away until they are next asked for. The surface is the keyboard's
full footprint below the top strip. Until the portal has granted pointer
control, it says so in place of pointing.

The mark and the caret trackpad share the space bar and do not overlap: a touch
that begins on the mark latches the pointer, and a touch anywhere else on the
space bar types a space or moves the text cursor. The precision surface does not
duplicate the system's Shuffle gestures, and editing stays with the keys
(§ Editing).

## Showing and hiding

The keys come up when a text field is tapped, and when their entry in the system
tray is tapped with them down; tapped with them up, it puts them away. The entry
speaks the tray protocol itself, since this process loads no widget toolkit, and
has no menu.

A raise from the tray entry never takes the focus from a text box that is ready
to be typed into. Only a cold start needs more: straight after signing in,
before any text field has been touched, the compositor's ask alone shows
nothing. Then the Keyboard borrows the focus with a field nobody sees until the
keys go, and the focus returns to where it was.

They rise from the screen's bottom edge on their own and go back into it,
whether the Hide key, the tray entry, the end of typing or the application put
them away. Keys going because
typing ended, or because an application asked the compositor to put them away,
leave before the window goes. Asked for again on the
way out, they come back from where they are.

They rise only once the dock has left and given up its room, so they never rise
into it.

Before each motion with a destination, and on a press of the Hide key, the keys
tell Kadunce where they will rest and when (`keyboardHeading`). The Active card
follows them, and its application is resized once, at rest, not every frame.
With no Kadunce nothing answers and nothing changes. A request for the keys made
on the person's behalf, from the tray entry or the precision surface, goes
through Kadunce when it is running, so Kadunce knows it was asked; otherwise it
goes to the compositor directly.

### The bottom of the screen

The region follows keys on screen, not requests for them. While keys are shown,
the Keyboard asks the Bottom Surface for the region, and the surface decides
what giving it up means. The region goes back once the keys have gone. Where no
Bottom Surface answers, Plasma's bottom panels autohide while the keys are up
and return to their previous hiding mode afterwards. `bottomsurfacecoordinator`
is this whole boundary; the surface's side of it is the Bottom Surface contract
in the `shuffle` repository. The Keyboard puts nothing of its own on the
surface's band, so windows stop at the band.

## Engineering constraints

- Build on the chosen foundation: a Shuffle front end over Qt Virtual Keyboard,
  Plasma Keyboard's input-method client and KWin's text-input delivery. Build no
  input engine unless mature system infrastructure cannot meet this contract.
- Verify Qt/KDE, GTK, browsers, Chromium/Electron and terminals.
- Treat as blockers: dropped characters, wrong keymaps, focus loss, meaningful
  latency, unreliable show and hide, or a keyboard that moves a card or resizes
  any window but the Active card making its room.
- Keep pointer, editing, keyboard and system gestures in explicit,
  non-overlapping ownership.
- Support lock and sign-in surfaces only where the system API permits safe
  integration.

## 1.0 boundaries

Shuffle 1.0 does not implement autocorrect, prediction, swipe typing,
dictation, custom dictionaries, AI writing, a multilingual IME or emoji
infrastructure. The emoji panel only commits the characters it shows; it has no
search, no skin tones beyond what each character carries, and no font of its
own. Mature system capability may be integrated where it does not compromise
input reliability.

The layout leaves room for what comes after 1.0. Predictions take the card's
top strip. Dictation takes the Emoji key's place, and the emoji panel moves
behind it.

## Acceptance

A supported touch device types quickly without loss or wrong mapping, with
two thumbs overlapping. It moves the text cursor from the space bar and deletes
by scrub, enters and leaves the precision surface without focus loss, points
and edits reliably, and returns immediately to typing. The pass is
[`PHYSICAL_ACCEPTANCE.md`](PHYSICAL_ACCEPTANCE.md).
