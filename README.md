# Shuffle Keyboard

Shuffle Keyboard is the touch keyboard and precision pointer for Shuffle on KDE
Plasma 6: four large rows centred on the card, flick keys for the digits and
punctuation, a caret trackpad on the space bar and a pointer trackpad latch,
drawn as a card over the window above.

## Controls

| Task | Touch | Keyboard |
| --- | --- | --- |
| Shuffle Keyboard | Tap a text field | — |
| Precision surface | Tap the trackpad mark at the space bar's right end | — |

Keyboard in the system tray, or in Control Center, brings the keys up at any
time. Tap Hide, at the bottom right, to put them away.
Every input is in [`docs/INPUT.md`](docs/INPUT.md).

- What it is: [`docs/KEYBOARD-CONTRACT.md`](docs/KEYBOARD-CONTRACT.md)
- Why this base: [`docs/FEASIBILITY.md`](docs/FEASIBILITY.md)
- The by-hand pass on a touch device:
  [`docs/PHYSICAL_ACCEPTANCE.md`](docs/PHYSICAL_ACCEPTANCE.md)

## Built on KDE's Plasma Keyboard

It is a fork of KDE's Plasma Keyboard 6.7.5 and keeps its input delivery, Qt
Virtual Keyboard and KWin's input-method path, with no input engine of its own.
It carries KDE's licence.

## Build

On an Arch-family Plasma 6 development system:

```sh
cmake -S . -B build -G Ninja -DBUILD_TESTING=OFF -DCMAKE_BUILD_TYPE=RelWithDebInfo
cmake --build build
```

The executable is `build/bin/shuffle-keyboard`. `./verify.sh` formats, checks
licence headers, builds and runs the tests.

## Install

Do not replace the active desktop keyboard while developing. Install into a
staging prefix first:

```sh
cmake --install build --prefix "$PWD/stage"
```

For the device, `./install-keyboard.sh` builds and replaces the copy in your own
prefix; the Keyboard in use changes at the next sign-in. Enabling it is
[`docs/PHYSICAL_ACCEPTANCE.md`](docs/PHYSICAL_ACCEPTANCE.md) § Install and
enable. KWin must start the binary as its virtual keyboard: run as a normal
application it exits, unless `SHUFFLE_PREVIEW_MODE=1` is set for an isolated
test.
