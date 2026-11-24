#!/usr/bin/env bqn
# bakhlo's change samples (tests/fixtures/records, scheduled): each APPLY block
# changes a book and gives the book after it byte for byte, or the refusal's code.
# Kinds of change not written yet are counted, not run.
Assert ← {𝕩 ? 1 ; •Out "test_change: FAILED" ⋄ •Exit 1}
change ← •Import "../src/change.bqn"
tab ← @+9
Split ← {m←tab=𝕩 ⋄ ((((¬m)×1++`m)-1)∾1++´m)⊔𝕩}
First ← ⊑∘Split

# ⟨folder, name, book before, change lines, answer⟩ for each APPLY block
SamplesIn ← {𝕊 dir:
  lines ← (0<≠¨)⊸/ •FLines dir∾"changes.answers"
  lines ↩ ('#'≠⊑)¨⊸/ lines
  starts‿ends‿uses ← /¨ (<First¨lines) ≡¨¨ <¨"APPLY"‿"ENDAPPLY"‿"USE"
  {𝕊 s‿e:
    book ← 2⊑Split (⊑⌽(uses<s)/uses)⊑lines
    body ← (1+s)↓e↑lines
    a ← ⊑/(First¨body)∊"AFTER"‿"REFUSED"
    ⟨dir, 1⊑Split s⊑lines, book, a↑body, Split a⊑body⟩
  }¨ starts⋈¨ends
}
samples ← ∾SamplesIn¨"fixtures/records/"‿"fixtures/scheduled/"

commands ← "PUT-ENTRY"‿"PUT-PLAN"‿"CANCEL-PLAN"‿"CORRECT-ENTRY-DATE"‿"CLASSIFY-MERCHANT"
Written ← {∧´("PUT-ENTRY"‿"NEW"≡2↑Split)¨ ((First¨∊commands˙)⊸/) 3⊑𝕩}
Passes ← {𝕊 dir‿name‿book‿c‿answer:
  r ← (change.Open •file.Bytes dir∾book) change.Apply c
  After ← {𝕊: r.ok ? (change.Bytes r) ≡ •file.Bytes dir∾1⊑answer ; 0}
  Refused ← {𝕊: r.ok ? 0 ; r.code ≡ 1⊑answer}
  ok ← ("AFTER"≡⊑answer)◶⟨Refused, After⟩ @
  {𝕊: •Out "wrong: "∾dir∾name∾" → "∾r.ok◶⟨{𝕩.code},"saved"˙⟩ r}⍟(¬ok) @
  ok
}
run ← Written¨samples
•Out "change samples: "∾(•Fmt +´run)∾" run, "∾(•Fmt +´¬run)∾" not written yet"
Assert ∧´Passes¨run/samples
•Out "test_change: ok"
