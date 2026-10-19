# Shuffle Keyboard

Shuffle Keyboard is the touch keyboard and precision pointer Shuffle 1.0
requires. On a supported 10–13 inch touch device it types into any application
and points at anything, with no physical keyboard or mouse. This document
describes the Keyboard; [`INPUT.md`](INPUT.md) lists every input it handles and
what each does.

## What it owns

Shuffle decides the layout, height, precision surface, showing and hiding, and
presentation. It has no input engine of its own. A touched key goes to Qt
Virtual Keyboard, Plasma Keyboard's input-method client hands the result to
KWin, and KWin delivers it through the application's own text-input path. Qt
and KWin handle locale, keymaps and application compatibility.
[`FEASIBILITY.md`](FEASIBILITY.md) records why this base was chosen.

The precision surface moves the pointer as the Keyboard itself, through KWin's
fake-input protocol. KWin offers that protocol only to the program its desktop
entry names in full, and the Keyboard's entry asks for it. The pointer then
moves with no prompt and no remote-control notice, just as the keys type. Where
KWin does not offer it, the surface falls back to the desktop's RemoteDesktop
portal. Before its first portal call the Keyboard names itself to the portal as
`org.shuffle.Keyboard`. Plasma then asks once, by that name, and shows its
remote-control notice only while the surface is latched.

## The card

The keyboard is a card: the Itasca `#141414` surface with a hairline border and
10 px rounded top corners, the suite's paper tier, as are its keys and the
precision surface. It keeps Kadunce's 10 px gutter at the left and
right only. It sits flush with the screen's bottom edge and lies over the
window above, since a gutter there would only cost rows.

The card is monochrome: Itasca's surface, Ghost White `#F8F8FF` and grey
hairlines, with no accent colour. Keys have hairline outlines, open spacing
and floating Ghost White labels. A key that is on (Shift, Caps, Ctrl, Alt)
fills. There are no skeuomorphic keys, dense outlines or permanent toolbars.

The card follows the Plasma style, as the desktop's panels do, not the colours
programs use. It uses the dark colours above unless the style is light and
its text reads on it (WCAG AA, 4.5:1). Then the surface is the style's
window colour, the labels its text colour, and every hairline, fill and the
trackpad are mixed from those two, so a label and what it sits on always come
from the same style. The accents' pop-up stands on the style's view colour where
the labels read on it, and on the card's own colour where they do not. A style
that keeps its panels dark under light programs keeps the keys dark. At the
sign-in screen the keys are always dark.

Its top strip, 10 px above a 6 px band and 10 px below it, is kept clear for
word predictions, which come after 1.0 (§ 1.0 boundaries). The strip stays
empty and ignores touches. There is no handle; the Hide key puts the keys
away.

## Layout

The key block is the original footprint: twelve and a half units wide and
centred in the card, with the card's surface clear at either side, where the
hands hold the device. Every character key is one unit, at one pitch on every
row, except the slash, which fills the bottom row's end. Q begins at 1 unit, A
at 1.25 and Z at 1.75: the home row a quarter unit right of the top row and the
bottom row a further half. This puts the gap between the hands, between T and
Y, at the card's centre ([`FEASIBILITY.md`](FEASIBILITY.md) § Row
geometry). Changing the footprint, pitch or stagger takes new evidence, not a
preference.

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

The Tette Dot is a white dot, the protected resting brand mark, with no text
label. It sits right of the space bar and stands for whatever the person has
bound to the bare Meta key, read live from KDE's global shortcuts rather than
tied to a named applet.

The space bar is the widest key and carries the trackpad mark at its right end.
[`INPUT.md`](INPUT.md) § Keys says what each key does.

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

The card is 44% of the screen's height wherever that gives keys at least 16 mm
tall, and the person cannot change it. Shuffle's window roll gives the Active
card its room (§ Showing and hiding), so shorter keys would win back no screen.
At 45% the room left above the keys was shorter than a browser makes itself,
so a screen that already reaches 16 mm keeps 44%: on a 13-inch tablet the keys
are about 17 mm.

Keys are never under 16 mm where the screen is wide enough to hold them
(product owner, 14 and 18 October 2026). Where 44% would give smaller keys, as
on a 10-inch tablet, the card grows until they reach 16 mm, about half a Surface
Go's height. It never grows past the size at which twelve and a half square keys
still fit inside the card's gutters, so it takes no height the keys cannot use.
Width sets the ceiling: 16 mm on a Surface Go, about 15.6 mm on a 10.1-inch
16:10 tablet, which takes 53% of its height to get there, and less on a tablet
held upright. A screen that does not report its size keeps 44%. `src/qml/KeySizing.qml` holds
the rule and `autotests/qml/tst_keysizing.qml` proves it.

The four rows set the key height, and a character key is as wide as it is tall.
Where twelve and a half square units would not fit inside the card's gutters,
every key narrows together until they do, and the pitch stays one on every row.

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
  Shift with the caret trackpad selects. Double-tapped, Ctrl or Alt stays on
  until tapped again or the keys go away. Keys reach the application being
  typed into; the desktop's own shortcuts, such as Alt+Tab, do not hear them.

There is no history scrub. [`INPUT.md`](INPUT.md) § Caret trackpad and
§ Delete give each input.

## Precision surface

The trackpad mark at the space bar's right end latches the whole keyboard as a
trackpad; [`INPUT.md`](INPUT.md) § Precision surface lists what each touch
does. While latched, the keys dim and do not type, and they stay up whatever the
pointer does. The mark stays live and lit, and Hide stays live and undimmed.
Putting the keys away, with Hide or the tray entry, ends the latch, and they
stay away until they are next asked for. The surface is the keyboard's
full footprint below the top strip. Through the portal, latching asks for
pointer control and ending the latch gives it back. Until the portal grants
pointer control, the surface says it has none instead of pointing. If the
portal ends that control, because it restarted or the permission was withdrawn,
the surface says so again and the next touch asks afresh.

The mark and the caret trackpad share the space bar and do not overlap: a touch
that begins on the mark latches the pointer, and a touch anywhere else on the
space bar types a space or moves the text cursor. The precision surface leaves
the system's Shuffle gestures to the system, and editing to the keys
(§ Editing).

## Showing and hiding

The keys come up when a text field is tapped, and when their entry in the system
tray is tapped with them down; tapped with them up, it puts them away. The entry
implements the tray protocol directly, since this process loads no widget
toolkit. It has no menu.

A raise from the tray entry leaves the focus on a text box that is ready to be
typed into. Only a cold start needs more: straight after signing in, before any
text field has been touched, the compositor's request alone shows nothing. The
Keyboard then borrows the focus with an invisible field until the keys go, and
the focus returns to where it was.

They rise from the screen's bottom edge on their own and go back into it,
whether the Hide key, the tray entry, the end of typing or the application put
them away. Keys going because typing ended, or because an application asked the
compositor to put them away, leave before the window goes. They wait 150 ms
before setting off, because a field that lets go is often handing over to the
next one, as a browser's boxes do; then nothing moves. Asked for again on the
way out, they come back from where they are.

They rise only once the dock has left and given up its room.

Their travel follows Plasma's animation speed, so they keep pace with the dock
and the cards. At the fastest setting they arrive and leave at once.

Before each motion with a destination, and on a press of the Hide key, the keys
tell Kadunce where they will rest and when (`keyboardHeading` on
`co.goodinput.Kadunce`). The Active card follows them, and its application is
resized once, at rest, not every frame.
Without Kadunce, nothing answers and nothing changes. A request for the keys
made on the person's behalf, from the tray entry or the precision surface, goes
through Kadunce when it is running, so Kadunce knows it was asked; otherwise it
goes to the compositor directly.

KWin starts and stops the Keyboard, and the Keyboard exits with the compositor
that started it. When the session ends it hands the bottom of the screen back,
waiting no more than a second for an answer, and is gone within three seconds,
so it never delays a sign-out. If KWin crashes, the Keyboard exits with it
rather than reconnecting. The KWin that comes back starts its own Keyboard, so
only one ever holds the tray entry and the bottom of the screen.

### The bottom of the screen

The region follows keys on screen, not requests for them. While keys are shown,
the Keyboard asks the Bottom Surface for the region, and the surface decides
what giving it up means. The region goes back once the keys have gone. A
surface that refuses, or is slow to answer, still holds the region, and the
Keyboard leaves every panel alone. Only where no Bottom Surface is on the bus at
all do Plasma's bottom panels autohide while the keys are up and return to their
previous hiding mode afterwards. Those modes are kept on disk before any panel
changes, so a Keyboard that crashed or was killed with the keys up puts them
back the next time it starts. None of this waits for the surface or the shell to
answer, so a busy desktop never holds up the keys. `bottomsurfacecoordinator`
implements this whole boundary. It finds the surface on the session bus as
`co.goodinput.BottomSurface`, asks for the region with `yieldRegion`, gives it
back with `releaseRegion`, and follows `dockExtentChanged` so the keys rise only
once the band has given up its room. The surface's side is the Bottom Surface
contract in the `shuffle` repository. The Keyboard puts nothing of its own on
the surface's band, so windows stop at the band.

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
