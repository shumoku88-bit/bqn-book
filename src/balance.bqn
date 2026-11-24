# Current balances in an admitted book (bakhlo docs/COMMON_FORMAT.ja.md,
# 「今の残高の求め方」). For each asked (Locus, Measure):
#
#   ZERO-ORIGIN or OPENING   the sum of its Effects in every TX
#   counted by an ASSERT     the counted amount, plus its Effects in the TXs after
#                            the anchor's last TX that the anchor's ALSO does not name
#   none of these            unknown: @, never 0
#
# The first ASSERT in file order counts a coordinate. PLAN never moves a balance,
# and HISTORY-FROM only matters for past dates. The result has asked's shape.

Balances ⇐ {book 𝕊 asked:
  c ← ⥊asked
  e‿a ← book.effect‿book.assert
  At ← {𝕩.locus⋈¨𝕩.measure}
  # rows: asked coordinates or ASSERTs; columns: Effects
  Sum ← {+˝˘𝕩×⎉1 e.amount}
  total ← Sum c≡⌜At e
  last ← {𝕩≡"-" ? ¯1 ; ⊑book.tx.id⊐⋈𝕩}¨book.anchor.last
  named ← book.also.anchor ⋈¨ book.tx.id⊐book.also.tx
  after ← ((a.anchor⊏last) <⌜ e.tx) ∧ ¬(a.anchor ⋈⌜ e.tx)∊named
  counted ← a.amount + Sum after ∧ (At a)≡⌜At e
  supported ← c ∊ (At book.zeroOrigin)∾At book.opening
  (≢asked) ⥊ supported ⊑¨ ((counted∾@)⊏˜(At a)⊐c) ⋈¨ total
}
