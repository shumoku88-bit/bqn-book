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
slots ← ("SLOT"≡Head)¨⊸/ lines
slotted ← {𝕩 ≡ ⊑ book series.Ask ⟨1↓∾(tab⊸∾)¨ 4↑Fields 𝕩⟩}¨ slots
{•Out "wrong: "∾𝕩}¨ (¬slotted)/slots
Assert ∧´slotted
# AMOUNT: the question through ENDINPUT, the answer through ENDAMOUNT
amounts ← /("AMOUNT"≡Head)¨lines
Answered ← {
  input ← ⊑/(<"ENDINPUT")≡¨𝕩↓lines
  done ← ⊑/(<"ENDAMOUNT")≡¨𝕩↓lines
  (((𝕩+1+input)+↕done-input+1)⊏lines) ≡ book series.Ask (𝕩+↕input)⊏lines
}
priced ← Answered¨ amounts
Assert ∧´priced
•Out "series samples: "∾•Fmt (1+≠right)+(≠slotted)+≠priced

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
# more: plans like the last rent, on the days given, with the IDs given
s ← change.Open •file.Bytes dir∾"series.txt"
more ← s series.More "rent-2027-03"‿⟨"2027-04-27", "2027-05-27"⟩‿⟨"rent-a", "rent-b"⟩
Assert more ≡ ⟨"PUT-PLAN"∾tab∾"NEW", ∾⟨"PLAN", tab, "rent-a", tab, "2027-04-27", tab, "jpy"⟩, "CHANGE"∾tab∾"bank"∾tab∾"-80000", "CHANGE"∾tab∾"rent"∾tab∾"80000", "ENDPLAN",
               "PUT-PLAN"∾tab∾"NEW", ∾⟨"PLAN", tab, "rent-b", tab, "2027-05-27", tab, "jpy"⟩, "CHANGE"∾tab∾"bank"∾tab∾"-80000", "CHANGE"∾tab∾"rent"∾tab∾"80000", "ENDPLAN"⟩
Assert (s change.Apply more).ok
Assert "source-not-open" ≡ (s series.More "rent-2027-01"‿⟨"2027-04-27"⟩‿⟨"x"⟩).code
# the change that reprices: each plan in its place, signs kept
priced2 ← s series.Repriced (book.plan.id⊐"phone-2027-01"‿"phone-2027-02")‿3300
Assert priced2 ≡ ⟨"PUT-PLAN"∾tab∾"REPLACE", ∾⟨"PLAN", tab, "phone-2027-01", tab, "2027-01-25", tab, "jpy"⟩, "CHANGE"∾tab∾"bank"∾tab∾"-3300", "CHANGE"∾tab∾"phone"∾tab∾"3300", "ENDPLAN"⟩
Assert (s change.Apply priced2).ok
•Out "test_series: ok"
