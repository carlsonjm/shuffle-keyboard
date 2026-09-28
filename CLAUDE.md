# Shuffle Keyboard — Claude Code entry point

`AGENTS.md` is the authoritative startup and working contract for this
repository and applies unchanged to Claude Code. Read it first. This file adds
only what a session working on this machine needs.

## Which checkout

The working tree is `Projects/Shuffle/shuffle-keyboard`. The keyboard was
written in a retired checkout that is off-limits to sessions here, and work has
arrived from it by hand.

**Bring changed files, never the folder.** Copying the old folder over this one
brings its hidden `.git` with it, which replaces this repository's history,
remote and every commit in one move. It happened on 21 September: the checkout
reverted to a shallow clone with one commit and no link to GitHub, and only the
pushed copy made it recoverable. If it happens again, do not re-commit the tree
on top. Re-add the `origin` remote, `git fetch --unshallow origin`,
`git reset --soft origin/shuffle-1.0`, then `git add -A` and read the real
difference before committing any of it.

## Suite position

One of five repositories. `kadunce`, `tettegouche` and `temperance` are the
public components; `shuffle` downstream assembles the product. This repository
is Block 9 in `../kadunce/docs/ROADMAP-CC.md`, and it is private because it has
not been published yet, not because it can be closed: it carries KDE's licence,
and whoever receives a build is entitled to its source.

`bottomsurfacecoordinator` is where this repository meets `shuffle`: it asks
the Bottom Surface for the bottom of the screen where one is installed, and
falls back to Plasma's bottom panel where none is
(`docs/KEYBOARD-CONTRACT.md` § The bottom of the screen).
