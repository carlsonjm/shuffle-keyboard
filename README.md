<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="assets/readme/banner-dark.png">
    <img src="assets/readme/banner-light.png" alt="Shuffle Keyboard: big keys for your fingers, and a trackpad for the moments that need precision" width="100%">
  </picture>
</p>

Shuffle Keyboard is a touch keyboard and precision pointer for KDE Plasma 6 on
Wayland: four large rows centred on a card at the bottom of the screen, flick
keys for the digits and punctuation, a caret trackpad on the space bar, and a
latch that turns the whole keyboard into a pointer trackpad. It runs on any
Plasma 6 desktop. The Shuffle desktop bundles it and adds a dock that steps
aside for it.



https://github.com/user-attachments/assets/3f88c114-e4bd-4b3a-9a83-722ffbda922b



## Controls

| Task | Touch | Keyboard |
| --- | --- | --- |
| Shuffle Keyboard | Tap a text field | — |
| Precision surface | Tap the trackpad mark at the space bar's right end | — |

The Keyboard entry in the system tray (or, on Shuffle, in Control Center)
brings the keys up at any time. Tap Hide, at the bottom right, to put them away.
Every input is in [`docs/INPUT.md`](docs/INPUT.md).

- What it is: [`docs/KEYBOARD-CONTRACT.md`](docs/KEYBOARD-CONTRACT.md)
- Why it is built this way: [`docs/FEASIBILITY.md`](docs/FEASIBILITY.md)
- The by-hand pass on a touch device:
  [`docs/PHYSICAL_ACCEPTANCE.md`](docs/PHYSICAL_ACCEPTANCE.md)

## Built on KDE's Plasma Keyboard

It is a fork of KDE's Plasma Keyboard 6.7.5. It keeps Plasma Keyboard's input
delivery, Qt Virtual Keyboard and KWin's input-method path, and adds no input
engine of its own. It carries KDE's licence. The project's own names and marks
are covered separately, in [`TRADEMARKS.md`](TRADEMARKS.md).

## Install

These steps are for Arch Linux or CachyOS running KDE Plasma 6.7 or newer in a
Wayland session, the default on both. The Keyboard is built on your computer
from this page's code, so you type a few commands into **Konsole**, Plasma's
terminal. Open it from the application launcher. It installs in your own home
folder, needs no password, and sits beside Plasma's own keyboard without
replacing it.

### 1. What you need

Check your Plasma version. It must say 6.7 or higher:

```bash
plasmashell --version
```

Bring the computer up to date. If you just did this for another part of the
suite, skip it:

```bash
sudo pacman -Syu
```

Restart the computer only if that update installed a new `kwin`,
`plasma-workspace` or kernel (`linux`, or `linux-cachyos` on CachyOS): the Keyboard is built against what is
installed, so that has to be what is running.

Then install what the build needs. Type your password when asked, and answer
`Y`:

```bash
sudo pacman -S --needed base-devel git cmake ninja pkgconf extra-cmake-modules qt6-base qt6-declarative qt6-virtualkeyboard qt6-wayland kcoreaddons ki18n kcmutils kconfig kcrash libplasma layer-shell-qt libxkbcommon wayland wayland-protocols plasma-wayland-protocols
```

If pacman says a package **is up to date -- skipping**, or **there is nothing
to do**, that is normal: it is already installed.

### 2. Download

This puts the code in a folder called `shuffle-keyboard` in your home folder.
Use `git` rather than GitHub's Download ZIP, so a later update is one command:

```bash
cd ~
git clone https://github.com/carlsonjm/shuffle-keyboard.git
cd shuffle-keyboard
```

### 3. Install

```bash
./install-keyboard.sh
```

It counts six steps, `[1/6]` to `[6/6]`. At step
6 it says **no copy under /usr/local; nothing to bring level**; that step is
for Shuffle's sign-in screen and has nothing to do on a plain Plasma desktop.
It ends by saying the Keyboard on disk is now this build.

### 4. Turn it on

1. Open **System Settings → Keyboard → Virtual Keyboard**.
2. Select **Shuffle Keyboard** and choose **Apply**.
3. Sign out and back in, so KWin starts it.

The sign-in screen keeps Plasma's own on-screen keyboard.

### 5. Check it worked

- On a touchscreen, tap a text field. Four rows of large keys come up at the
  bottom of the screen. Tap **Hide**, at the bottom right, to put them away.
- With a mouse, the **Keyboard** entry in the system tray brings the keys up.
- Tap the trackpad mark at the space bar's right end: the keys turn into a
  trackpad for the pointer.

### 6. Update

After every Plasma update, and to get a newer Keyboard:

```bash
cd ~/shuffle-keyboard
git pull
./install-keyboard.sh
```

Then sign out and back in. Until you do, you keep typing on the copy KWin
started.

### 7. Uninstall

1. Open **System Settings → Keyboard → Virtual Keyboard**, select **None**,
   or Plasma's own keyboard, and choose **Apply**. The uninstaller refuses
   while the Shuffle Keyboard is still chosen, so a touch-only computer is
   never left with no keys at the next sign-in.
2. In Konsole:

   ```bash
   cd ~/shuffle-keyboard
   ./uninstall-keyboard.sh
   ```

3. Sign out and back in.

To delete the download too, run `rm -rf ~/shuffle-keyboard`.

## For developers

On an Arch-family Plasma 6 development system, with Qt 6.10, KDE Frameworks
6.26 and Plasma 6.7 or later, Qt Virtual Keyboard, Qt Wayland and LayerShellQt
(`.github/workflows/arch.yml` lists the Arch packages):

```sh
cmake -S . -B build -G Ninja -DBUILD_TESTING=OFF -DCMAKE_BUILD_TYPE=RelWithDebInfo
cmake --build build
```

The executable is `build/bin/shuffle-keyboard`. `./verify.sh` formats, checks
licence headers, builds and runs the tests.

Do not replace the active desktop keyboard while developing. Install into a
staging prefix first:

```sh
cmake --install build --prefix "$PWD/stage"
```

`./install-keyboard.sh` builds the Keyboard and replaces the copy in your own
prefix. Where the sign-in screen has its own copy under `/usr/local`, put
there by the Shuffle desktop, it updates that too. KWin must start the binary
as its virtual keyboard. Started as a normal application it exits, unless
`SHUFFLE_PREVIEW_MODE=1` is set for an isolated test. The by-hand pass is
[`docs/PHYSICAL_ACCEPTANCE.md`](docs/PHYSICAL_ACCEPTANCE.md).
`./uninstall-keyboard.sh` removes exactly what `./install-keyboard.sh` put in
your prefix.

The fork installs under its own names, so it can sit beside Plasma's own
keyboard and neither loads the other's pieces: the QML modules
`org.shuffle.keyboard` and `QtQuick.VirtualKeyboard.Styles.Shuffle`, the
settings page `kcm_shufflekeyboard`, layouts under `share/shuffle-keyboard` and
settings in `shufflekeyboardrc`, which it fills from `plasmakeyboardrc` the
first time it runs. The one name it shares is the `plasma-keyboard` program the
sign-in screen starts, which Shuffle's packaging and its sign-in installer
point at this build.
