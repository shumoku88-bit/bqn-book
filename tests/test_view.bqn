#!/usr/bin/env bqn
# What screens read: the list views on bakhlo's full sample, and Edit: every entry
# and open plan of every sample book, sent back unchanged, leaves the book byte for
# byte as it was.
Assert ← {𝕩 ? 1 ; •Out "test_view: FAILED at "∾•Fmt 𝕨 ⋄ •Exit 1}
change ← •Import "../src/change.bqn"
view ← •Import "../src/view.bqn"
Row ← {⊑(⊑¨𝕨)⊐⋈𝕩}                               # rows Row id: the row with that id

full ← (change.Open •file.Bytes "fixtures/common_format/ok-full.txt").book
entries ← view.Entries full
1 Assert ⟨"tx-0003","2027-01-05","コンビニ","some-store","",""⟩ ≡ (entries Row "tx-0003")⊑entries
2 Assert ⟨"tx-0004","2027-01-06","","NONMERCHANT","","plan-0001"⟩ ≡ (entries Row "tx-0004")⊑entries
3 Assert ⟨"tx-0005","2027-01-07","返品","","tx-0003",""⟩ ≡ (entries Row "tx-0005")⊑entries
4 Assert "" ≡ 3⊑(entries Row "tx-0001")⊑entries         # unclassified, not NONMERCHANT
5 Assert "内容不明の出金\tあとで確認\\済" ≡ 2⊑(entries Row "tx-0009")⊑entries   # escaped
plans ← view.Plans full
6 Assert (2↓¨plans) ≡ ⟨⟨"jpy","paid","tx-0004"⟩,⟨"jpy","open",""⟩,⟨"jpy","cancelled","2027-01-20"⟩⟩
loci ← view.Loci full
7 Assert ⟨"old-phone","旧電話代","解約した回線","HIDDEN",""⟩ ≡ (loci Row "old-phone")⊑loci
8 Assert "ASSET" ≡ 4⊑(loci Row "wallet")⊑loci
9 Assert ⟨⟨"jpy","0"⟩,⟨"usd","2"⟩⟩ ≡ view.Measures full

# Edit, sent back unchanged
Accepted ← {(".txt"≡¯4↑𝕩) ∧ "ng-"≢3↑𝕩}            # every sample book except refused ones
books ← ∾{𝕩⊸∾¨ Accepted¨⊸/ •file.List 𝕩}¨ "fixtures/common_format/"‿"fixtures/records/"‿"fixtures/scheduled/"
Back ← {𝕊 path:
  bytes ← •file.Bytes path
  s ← change.Open bytes
  open ← (¬(↕≠s.book.plan.id)∊s.book.paid.plan∾s.book.cancelled.plan)/s.book.plan.id
  asks ← ((<"TX")⋈¨s.book.tx.id) ∾ (<"PLAN")⋈¨open
  same ← {bytes ≡ change.Bytes s change.Apply s change.Edit 𝕩}¨asks
  {•Out "changed by its own edit: "∾path∾" "∾∾𝕩}¨ (¬same)/asks
  ∧´same
}
10 Assert ∧´Back¨books
•Out "edits sent back: "∾•Fmt ≠books
•Out "test_view: ok"
