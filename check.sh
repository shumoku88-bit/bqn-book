#!/bin/sh
# Every check: the sample test, and whether the copied samples are still bakhlo's.
set -eu
cd "$(dirname "$0")"
bqn tests/test_book.bqn
if [ -d ../bakhlo/test/common_format ]; then
  diff -r ../bakhlo/test/common_format tests/fixtures/common_format
  echo "samples: same as bakhlo"
else
  echo "samples: bakhlo not found next to this repository; not compared"
fi
