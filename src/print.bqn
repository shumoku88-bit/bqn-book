# Writing an admitted book back as book.txt (bakhlo docs/COMMON_FORMAT.ja.md,
# 「書き出しの決まり」). An accepted file has only one spelling, so reading and
# printing gives back the same bytes (K13): bytes ≡ •ToUTF8 Print (Read bytes).book

tab‿lf‿cr ← @+9‿10‿13
Int ← {𝕩<0 ? "-"∾𝕊-𝕩 ; 𝕩<10 ? ⋈'0'+𝕩 ; (𝕊⌊𝕩÷10)∾'0'+10|𝕩}
from‿to ← ⟨'\',lf,cr,tab⟩‿⟨"\\","\n","\r","\t"⟩
Escape ← {i←from⊐𝕩 ⋄ ∾(to∾⋈¨𝕩)⊏˜i+(4=i)×↕≠𝕩}

# kind Spell columns‿optional: one line per row of the aligned columns, then
# that row's optional trailing fields (a list of 0 or more).
Spell ← {kind 𝕊 cols‿more: {1↓∾(tab∾⊢)¨𝕩}¨ (⟨kind⟩∾⊢)¨ (<˘⍉>cols) ∾¨ more}
None ← {(≠⊑𝕩)⥊<⟨⟩}
_lines ← {𝕗 Spell 𝕩‿(None 𝕩)}
# heads end _block owner‿body: each head line, its block's lines in the given
# order, and the closing line.
_block ← {end←𝕗 ⋄ owner‿body ← 𝕩 ⋄ ∾ 𝕨 {⟨𝕨⟩∾𝕩∾⟨end⟩}¨ (owner∾≠𝕨)⊔body}

Print ⇐ {𝕊 b:
  t‿e‿p‿a ← b.tx‿b.effect‿b.plan‿b.anchor
  txHeads ← "TX" Spell ⟨t.id, t.day⟩‿(t.hasMemo {𝕨 ? "DESC"⋈Escape 𝕩 ; ⟨⟩}¨ t.memo)
  txs ← txHeads "ENDTX"_block ⟨
    e.tx ∾ b.reversal.tx ∾ b.original.tx ∾ b.merchant.tx ∾ b.exchange.tx
    ∾⟨
      "EFFECT" Spell ⟨e.locus, e.measure, Int¨e.amount⟩‿((0<≠¨e.key)⥊¨<¨e.key)
      "REVERSAL-OF"_lines ⟨b.reversal.target⟩
      "ORIGINAL"_lines ⟨b.original.measure, Int¨b.original.amount⟩
      {0=≠𝕩 ? "NONMERCHANT" ; "MERCHANT"∾tab∾𝕩}¨ b.merchant.name
      "EXCHANGE"_lines ⟨b.exchange.from, b.exchange.to⟩
    ⟩
  ⟩
  planHeads ← "PLAN"_lines ⟨p.id, p.day, p.measure⟩
  plans ← planHeads "ENDPLAN"_block ⟨
    b.change.plan ∾ b.paid.plan ∾ b.cancelled.plan
    ∾⟨
      "CHANGE"_lines ⟨b.change.locus, Int¨b.change.amount⟩
      "PAID-BY"_lines ⟨b.paid.tx⟩
      "CANCELLED"_lines ⟨b.cancelled.day⟩
    ⟩
  ⟩
  anchorHeads ← "ANCHOR"_lines ⟨a.last⟩
  anchors ← anchorHeads "ENDANCHOR"_block ⟨
    b.also.anchor ∾ b.assert.anchor
    ∾⟨"ALSO"_lines ⟨b.also.tx⟩, "ASSERT"_lines ⟨b.assert.locus, b.assert.measure, Int¨b.assert.amount⟩⟩
  ⟩
  ∾{𝕩∾lf}¨∾⟨
    ⟨"BOOK"∾tab∾"1"⟩
    "MEASURE"_lines ⟨b.measure.id, Int¨b.measure.scale⟩
    "LOCUS" Spell ⟨b.locus.id, Escape¨b.locus.label, Escape¨b.locus.help⟩‿(b.locus.hidden⥊¨<<"HIDDEN")
    "ROLE"_lines ⟨b.role.locus, b.role.name⟩
    txs, plans
    "ZERO-ORIGIN"_lines ⟨b.zeroOrigin.locus, b.zeroOrigin.measure⟩
    "OPENING"_lines ⟨b.opening.locus, b.opening.measure, b.opening.tx⟩
    "HISTORY-FROM"_lines ⟨b.historyFrom.locus, b.historyFrom.measure, b.historyFrom.day⟩
    anchors
    "ITEM"_lines ⟨b.item.id, b.item.due, b.item.when, Escape¨b.item.context⟩
    "CLOSE"_lines ⟨b.close.item, b.close.day, b.close.kind⟩
    ⟨"END"⟩
  ⟩
}
