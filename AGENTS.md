# Working on bqn-book

Read `README.md` and `docs/PLAN.ja.md` first.

## Decisions (moko)

- 2026-11-24: the aim is to see how simply and elegantly BQN can say what bakhlo does
  with its `book.txt`. This repository replaced `bqn-ledger` (now in `../archive/`),
  whose older procedural code was dropped rather than polished.
- Work simply: commit small, tested slices to `main` (`./check.sh` first). No branches
  or pull requests.
- The format belongs to bakhlo (`bakhlo/docs/COMMON_FORMAT.ja.md`). Do not change it
  here; agree with bakhlo's answers, sample by sample.
- 2026-11-24 (stage 5): moko records the household (`../bakhlo-data`) through bk in the
  terminal or through bqn-book's Emacs screen, side by side; bakhlo's AGENTS.md says the
  same. They take turns by `book.txt.lock` and K12 (`tests/test_with_bk.sh`); bqn-book
  backs up after each save as bk does (`bin/backup`). The AI still never writes the
  household: real-data checks use bakhlo's `./tools/household-copy`. Keep private names,
  memos, amounts and counts out of this repository and its history; the household's own
  settings live in `emacs/local.el`, which Git ignores.

## Layers (moko, 2026-11-24)

Screens (a TUI, a GUI) must stay replaceable. Keep three layers:

- `src/read.bqn`, `balance.bqn`, `print.bqn`, `change.bqn` are pure: no files, no screens.
- `src/store.bqn` owns every effect on the book: lock, K12, durable write, `.prev`.
- `bin/book` is the screens' door: tab-separated lines in, tab-separated lines out; a
  change is written in bakhlo's change language. A screen never edits book.txt itself.

## BQN

- Start from shapes: aligned columns per section, one row per line; a block line names
  its TX, PLAN or ANCHOR by index. Prefer tables (`⌜`), grouping (`⊔`), classification
  (`⊐`), membership (`∊`) and Under (`⌾`) over loops, `⍟` guards and `↩`.
- State rules as data where the specification is a table (see the reference rules in
  `src/read.bqn`), and let a rule's place carry its order.
- Names are case-insensitive and ignore underscores: `Lines`, `lines` and `_lines` clash.
  A local `block` silently turns a call of `Block` into a constant. `tests/names.py`
  (in `./check.sh`) reports such pairs; name functions and values apart.
- Try uncertain primitives in a small `bqn -e` probe; numbers are exact only up to 2⋆53.
- BQN evaluates right to left: `(A) ∧ B` runs B first. Write one effect per line or step.
- A block that never uses 𝕩 or 𝕨 is evaluated at once; give it `𝕊:` to make it a function.
- Predicates end a body: names defined before `;` are gone after it. Use `◶` or a helper.
