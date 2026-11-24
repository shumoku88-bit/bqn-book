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
# 4. the same plans in series, with the same missing months: amount, next, last,
# how many, and the notes (monthly, missing) of every series, in bk's order
cp tests/fixtures/scheduled/series.txt "$book"
printf 'phone\t2027-01-25\t1\tbank\tphone\nrent\t2027-01-27\t1\tbank\trent\n' > "$dir/config/scheduled-coverage.tsv"
theirs=$("$bk" --book "$book" plans < /dev/null | tail -n +2 |
  awk -F "  +" "{ gsub(/,/, \"\", \$5); print \$5, \$7, \$8, \$9, \$10 }")
ours=$(bin/book "$book" series "$today" | awk -F '\t' '{
  note = ($5 < "'"$today"'") ? "overdue" : ""
  if ($8 == 1) note = note (note == "" ? "" : ", ") "monthly"
  if ($9 != "") note = note ", missing " $9
  print $3, $5, $6, $7, note }')
[ -n "$theirs" ] && [ "$theirs" = "$ours" ] || { printf 'bk plans:\n%s\nours:\n%s\n' "$theirs" "$ours"; exit 1; }
# 5. accounts: a new one with a name and a role, a hidden one offered again under
# its ID, and a new name for one in use, the same bytes as bk loci add and name
cp tests/fixtures/scheduled/base.txt "$book"
cp tests/fixtures/scheduled/base.txt "$dir/ours.txt"
printf 'cafe\n  Café\\Bar \nexpense\ny\n' | "$bk" --book "$book" loci add > /dev/null
printf 'gym\ngym\n-\ny\n' | "$bk" --book "$book" loci add > /dev/null
printf 'Ban\nMain bank\ny\n' | "$bk" --book "$book" loci name > /dev/null
printf '%s\n' 'ADD-LOCUS	cafe' 'SET-LOCUS-LABEL	cafe	  Café\\Bar ' 'SET-ROLE	cafe	EXPENSE' \
  'ADD-LOCUS	gym' 'SET-LOCUS-LABEL	bank	Main bank' | bin/book "$dir/ours.txt" save > /dev/null
cmp -s "$book" "$dir/ours.txt" || { diff "$book" "$dir/ours.txt"; exit 1; }
! cmp -s "$book" tests/fixtures/scheduled/base.txt
echo "with bk: ok"
