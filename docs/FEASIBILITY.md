# Shuffle Keyboard technical foundation

## Decision

The smallest reliable path from a touched key to arbitrary desktop software is:

1. Shuffle's QML touch target calls `QVirtualKeyboardInputEngine::virtualKeyClick`.
2. Qt Virtual Keyboard produces the committed text or key event.
3. Plasma Keyboard's input-method-v1 client forwards it to KWin.
4. KWin delivers it through the target application's supported text-input
   protocol, with its compositor key-event fallback for applications without
   a compatible text-input path.

This retains Qt Virtual Keyboard for locale, layout, and input-engine behavior,
and KWin for application compatibility and the active system keymap. Shuffle is
therefore a front end and interaction layer, not a new input engine.

## Alternatives evaluated

- **Qt Virtual Keyboard alone:** mature input engine, but its normal desktop
  integration is per Qt application and is not an arbitrary-application system
  input path.
- **Plasma Keyboard plus KWin:** selected. It is the Plasma-native privileged
  input-method path and already bridges Qt, GTK, browser, and fallback clients.
- **Fcitx5:** mature and appropriate for conventional multilingual IME work,
  but it does not supply the contracted Shuffle touch and precision surfaces.
  Making it the foundation would add another integration boundary without
  improving delivery for this Plasma-specific product.
- **Synthetic per-application input:** rejected. It is less reliable under
  Wayland and would duplicate compositor responsibilities.

Precision pointer events use the desktop's RemoteDesktop portal. The portal
owns user consent and device injection; Shuffle only recognizes gestures.

## Delivery evidence

All application tests ran in an isolated virtual KWin Wayland session, never in
the developer's active desktop. The stress payload was delivered at 1 ms key
intervals and compared byte-for-byte.

| Target | Result |
| --- | --- |
| Qt / KDE line edit | 1,080 characters exact |
| GTK 4 entry | 1,080 characters exact |
| Firefox, native Wayland | 1,080 characters exact |
| Chromium, native Wayland | 1,080 characters exact |
| Electron 42, native Wayland | 1,080 characters exact |
| Konsole | line plus Enter exact |

After integrating the Shuffle UI, a 1,032-character mixed-case, number, and
punctuation payload was repeated against Qt and GTK with no loss, duplication,
reordering, or mapping errors.

The compositor-keymap shortcut path was separately exercised with this stateful
sequence: type `abc`, Select All, Copy, Cut, Paste, Undo, Redo, then type
`DONE`. Qt, GTK, and Chromium each produced exactly `abcDONE`.

## Row geometry

The fixed pitch and the Q/A/Z stagger (`KEYBOARD-CONTRACT.md` § Layout) were
chosen by an on-device comparison against a conventional four-row iPad layout
built on this keyboard's exact delivery path. It found essentially no misses on
the fixed pitch. Sharing that path isolated the earlier miss pattern to row
geometry rather than to input delivery, and Shuffle adopted the same pitch and
stagger. The comparison keyboard has been removed: it settled one question, and
shipping a second virtual keyboard to answer it again is not worth carrying.

What was settled is the pitch and the steps between rows: the home row a
quarter unit right of the top row, the bottom row a further half.

Where the block sits was settled on 1 October 2026 by a typing test on the
device: two thumbs, the same kind of sentence on each layout in alternating
order, and every touch recorded against the key it was meant for. A 16-unit
block carrying a ThinkPad's punctuation right of the letters put the gap
between the hands well left of the card's centre. Moved to where the thumbs
landed, it still hit the wrong key on 6.4% of aimed touches against 2.6% on
the original twelve-and-a-half-unit footprint, and on 9% against 1% for the
right thumb: with marks right of the letters, the letters cannot sit where the
right thumb lands. The original footprint keeps both steps, puts the gap
between the hands at the card's centre, and carries the marks on flicks and
the symbols layer.

## Physical acceptance

Automated tests cannot establish finger comfort, pointer feel, portal-consent
ergonomics or real panel motion. [`PHYSICAL_ACCEPTANCE.md`](PHYSICAL_ACCEPTANCE.md)
is that pass, on the supported 10–13 inch device, before release.
