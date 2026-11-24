#!/usr/bin/env bqn
# Accounts: bakhlo's role samples (fixtures/loci, ROLE questions), and adding and
# naming accounts as bk loci does (tests/test_with_bk.sh compares the bytes).
Assert ← {𝕩 ? 1 ; •Out "test_loci: FAILED" ⋄ •Exit 1}
change ← •Import "../src/change.bqn"
tab ← @+9
Fields ← {(((¬m)×1++`m←tab=𝕩)-1)⊔𝕩}
s ← change.Open •file.Bytes "fixtures/loci/book.txt"
roles ← ("ROLE"≡4⊸↑)¨⊸/ •FLines "fixtures/loci/rules.answers"
Answer ← {
  r ← s change.Apply ⟨1↓∾(tab⊸∾)¨"SET-ROLE"‿𝕩‿"EXPENSE"⟩
  r.ok◶⟨{𝕊: "REFUSED"‿r.code}, ⟨"OK"⟩˙⟩ @
}
right ← {(2↓Fields 𝕩) ≡ Answer 1⊑Fields 𝕩}¨ roles
Assert ∧´right
•Out "role samples: "∾•Fmt ≠right

Lines ← {(change.Bytes 𝕩) ≡ •ToUTF8 ∾(∾⟜(@+10))¨𝕨}   # expected lines ≡ the book's bytes
Do ← {r ← s change.Apply 𝕩 ⋄ r}
# a new account: named by its ID, then by a name; its description is the name
a ← Do ⟨"ADD-LOCUS"∾tab∾"cafe", "SET-LOCUS-LABEL"∾tab∾"cafe"∾tab∾"  Café\\\\Bar ", "SET-ROLE"∾tab∾"cafe"∾tab∾"EXPENSE"⟩
Assert a.ok
Assert ⟨"LOCUS"∾tab∾"cafe"∾tab∾"Café\\\\Bar"∾tab∾"Café\\\\Bar"⟩ ≡ ("LOCUS"∾tab∾"cafe")⊸{𝕨≡(≠𝕨)↑𝕩}¨⊸/ a.lines
Assert ⟨"ROLE"∾tab∾"bank"∾tab∾"ASSET", "ROLE"∾tab∾"cafe"∾tab∾"EXPENSE"⟩ ≡ ("ROLE"≡4⊸↑)¨⊸/ a.lines
Assert "Café\\Bar" ≡ ⊑(a.book.locus.id≡¨<"cafe")/a.book.locus.label
Assert "duplicate-locus" ≡ (Do ⟨"ADD-LOCUS"∾tab∾"bank"⟩).code
Assert "locus-not-approved" ≡ (Do ⟨"SET-LOCUS-LABEL"∾tab∾"nowhere"∾tab∾"x"⟩).code
Assert "invalid-label" ≡ (Do ⟨"SET-LOCUS-LABEL"∾tab∾"bank"∾tab∾"   "⟩).code
Assert "invalid-label" ≡ (Do ⟨"SET-LOCUS-LABEL"∾tab∾"bank"∾tab∾81⥊'a'⟩).code
Assert "invalid-role" ≡ (Do ⟨"SET-ROLE"∾tab∾"wallet"∾tab∾"asset"⟩).code
Assert "invalid-locus" ≡ (Do ⟨"ADD-LOCUS"∾tab∾"two words"⟩).code
# all or none: a refused change leaves the book as it was
Assert ¬(Do ⟨"ADD-LOCUS"∾tab∾"cafe", "ADD-LOCUS"∾tab∾"cafe"⟩).ok
•Out "test_loci: ok"
