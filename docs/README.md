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
| `../tests/verify-handle.sh` | Runs the drag handle in a compositor of its own: its own bus, runtime and config, all discarded afterwards. It answers whether a process whose other window is an input panel can also own a layer surface, and where the compositor puts it against a reserved band. |
| `../tests/verify-raise.sh` | Raises the Keyboard from its handle in a compositor of its own, with an application holding the focus, and asks the compositor where the focus is at each step. |
| `../tests/verify-seat.sh` | Seats the Keyboard in a compositor of its own over a band that reserves the bottom of the output and then gives it up, and asks where the compositor put it. |

Suite block order lives in `../../kadunce/docs/ROADMAP-CC.md`. This repository
is Block 9.
