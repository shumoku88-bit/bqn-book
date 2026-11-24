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
- Never write the household (`../bakhlo-data`) before stage 5 of the plan and moko's
  explicit decision. Real-data checks use bakhlo's `./tools/household-copy`; keep
  private names, memos, amounts and counts out of this repository and its history.

## BQN

- Start from shapes: aligned columns per section, one row per line; a block line names
  its TX, PLAN or ANCHOR by index. Prefer tables (`⌜`), grouping (`⊔`), classification
  (`⊐`), membership (`∊`) and Under (`⌾`) over loops, `⍟` guards and `↩`.
- State rules as data where the specification is a table (see the reference rules in
  `src/read.bqn`), and let a rule's place carry its order.
- Names are case-insensitive and ignore underscores: `Lines`, `lines` and `_lines` clash.
- Try uncertain primitives in a small `bqn -e` probe; numbers are exact only up to 2⋆53.
