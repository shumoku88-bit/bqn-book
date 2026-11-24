#!/bin/sh
# Every check: bakhlo's samples (reading, balances, printing, changes), saving on a
# synthetic book, the command line, and whether the copied samples are still bakhlo's.
set -eu
cd "$(dirname "$0")"
python3 tests/names.py
bqn tests/test_book.bqn
bqn tests/test_change.bqn
bqn tests/test_store.bqn

dir=$(mktemp -d)
trap 'rm -rf "$dir"' EXIT
cp tests/fixtures/records/base.txt "$dir/book.txt"
printf 'PUT-ENTRY\tNEW\topen\nTX\tpaid-rent\t2027-02-10\nEFFECT\tbank\tjpy\t-300\nEFFECT\tfood\tjpy\t300\nENDTX\n' > "$dir/change"
bin/book "$dir/book.txt" preview < "$dir/change" > "$dir/out"
cmp -s "$dir/book.txt" tests/fixtures/records/base.txt
bin/book "$dir/book.txt" save < "$dir/change" > "$dir/out"
head -1 "$dir/out" | grep -qx SAVED
if bin/book "$dir/book.txt" save < "$dir/change" > "$dir/out"; then exit 1; fi
grep -qx 'REFUSED	duplicate-entry' "$dir/out"
printf 'PACE\tjpy\t2027-02-01\t2027-03-01\nPOOL\tbank\n' | bin/book tests/fixtures/scheduled/base.txt ask > "$dir/out"
grep -qx 'DAILY	3285' "$dir/out"
echo "bin/book: ok"

if [ -d ../bakhlo/test ]; then
  for d in common_format records scheduled; do
    diff -r -x '*.ml' "../bakhlo/test/$d" "tests/fixtures/$d"
  done
  echo "samples: same as bakhlo"
else
  echo "samples: bakhlo not found next to this repository; not compared"
fi
