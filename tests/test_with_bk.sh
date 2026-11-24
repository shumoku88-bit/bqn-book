#!/bin/sh
# bk (bakhlo) and bqn-book on one synthetic book, as moko uses them side by side:
# one writes at a time, neither loses the other's record, and both give the same
# guide. Needs bakhlo built next to this repository.
set -eu
cd "$(dirname "$0")/.."
bk=../bakhlo/_build/default/tui/app/bakhlo_tui.exe
[ -x "$bk" ] || { echo "with bk: bakhlo not built next to this repository; not run"; exit 0; }
dir=$(mktemp -d)
trap 'rm -rf "$dir"' EXIT
book=$dir/book.txt
answers='2027-01-20\nbk test\njpy\nbank\n-300\nfood\n\n\n'

# 1. bqn-book holds the writer lock: bk does not save, and says why
cp tests/fixtures/records/base.txt "$book"
bqn tests/hold_lock.bqn "$book.lock" "$dir/held" 3 &
while [ ! -f "$dir/held" ]; do sleep 0.1; done
printf "${answers}y\nn\n" | "$bk" --book "$book" r > "$dir/out" 2>&1 || true
grep -q 'Not saved: file-or-writer-unavailable' "$dir/out"
cmp -s "$book" tests/fixtures/records/base.txt
wait

# 2. bqn-book saves while bk waits to save: bk refuses, the saved record stays
cp tests/fixtures/records/base.txt "$book"
( printf "$answers"; sleep 3; printf 'y\nn\n' ) | "$bk" --book "$book" r > "$dir/out" 2>&1 &
sleep 1
printf 'PUT-ENTRY\tNEW\t-\nTX\temacs-1\t2027-01-21\tDESC\temacs test\nEFFECT\tbank\tjpy\t-5\nEFFECT\tfood\tjpy\t5\nENDTX\n' |
  bin/book "$book" save > /dev/null
wait
grep -q 'The book changed while you were typing; nothing was saved' "$dir/out"
grep -q 'emacs test' "$book"
! grep -q 'bk test' "$book"

# 3. the same book and settings give the same guide (bk counts from today)
cp tests/fixtures/scheduled/base.txt "$book"
mkdir -p "$dir/config"
today=$(date +%Y-%m-%d)
printf 'pay\t%s\t2099-01-01\n' "$(date -v-1d +%Y-%m-%d)" > "$dir/config/boundary-presets.tsv"
printf 'bank\tjpy\n' > "$dir/config/daily-pace.tsv"
theirs=$("$bk" --book "$book" pace | sed -n 's/^ Today [0-9-]*: \([0-9,-]*\) jpy\/day$/\1/p' | tr -d ,)
ours=$(printf 'PACE\tjpy\t%s\t2099-01-01\nPOOL\tbank\n' "$today" | bin/book "$book" ask | sed -n 's/^DAILY	//p')
[ -n "$theirs" ] && [ "$theirs" = "$ours" ]
echo "with bk: ok"
