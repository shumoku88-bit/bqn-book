#!/usr/bin/env bqn
# Saving on a synthetic book in a fresh directory: the saved bytes are the changed
# book's and the old book is .prev; a book changed since loading (K12) or locked by
# another process is refused and left as it was.
Assert ← {𝕩 ? 1 ; •Out "test_store: FAILED at "∾•Fmt 𝕨 ⋄ •Exit 1}
change ← •Import "../src/change.bqn"
store ← •Import "../src/store.bqn"
tab ← @+9
dir ← ¯1↓1⊑•SH "mktemp"‿"-d"
book ← dir∾"/book.txt"
fixtures ← •file.At "fixtures/records/"
book •file.Bytes •file.Bytes fixtures∾"base.txt"
newSplit ← ⟨
  "PUT-ENTRY"∾tab∾"NEW"∾tab∾"-"
  "TX"∾tab∾"split"∾tab∾"2027-01-12"∾tab∾"DESC"∾tab∾"shared meal"
  "EFFECT"∾tab∾"bank"∾tab∾"jpy"∾tab∾"-75"
  "EFFECT"∾tab∾"food"∾tab∾"jpy"∾tab∾"30"
  "EFFECT"∾tab∾"food"∾tab∾"jpy"∾tab∾"45"
  "ORIGINAL"∾tab∾"usd"∾tab∾"50"
  "MERCHANT"∾tab∾"sample-cafe"
  "ENDTX"
⟩

# saved: the changed bytes; the old book is .prev; nothing else is left
loaded ← store.Load book
saved ← loaded store.Save loaded change.Apply newSplit
1 Assert saved.ok
2 Assert (•file.Bytes book) ≡ •file.Bytes fixtures∾"new-split.after.txt"
3 Assert (•file.Bytes book∾".prev") ≡ •file.Bytes fixtures∾"base.txt"
4 Assert ∧´(•file.List dir)∊"book.txt"‿"book.txt.prev"‿"book.txt.lock"
5 Assert (saved.bytes ≡ •file.Bytes book) ∧ saved.lines ≡ (store.Load book).lines   # it returns the saved book

# K12: somebody else saved after we loaded
stale ← store.Load book
other ← stale store.Save stale change.Apply ⟨"PUT-ENTRY"∾tab∾"NEW"∾tab∾"-", "TX"∾tab∾"x"∾tab∾"2027-01-13", "EFFECT"∾tab∾"bank"∾tab∾"jpy"∾tab∾"-1", "EFFECT"∾tab∾"food"∾tab∾"jpy"∾tab∾"1", "ENDTX"⟩
6 Assert other.ok
before ← •file.Bytes book
late ← stale store.Save stale change.Apply ⟨"PUT-ENTRY"∾tab∾"NEW"∾tab∾"-", "TX"∾tab∾"y"∾tab∾"2027-01-13", "EFFECT"∾tab∾"bank"∾tab∾"jpy"∾tab∾"-2", "EFFECT"∾tab∾"food"∾tab∾"jpy"∾tab∾"2", "ENDTX"⟩
7 Assert (¬late.ok) ∧ late.code≡"conflict"
8 Assert before ≡ •file.Bytes book

# another process holds the writer lock
marker ← dir∾"/held"
•SH "sh"‿"-c"‿("bqn '"∾(•file.At "hold_lock.bqn")∾"' '"∾book∾".lock' '"∾marker∾"' 2 >/dev/null 2>&1 &")
waited ← {•Delay 0.05 ⋄ 𝕩+1}•_while_{(𝕩<100) ∧ ¬•file.Exists marker} 0   # at most 5 s
9 Assert •file.Exists marker
current ← store.Load book
blocked ← current store.Save current change.Apply ⟨"PUT-ENTRY"∾tab∾"NEW"∾tab∾"-", "TX"∾tab∾"z"∾tab∾"2027-01-14", "EFFECT"∾tab∾"bank"∾tab∾"jpy"∾tab∾"-3", "EFFECT"∾tab∾"food"∾tab∾"jpy"∾tab∾"3", "ENDTX"⟩
10 Assert (¬blocked.ok) ∧ blocked.code≡"locked"
11 Assert current.bytes ≡ •file.Bytes book

# bakhlo itself reads what was saved, when it is built next to this repository
bk ← •file.At "../../bakhlo/_build/default/tui/app/bakhlo_tui.exe"
{𝕊: 12 Assert 0=⊑•SH bk‿"--book"‿book‿"bal"}⍟(•file.Exists bk) @

•SH "rm"‿"-rf"‿dir
•Out "test_store: ok"
