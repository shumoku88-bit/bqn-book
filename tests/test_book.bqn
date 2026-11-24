#!/usr/bin/env bqn
# bakhlo's shared samples (tests/fixtures/README.md):
# - every sample is accepted, or refused with bakhlo's code and line (read.answers);
# - every accepted sample prints back to its own bytes (K13);
# - its current balances are bakhlo's (ok-*.answers; UNKNOWN is @, not 0).
Assert ← {𝕩 ? 1 ; •Out "test_book: FAILED" ⋄ •Exit 1}
read ← •Import "../src/read.bqn"
print ← •Import "../src/print.bqn"
balance ← •Import "../src/balance.bqn"
dir ← "fixtures/common_format/"
tab ← @+9
Split ← {m←tab=𝕩 ⋄ ((((¬m)×1++`m)-1)∾1++´m)⊔𝕩}
Asks ← {kind 𝕊 file: Split¨ (kind⊸≡¨⊑∘Split¨)⊸/ •FLines dir∾file}

Said ← {𝕩.ok ? ⟨"OK"⟩ ; ⟨"REFUSED", 𝕩.code, •Fmt 𝕩.line⟩}
reads ← "READ" Asks "read.answers"
wrong ← {(2↓𝕩) ≢ Said read.Read •file.Bytes dir∾1⊑𝕩}¨reads
{•Out "wrong: "∾•Fmt 𝕩}¨ wrong/reads
Assert (64=≠reads) ∧ 0=+´wrong

oks ← (∨´"ok-"⊸⍷)¨⊸/ ⊑¨1⊸↓¨ reads
Book ← {(read.Read •file.Bytes dir∾𝕩).book}
reprinted ← {(•file.Bytes dir∾𝕩) ≡ •ToUTF8 print.Print Book 𝕩}¨oks
{•Out "not reprinted: "∾𝕩}¨ (¬reprinted)/oks
Assert ∧´reprinted

Balanced ← {𝕊 file:
  questions ← "BALANCE" Asks (¯3↓file)∾"answers"
  got ← (Book file) balance.Balances 1‿2⊸⊏¨questions
  want ← {𝕩≡"UNKNOWN" ? @ ; •ParseFloat 𝕩}∘(3⊸⊑)¨questions
  {•Out "balance: "∾•Fmt 𝕩}¨ (got≢¨want)/questions
  got≡want
}
Assert ∧´Balanced¨oks
•Out "test_book: ok"
