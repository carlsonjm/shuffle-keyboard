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

## Workspace evidence

On a 1280×800 virtual output, a maximized test client reported:

- 450 px client height with the default 320 px keyboard;
- 290 px after changing the keyboard to 480 px;
- 770 px immediately after keyboard dismissal.

The chosen 480 px value was present in the isolated `plasmakeyboardrc` after
restart. With a normal 46 px Plasma bottom panel, the panel changed from `none`
to `autohide` while the keyboard was visible and returned to `none` afterward.
The client returned to the panel-reserved 724 px height after dismissal.

## Remaining physical acceptance

The first on-device geometry comparison found essentially no misses on the
four-row fixed-pitch iPad baseline. Because it shares the exact delivery path
with Shuffle, this isolates the earlier miss pattern to row geometry. The
Shuffle candidate now uses the same Q/A/Z pitch and stagger and defaults to the
full width proven by that comparison.

Automated tests cannot establish finger comfort, accidental Cut frequency,
pointer feel, portal-consent ergonomics, or real panel animation quality. Those
items require the contracted physical touch acceptance pass on the supported
10–13 inch device before release.
