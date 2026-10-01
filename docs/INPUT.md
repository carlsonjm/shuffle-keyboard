# Shuffle Keyboard input

Every input Shuffle Keyboard handles, destination by destination, and what you
see it do. Other documents cite this list rather than describe an input
themselves.

| Task | Touch | Keyboard |
| --- | --- | --- |
| Shuffle Keyboard | Tap a text field | — |
| Precision surface | Tap the trackpad mark at the space bar's right end | — |

## Shuffle Keyboard

### Text fields

| Input | What happens |
| --- | --- |
| Tap a text field | The keys rise from the screen's bottom edge. |
| Leave the text field, or the application puts the keys away | The keys slide down and away. Asked for again on the way out, they come back from where they are. |

### Tray entry

The keys' entry in the system tray, called Keyboard, which Temperance can also
show as a pill in Control Center.

| Input | What happens |
| --- | --- |
| Tap or click the entry, with the keys down | The keys rise for the window in use; a text box that was ready keeps the focus. Straight after signing in, with nothing ready, they still come up, and typing goes nowhere until a text box is tapped. |
| Tap or click the entry, with the keys up | The keys slide down and away, as Hide puts them. |

### Hide key

| Input | What happens |
| --- | --- |
| Tap Hide | The keys slide down and away. Hide stays live while the trackpad is latched, and ends the latch. |
| Activate Hide with a screen reader | "Put the keyboard away" puts the keys away. |

### Keys

| Input | What happens |
| --- | --- |
| Tap a letter, digit or mark | Types it as your finger lifts, or as soon as another finger lands, whichever comes first. Overlapping thumbs keep their order. |
| Slide off a key before lifting | Nothing is typed, unless the slide is a flick down (§ Flicks). |
| Tap the same key twice quickly | Types it twice. |
| Hold a, e, i, o, u, n, c, s or y | Its accents appear above it. Slide to one and lift to type it; lift off them to type nothing. |
| Hold any other key but Delete | Types it once, as your finger lifts. There is no repeat. |
| Tap Shift | The next key is shifted: a capital letter, or the ANSI shift of comma, period or slash, `<` `>` `?`. Shift then lets go; tapping it again first cancels it. |
| Double-tap Shift | Caps Lock: letters stay capitals until Shift is tapped again. |
| Tap Shift with Caps Lock on | Caps Lock and Shift both let go. |
| Tap `123` | The symbols layer replaces the letters until `ABC` is tapped. A pending Shift, Ctrl or Alt lets go. |
| Tap `ABC` | The letters return. |
| Tap Emoji, on the symbols layer | The emoji panel replaces the three upper rows. The bottom row's first key reads `ABC`; tap it to return to the letters. |
| Tap an emoji | Types it. The panel stays. |
| Swipe across the emoji panel, or tap a category | The panel scrolls sideways. |
| Tap Delete | Deletes the character before the cursor, on every layer. |
| Hold Delete still | Keeps deleting until you lift your finger, by characters and then by words. |
| Tap Go | Enter: a new line, or whatever Enter does in that application. |
| Tap Esc, on the symbols layer | Esc. |
| Tap Tab | Tab. |
| Tap the space bar | A space. Its right end is the trackpad mark (§ Precision surface). |
| Tap Ctrl or Alt | It lights and applies to the next key, then lets go. Tapping it again first cancels it. |
| Tap Ctrl, then C, X, V or Z | Copy, cut, paste or undo, as the application defines them. Any other key makes its own chord, and Shift and Alt combine the same way, so Ctrl, Shift, C copies in a terminal and Ctrl, Shift, Z redoes. |
| Tap the Tette Dot | Whatever the bare Meta key opens in Plasma. |

### Flicks

A key with a small grey character above its own types that character when
flicked down. As the finger moves down, the grey character grows into the
key's centre, and the flick types once it has fully grown, nearly half a key's
height down. A move mostly sideways is not a flick.

| Input | What happens |
| --- | --- |
| Flick Q to P down | 1 to 0. |
| Flick A to L down | `!` `@` `#` `$` `%` `^` `&` `*` `(`. |
| Flick Z to M down | `)` `~` `` ` `` `€` `£` `§` `…`. |
| Flick comma, period or slash down | Its ANSI shift: `<` `>` `?`. |
| Flick a mark on the symbols layer down | Its ANSI shift: `_` `+` `{` `}` `\|` `:` `"` `~` `?`. |
| Move down less than a full flick, then lift | The key's own character, as a tap, even if the finger has left the key's bottom edge. |

A flick types its character as it is, whatever Shift says, and a pending Shift
stays pending.

### Caret trackpad

| Input | What happens |
| --- | --- |
| Hold the space bar still for a third of a second | The keys go quiet, their labels nearly gone, and the whole key block moves the text cursor. Nothing is typed. |
| Slide along the space bar | The same, at once, with no wait. |
| Move sideways | Left or Right, one character per step. |
| Move up or down | Up or Down, one line per larger step. |
| Lift | The cursor stays where it is and the keys return. |
| Touch the trackpad mark | Not the caret trackpad: the mark latches the precision surface. |

Every step is an arrow key, so it moves the cursor wherever arrow keys do,
terminals included.

### Delete

| Input | What happens |
| --- | --- |
| Drag left from Delete | The characters before the cursor are marked, one more for each step the finger moves. |
| Slide back toward Delete | Marks come off one step at a time. Back at the key, nothing is marked. |
| Lift after a drag | The marked characters are deleted. |
| Flick left from Delete | Deletes the word before the cursor, as Ctrl, Backspace does in that application. |
| Drag in an application that does not share its text, such as a terminal | The count shows on the key in place of a mark, and lifting sends that many Backspaces. |

## Precision surface

| Input | What happens |
| --- | --- |
| Tap the trackpad mark at the space bar's right end | The keys dim and the whole keyboard becomes a trackpad. The keys stay up, whatever the pointer does, until the mark is tapped again or they are put away. |
| Tap the trackpad mark while latched | Back to typing. |
| Tap Hide, or the tray entry, while latched | The latch ends and the keys slide away, and they stay away. The next text field brings them back for typing. |
| Latch for the first time | Plasma asks once whether the Keyboard may control the pointer. Until it is allowed, the surface says so. |
| Move one finger | Moves the pointer. |
| Tap one finger | Clicks. |
| Hold one finger still, then move | Presses and drags, to select text or move an item. Lifting lets go. |
| Move two fingers | Scrolls. |
| Tap two fingers | Right-clicks. |
