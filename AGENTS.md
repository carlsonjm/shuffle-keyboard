# Repository context and startup

Shuffle Keyboard is a fork of KDE's `plasma-keyboard`, currently at its 6.7.5
release. It owns the Shuffle layout, gestures, height, panel handoff and
presentation. It owns no input engine: a touched key goes to Qt Virtual
Keyboard, its input-method client hands the result to KWin, and KWin delivers it
through the application's own text-input path.

For every task, read this file, `docs/KEYBOARD-CONTRACT.md` for what the
Keyboard is, `docs/INPUT.md` for every input it handles, and
`docs/FEASIBILITY.md` for why the base was chosen. Suite block order lives in
`../shuffle/docs/suite/ROADMAP-CC.md`, where this repository is Block 9; read it when
that checkout is present, and say the suite plan was unavailable when it is not.

## Working in a fork

- `upstream` points at invent.kde.org. Keep the fork small enough to rebase onto
  a later Plasma Keyboard: change upstream files where Shuffle behavior requires
  it, not to restyle them.
- Every file this fork adds carries an SPDX header. The licence travels with
  what ships, so a file that cannot say what it is cannot ship.
- The commit hook refuses unformatted C++. `./verify.sh` checks the same thing
  first, so a formatting refusal never arrives after the work is done.
- The row geometry in `docs/KEYBOARD-CONTRACT.md` is settled by the evidence in
  `docs/FEASIBILITY.md`. Re-open it with evidence, not with a preference.

## Documents

- Every input the Keyboard handles is defined in `docs/INPUT.md`, which opens
  with its controls map: each destination by name, with the touch that reaches
  it. Other documents cite it; a README quick start may repeat the map's rows.
- Each document owns one subject and states what is true now. History lives in
  Git.

## Holds

- J approves product behavior and visual direction before implementation begins.
  He sets intent, scope and sequencing and does not review code.
- One implementation owner: this workflow. Changes arrive as commits against
  this repository, never as a folder copied from somewhere else. A second worker
  is read-only review or a disjoint file set.
- Reproduce a defect and measure the property controlling it before changing it.
- Run `./verify.sh` before treating a change as complete. It formats, checks
  licence headers, builds and runs the tests. The mock input-method compositor
  test only builds where Qt WaylandCompositor is installed; its absence is a
  skip, not a pass.
- Automated checks cannot establish typing accuracy, latency, dropped
  characters, focus behavior or finger comfort. `docs/PHYSICAL_ACCEPTANCE.md` is
  the pass for those, on a touch device, by hand.
- Installing into the user's session, running `kbuildsycoca6`, restarting Plasma
  and logging out are the user's to perform. Prepare the candidate and hand the
  installation over as the exact commands in `docs/PHYSICAL_ACCEPTANCE.md`.
