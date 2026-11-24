# What a screen lists: one row of fields per Measure, Locus, entry or plan, in book
# order. Text is written as in book.txt (\t, \n, \\ escaped), so a row stays a row.
# Pure.

print ← •Import "print.bqn"
Rows ← {<˘⍉>𝕩}                                 # aligned columns → rows
# section At n: for each of n rows, its row in a block section (its tx or plan
# column), or that section's length where it has none
At ← {(↕𝕩)⊐˜𝕨}

# id, decimal places
Measures ⇐ {Rows ⟨𝕩.measure.id, print.Int¨𝕩.measure.scale⟩}

# id, label, help, HIDDEN or "", role or ""
Loci ⇐ {
  l‿r ← 𝕩.locus‿𝕩.role
  Rows ⟨l.id, print.Escape¨l.label, print.Escape¨l.help, l.hidden⊏""‿"HIDDEN", (r.name∾<"")⊏˜r.locus⊐l.id⟩
}

# id, day, memo, merchant (its name, NONMERCHANT, or ""), the TX it reverses, the
# plan it pays
Entries ⇐ {
  b ← 𝕩
  n ← ≠b.tx.id
  merchant ← (({0=≠𝕩 ? "NONMERCHANT" ; 𝕩}¨b.merchant.name)∾<"")⊏˜b.merchant.tx At n   # "" unclassified (K8)
  reverses ← (b.reversal.target∾<"")⊏˜b.reversal.tx At n
  pays ← (b.plan.id∾<"")⊏˜(b.paid.plan∾≠b.plan.id)⊏˜b.paid.tx⊐b.tx.id
  Rows ⟨b.tx.id, b.tx.day, print.Escape¨b.tx.memo, merchant, reverses, pays⟩
}

# id, due day, Measure, open | paid | cancelled, the paying TX or the cancelling day
Plans ⇐ {
  b ← 𝕩
  n ← ≠b.plan.id
  paid ← b.paid.plan At n
  cancelled ← b.cancelled.plan At n
  state ← (paid<≠b.paid.plan)+2×cancelled<≠b.cancelled.plan
  detail ← (b.paid.tx∾<"")⊏˜paid
  detail ↩ ((b.cancelled.day∾<"")⊏˜cancelled) {0=≠𝕩 ? 𝕨 ; 𝕩}¨ detail
  Rows ⟨b.plan.id, b.plan.day, b.plan.measure, state⊏"open"‿"paid"‿"cancelled", detail⟩
}
