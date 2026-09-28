# Documentation index

| Document | Authority |
| --- | --- |
| [`../README.md`](../README.md) | What this is, building and installing |
| [`../AGENTS.md`](../AGENTS.md) | Startup, working contract and holds |
| [`KEYBOARD-CONTRACT.md`](KEYBOARD-CONTRACT.md) | What the Keyboard is: layout, height, scrub columns, precision surface, showing and hiding |
| [`INPUT.md`](INPUT.md) | Every input the Keyboard handles, and what it does |
| [`FEASIBILITY.md`](FEASIBILITY.md) | Why this base, the delivery evidence, and what settled the row geometry |
| [`PHYSICAL_ACCEPTANCE.md`](PHYSICAL_ACCEPTANCE.md) | The by-hand pass: install, typing, inputs, delivery |

Checking it:

| Script | What it does |
| --- | --- |
| `../verify.sh` | Formatting, licence headers, build and tests. Run before treating a change as complete. |
| `../install-keyboard.sh` | Builds and replaces the installed Keyboard in your own prefix, and refuses if what landed is not what was built. Restarts nothing: the compositor holds the copy it started for the life of the session. |
| `../tests/verify-raise.sh` | Raises the Keyboard from its tray entry, in a compositor of its own, with a stand-in for Kadunce answering and an application holding the focus. Asks the compositor where the focus is at each step, with a text box ready and on a cold start, and puts the keys away with a second tap. |
| `../tests/verify-seat.sh` | Seats the Keyboard in a compositor of its own over a band that reserves the bottom of the output and then gives it up, and asks where the compositor put it. |

Suite block order lives in `../../kadunce/docs/ROADMAP-CC.md`. This repository
is Block 9.
