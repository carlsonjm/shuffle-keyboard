# Documentation index

| Document | Authority |
| --- | --- |
| [`../README.md`](../README.md) | What the current candidate does |
| [`../AGENTS.md`](../AGENTS.md) | Startup, working contract and holds |
| [`FEASIBILITY.md`](FEASIBILITY.md) | Why this base, and what the geometry comparison settled |
| [`PHYSICAL_ACCEPTANCE.md`](PHYSICAL_ACCEPTANCE.md) | The by-hand pass: install, typing, gestures, delivery |

Checking it:

| Script | What it does |
| --- | --- |
| `../verify.sh` | Formatting, licence headers, build and tests. Run before treating a change as complete. |
| `../install-keyboard.sh` | Builds and replaces the installed Keyboard in your own prefix, and refuses if what landed is not what was built. Restarts nothing: the compositor holds the copy it started for the life of the session. |
| `../tests/verify-handle.sh` | Runs the drag handle in a compositor of its own: its own bus, runtime and config, all discarded afterwards. It answers whether a process whose other window is an input panel can also own a layer surface, and where the compositor puts it against a reserved band. |

Suite block order lives in `../../kadunce/docs/ROADMAP-CC.md`. This repository
is Block 9.
