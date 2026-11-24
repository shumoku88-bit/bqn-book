# Samples from bakhlo

`common_format/` is a copy of bakhlo's `test/common_format/` (bakhlo commit `31f86a2`):
the shared samples of Common Format v0 (`bakhlo/docs/COMMON_FORMAT.ja.md`). They are synthetic.

- `read.answers`: whether bakhlo accepts each sample, or which code and line it refuses.
- `ok-*.answers`: the current balances of each accepted sample.

The answers are bakhlo's: do not edit them here. When bakhlo changes them, copy the folder
again. `./check.sh` reports any difference while `../bakhlo` is present.
