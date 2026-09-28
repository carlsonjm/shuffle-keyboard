# Shuffle Keyboard input

This is every input Shuffle Keyboard handles, and what the person sees it do.
Each section is one surface and each row one input; a row whose input starts
with `Planned:` is agreed but not built. Other documents cite this list rather
than describe an input themselves.

## Text fields

| Input | What happens |
| --- | --- |
| Tap a text field | The keys rise from the screen's bottom edge. |
| Leave the text field, or the application puts the keys away | The keys slide down and away. Asked for again on the way out, they come back from where they are. |

## Handle

| Input | What happens |
| --- | --- |
| Tap the handle above the dock | The keys come up. A text box that was ready keeps the focus; with none ready, typing goes nowhere until one is tapped. The handle is there only while the keys are down and the Bottom Surface is installed. |
| Pull up on the handle above the dock, or from the dock's application row | The keys come up under the finger. Let go past a quarter of the way, or with a flick upward, and they open; otherwise they go back down. The focus is kept as a tap keeps it. |
| Tap beside the handle above the dock | Whatever is beneath takes the tap, and the keys stay down. |
| Tap the handle on the keys | The keys slide down and away. |
| Drag the handle on the keys down | The keys follow the finger. Let go past a quarter of the way, or with a flick downward, and they go; otherwise they spring back. |
| Activate a handle with a screen reader | "Show the keyboard" brings the keys up; "Put the keyboard away" puts them away. |

## Keys

| Input | What happens |
| --- | --- |
| Tap a letter, digit or mark | Types it as the finger lifts. |
| Slide off a key before lifting | Nothing is typed. |
| Tap the same key twice quickly | Types it twice. |
| Hold any key but Backspace | Types it once, as the finger lifts. There is no repeat and no accent popup. |
| Tap Shift | The next key is shifted: a capital letter, or `<`, `>` or `?` from comma, period or slash. Shift then lets go; tapping it again first cancels it. |
| Double-tap Shift | Caps Lock: letters stay capitals until Shift is tapped again. |
| Tap Shift with Caps Lock on | Caps Lock and Shift both let go. |
| Tap `123` | The digits and common marks replace the letters until `ABC` is tapped. A pending Shift, Ctrl or Alt lets go. |
| Tap Shift on the symbols layer | The second symbols layer, for one key: the remaining brackets and marks, Tab, Esc, Del, Home, End, Page Up, Page Down and the arrows. Tapping Shift again returns to the first. |
| Tap `ABC` | The letters return. |
| Tap Backspace | Deletes one character. |
| Hold Backspace | Keeps deleting until the finger lifts. |
| Tap Enter | Enter: a new line, or whatever Enter does in that application. |
| Tap Tab | Tab. |
| Tap the space bar | A space. The space bar only types; its right end is the trackpad mark. |
| Tap Ctrl or Alt | It lights and applies to the next key, then lets go. Tapping it again first cancels it. |
| Tap Ctrl, then C, X or V | Copy, cut or paste, as the application defines them. Any other key makes its own chord, and Shift and Alt combine the same way, so Ctrl, Shift, C copies in a terminal. |
| Tap the Tette Dot | Whatever the bare Meta key opens in Plasma. |

## Scrub columns

| Input | What happens |
| --- | --- |
| Touch either column | It shows its notches, what it reads and its name. At rest it is a faint line. |
| Drag down the left column | Undo, one step per notch, each with a click. The icon above shows undo. |
| Drag up the left column | Redo, one step per notch, each with a click. The icon above shows redo. |
| Slide back along the left column before lifting | Each notch passed back reverses one step, so a scrub can take itself back. |
| Drag the left column in a terminal | Nothing happens. |
| Drag up the right column | Taller keys, one percent of the screen's height per notch, up to 52%. The keys change as each notch passes, and the reading shows the height. |
| Drag down the right column | Shorter keys, down to 32%. |
| Lift from the right column | The height is kept for next time. The default, 42%, is the bright notch. |

## Precision surface

| Input | What happens |
| --- | --- |
| Tap the trackpad mark at the space bar's right end | The keys dim and the whole keyboard becomes a trackpad. The keys stay up until the mark is tapped again. |
| Tap the trackpad mark while latched | Back to typing. |
| Latch for the first time | Plasma asks once whether the Keyboard may control the pointer. Until it is allowed, the surface says so. |
| Move one finger | Moves the pointer. |
| Tap one finger | Clicks. |
| Hold one finger still, then move | Presses and drags, to select text or move an item. Lifting lets go. |
| Move two fingers | Scrolls. |
| Tap two fingers | Right-clicks. |
