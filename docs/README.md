# Documentation index

| Document | Authority |
| --- | --- |
| [`../README.md`](../README.md) | What this is, building and installing |
| [`../AGENTS.md`](../AGENTS.md) | Startup, working contract and holds |
| [`KEYBOARD-CONTRACT.md`](KEYBOARD-CONTRACT.md) | What the Keyboard is: card, layout, height, editing, precision surface, showing and hiding |
| [`INPUT.md`](INPUT.md) | Every input the Keyboard handles, and what it does |
| [`FEASIBILITY.md`](FEASIBILITY.md) | Why this base, the delivery evidence, and what settled the row geometry |
| [`PHYSICAL_ACCEPTANCE.md`](PHYSICAL_ACCEPTANCE.md) | The by-hand pass: install, typing, inputs, delivery |

Checking it:

| Script | What it does |
| --- | --- |
| `../verify.sh` | Formatting, licence headers, build and tests. Run before treating a change as complete. |
| `../install-keyboard.sh` | Builds and replaces the installed Keyboard in your own prefix, and refuses if what landed is not what was built. Brings the sign-in screen's copy under `/usr/local` level too, where there is one. Restarts nothing: the compositor holds the copy it started for the life of the session. Lists what it installed, removes what an earlier build installed and this one does not, and warns when Plasma's own `plasma-keyboard` is installed too. |
| `../uninstall-keyboard.sh` | Removes exactly what `install-keyboard.sh` listed, and refuses while the desktop is still set to start the Shuffle Keyboard. Leaves the sign-in screen's copy to Shuffle's `uninstall-signin-keyboard.sh`. |
| `../tests/verify-raise.sh` | Raises the Keyboard from its tray entry, in a compositor of its own, with a stand-in for Kadunce answering and an application holding the focus. Asks the compositor where the focus is at each step, with a text box ready and on a cold start, and puts the keys away with a second tap. |
| `../tests/verify-seat.sh` | Seats the Keyboard in a compositor of its own over a band that reserves the bottom of the output and then gives it up, and asks where the compositor put it. |
| `../tests/verify-panels.sh` | Raises and puts away the keys with no Bottom Surface installed, against a stand-in for Plasma's shell, and checks that the bottom panel autohides, comes back to its own mode, and comes back too after the Keyboard is killed with the keys up. |
| `../tests/verify-caret.sh` | Drags the caret trackpad left and right by the same distance, and asks the application how far its cursor went each way. |
| `../tests/verify-latch.sh` | Puts the keys away with Hide and with the tray entry while the trackpad is latched, by mouse and by finger, and asks the compositor whether they stay away. |
| `../tests/verify-hold.sh` | Holds a physical key with the keys down and with them up, and checks that it types only itself and opens nothing. |
| `../tests/verify-exit.sh` | Ends a compositor with the keys up, and checks that the Keyboard hands the bottom of the screen back and the compositor is gone within five seconds. |
| `../tests/verify-orphan.sh` | Crashes a compositor with a second behind its socket, and checks that the Keyboard leaves with the first rather than reconnecting. |

Each `tests/verify-*.sh` runs in a compositor of its own and touches nothing in
the running session. CI runs every one, against the released KWin on every
change and against the next one from Arch's kde-unstable every night; one that
cannot run where it is, for want of a tool, says so and is a skip, not a pass.

The suite's plan is kept privately, outside this repository.
