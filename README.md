# Shuffle Keyboard

Shuffle Keyboard is the touch keyboard and precision pointer for Shuffle on KDE
Plasma 6: four large rows, a history and a height scrub column either side, and
a trackpad latch, drawn as a card over the window above. It is a fork of KDE's
Plasma Keyboard 6.7.5 and keeps its input delivery, Qt Virtual Keyboard and
KWin's input-method path, with no input engine of its own.

- What it is: [`docs/KEYBOARD-CONTRACT.md`](docs/KEYBOARD-CONTRACT.md)
- Every input and what it does: [`docs/INPUT.md`](docs/INPUT.md)
- Why this base: [`docs/FEASIBILITY.md`](docs/FEASIBILITY.md)
- The by-hand pass on a touch device:
  [`docs/PHYSICAL_ACCEPTANCE.md`](docs/PHYSICAL_ACCEPTANCE.md)

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
