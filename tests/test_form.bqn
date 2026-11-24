#!/usr/bin/env bqn
# bakhlo's form samples (fixtures/records/forms.answers): opening an entry or a plan
# as form rows (OPEN), the entry a filled form makes (FORM), a refund (REFUND) and an
# exchange (FX), each answered as bakhlo answers it.
Assert ← {𝕩 ? 1 ; •Out "test_form: FAILED" ⋄ •Exit 1}
change ← •Import "../src/change.bqn"
form ← •Import "../src/form.bqn"
tab ← @+9
Split ← {m←tab=𝕩 ⋄ ((((¬m)×1++`m)-1)∾1++´m)⊔𝕩}
Join ← {1↓∾(tab∾⊢)¨𝕩}
First ← ⊑Split
dir ← "fixtures/records/"
lines ← ('#'≠⊑)¨⊸/ (0<≠¨)⊸/ •FLines dir∾"forms.answers"
kinds ← "OPEN"‿"FORM"‿"REFUND"‿"FX"
starts ← /(First¨lines)∊kinds
ends ← /(First¨lines)∊"END"⊸∾¨kinds
uses ← /"USE"⊸≡∘First¨lines

Said ← {(6=•Type 𝕩)◶⟨𝕩˙, {𝕊: ⟨Join "REFUSED"‿𝕩.code⟩}⟩ 𝕩}   # lines, or a refusal
Answer ← {𝕊 book‿head‿body:
  s ← change.Open •file.Bytes dir∾book
  f ← Split head
  input ← (⊑(/body≡¨<"ENDINPUT")∾≠body)↑body
  (⊑kinds⊐⊏f)◶⟨
    {𝕊: Said s.book form.Open 1↓f}
    {𝕊: r ← Said s form.Fill (1↓f)∾<input ⋄ (("PUT-ENTRY"≡First ⊑r)/⟨Join ⟨"RESULT"⟩∾1↓Split ⊑r⟩) ∾ (("PUT-ENTRY"≡First ⊑r)↓r)}
    {𝕊: Said s form.Refund 1↓f}
    {𝕊:
      day‿id‿memo ← 1↓4↑f
      legs ← {⟨𝕩⊑f, (𝕩+1)⊑f, •ParseFloat (𝕩+2)⊑f⟩}¨4‿7
      r ← form.Exchange ⟨day, id, ("-"≢memo)/memo⟩∾legs
      (6=•Type r)◶⟨{𝕊: a ← s change.Apply r ⋄ (1↓r)∾⟨a.ok◶⟨{𝕊: Join "REFUSED"‿a.code}, "ADMITTED"˙⟩ @⟩}, {𝕊: ⟨Join "REFUSED"‿r.code⟩}⟩ @
    }
  ⟩ @
}
Checked ← {𝕊 s‿e:
  book ← 2⊑Split (⊑⌽(uses<s)/uses)⊑lines
  body ← (1+s)↓e↑lines
  head ← s⊑lines
  expected ← ("FORM"≡First head)◶⟨⊢, {(1+⊑/𝕩≡¨<"ENDINPUT")↓𝕩}⟩ body
  got ← Answer book‿head‿body
  right ← expected ≡ got
  {𝕊: •Out "wrong: "∾head ⋄ •Out¨ "  got: "⊸∾¨got}⍟(¬right) @
  right
}
right ← Checked¨ starts⋈¨ends
•Out "form samples: "∾(•Fmt +´right)∾" of "∾•Fmt ≠right
Assert ∧´right
•Out "test_form: ok"
