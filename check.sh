#!/bin/sh
# Every check: bakhlo's samples (reading, balances, printing, changes), saving on a
# synthetic book, the command line, and whether the copied samples are still bakhlo's.
set -eu
cd "$(dirname "$0")"
python3 tests/names.py
bqn tests/test_book.bqn
bqn tests/test_amount.bqn
bqn tests/test_change.bqn
bqn tests/test_form.bqn
bqn tests/test_config.bqn
bqn tests/test_store.bqn
bqn tests/test_view.bqn
sh tests/test_with_bk.sh

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
bin/book tests/fixtures/common_format/ok-full.txt plans > "$dir/out"
grep -qx 'plan-0002	2027-02-06	jpy	open		3000	bank	phone' "$dir/out"
cp tests/fixtures/common_format/ok-full.txt "$dir/full.txt"
bin/book "$dir/full.txt" entry tx-0003 | bin/book "$dir/full.txt" save > "$dir/out"
cmp -s "$dir/full.txt" tests/fixtures/common_format/ok-full.txt
printf 'DAY\t2027/1/12\nMEMO\tlunch\nMEASURE\tjpy\nROW\t-\tbank\t-(500+300)/2\nROW\t-\tfood\t+400\n' |
  bin/book tests/fixtures/records/base.txt form NEW - > "$dir/out"
grep -qx 'EFFECT	bank	jpy	-400' "$dir/out"
echo "bin/book: ok"

if command -v emacs >/dev/null 2>&1; then
  emacs --batch -l tests/test_emacs.el -f ert-run-tests-batch-and-exit > "$dir/out" 2>&1 || { cat "$dir/out"; exit 1; }
  echo "emacs: ok"
fi

if [ -d ../bakhlo/test ]; then
  for d in common_format records scheduled amounts periods; do
    diff -r -x '*.ml' "../bakhlo/test/$d" "tests/fixtures/$d"
  done
  echo "samples: same as bakhlo"
else
  echo "samples: bakhlo not found next to this repository; not compared"
fi
