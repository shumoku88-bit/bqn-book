# Samples from bakhlo

Copies of bakhlo's `test/` folders (bakhlo commit `31f86a2`). They are synthetic.

- `common_format/`: the shared samples of Common Format v0 (`bakhlo/docs/COMMON_FORMAT.ja.md`).
  `read.answers` says whether bakhlo accepts each sample, or which code and line it refuses;
  `ok-*.answers` hold the current balances (`tests/test_book.bqn`).
- `amounts/`: typed amounts to smallest units and back (`tests/test_amount.bqn`). Three samples
  hold 60-digit integers, past what BQN numbers keep exact; there bqn-book refuses with its own
  `too-large`, and the test says how many.
- `records/`, `scheduled/`: changes to a book. Each `APPLY` block in `changes.answers` gives the
  book after it byte for byte, or the refusal's code (`tests/test_change.bqn`; the kinds of change
  not written yet are counted, not run). The questions after an `AFTER` (PACE, PAST, ACTIVITY) are asked of the changed book.

The answers are bakhlo's: do not edit them here. When bakhlo changes them, copy the folder
again. `./check.sh` reports any difference while `../bakhlo` is present.
