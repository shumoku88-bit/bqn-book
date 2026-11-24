#!/usr/bin/env bqn
# Plans in series: every SERIES and SERIES-OF question in bakhlo's series samples
# (fixtures/scheduled/series.answers), answered as bakhlo answers it; and coverage
# rules, against what bk plans shows for the same book (tests/test_with_bk.sh).
Assert ← {𝕩 ? 1 ; •Out "test_series: FAILED" ⋄ •Exit 1}
change ← •Import "../src/change.bqn"
series ← •Import "../src/series.bqn"
config ← •Import "../src/config.bqn"
tab‿lf ← @+9‿10
dir ← "fixtures/scheduled/"
book ← (change.Open •file.Bytes dir∾"series.txt").book
lines ← ('#'≠⊑)¨⊸/ (0<≠¨)⊸/ •FLines dir∾"series.answers"
Head ← {(⊑(𝕩=tab)⊐1)↑𝕩}
# SERIES: the block through ENDSERIES; SERIES-OF: one line, the question its start
starts ← /("SERIES"⊸≡)¨lines
ends ← /("ENDSERIES"⊸≡)¨lines
Assert (1=≠starts) ∧ 1=≠ends
Assert (((⊑starts)+↕1+ends-○⊑starts)⊏lines) ≡ book series.Ask ⟨"SERIES"⟩
Fields ← {(((¬m)×1++`m←tab=𝕩)-1)⊔𝕩}
ofs ← ("SERIES-OF"≡Head)¨⊸/ lines
right ← {𝕩 ≡ ⊑ book series.Ask ⟨1↓∾(tab⊸∾)¨ 2↑Fields 𝕩⟩}¨ ofs
Assert ∧´right
•Out "series samples: "∾•Fmt 1+≠right

# coverage: rent is watched monthly from January; its April has no plan
rules ← config.Coverage "rent"∾tab∾"2027-01-27"∾tab∾"1"∾tab∾"bank"∾tab∾"rent"∾lf
watched ← book series.Watch rules‿"2026-11-24"‿12
p ← ⊑ book.plan.id ⊐ <"rent-2027-02"
rent ← ⊑ / {⊑(⋈p)∊𝕩}¨ series.Series book
Assert ⟨0, "2027-04"⟩ ≡ rent⊑watched
Assert ∧´ (¯1‿""⊸≡)¨ (rent≠↕≠watched)/watched
Assert "malformed" ≡ (config.Coverage "rent"∾tab∾"2027-01-27"∾tab∾"1"∾tab∾"bank"∾lf).code
Assert "malformed" ≡ (config.Coverage ∾⟨"a", tab, "2027-01-27", tab, "1", tab, "bank", tab, "rent", lf,
                                       "b", tab, "2027-01-27", tab, "1", tab, "bank", tab, "rent", lf⟩).code
Assert ⟨⟩ ≡ config.Coverage ""
•Out "test_series: ok"
