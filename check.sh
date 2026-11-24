#!/bin/sh
# Every check: the sample test, and whether the copied samples are still bakhlo's.
set -eu
cd "$(dirname "$0")"
bqn tests/test_book.bqn
bqn tests/test_change.bqn
if [ -d ../bakhlo/test ]; then
  for d in common_format records scheduled; do
    diff -r -x '*.ml' "../bakhlo/test/$d" "tests/fixtures/$d"
  done
  echo "samples: same as bakhlo"
else
  echo "samples: bakhlo not found next to this repository; not compared"
fi
