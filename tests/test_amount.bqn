#!/usr/bin/env bqn
# bakhlo's amount samples (fixtures/amounts): typed text to exact smallest units, and
# back. Three samples hold 60-digit integers, past the 2⋆53 that BQN numbers keep
# exact (bakhlo's integers have no limit): there we refuse with our too-large.
Assert ← {𝕩 ? 1 ; •Out "test_amount: FAILED" ⋄ •Exit 1}
amount ← •Import "../src/amount.bqn"
read ← •Import "../src/read.bqn"
tab ← @+9
Split ← {m←tab=𝕩 ⋄ ((((¬m)×1++`m)-1)∾1++´m)⊔𝕩}
asks ← Split¨ (0<≠¨)⊸/ •FLines "fixtures/amounts/input.answers"

Answer ← {𝕊 kind‿scale‿input:
  s ← •ParseFloat scale
  text ← read.Unescaped input
  Say ← {𝕩.ok ? ⋈0 amount.Format 𝕩.value ; "REFUSED"‿𝕩.code}
  (⊑"FORMAT"‿"POSITIVE"‿"SIGNED"⊐<kind)◶⟨
    {𝕊: ⋈s amount.Format •ParseFloat input}
    {𝕊: Say s amount.Positive text}
    {𝕊: Say s amount.Signed text}
  ⟩ @
}
big ← {∨´{15<+´𝕩∊'0'+↕10}¨𝕩}¨asks             # a 60-digit integer somewhere
right ← {(3↓𝕩) ≡ Answer 3↑𝕩}¨ (¬big)/asks
{•Out "wrong: "∾(1↓∾(tab∾⊢)¨𝕩)∾" → "∾•Fmt Answer 3↑𝕩}¨ (¬right)/(¬big)/asks
Assert ∧´right
# past our limit: refused, never rounded (FORMAT has no text to refuse; not asked)
limited ← ("FORMAT"≢⊑)¨⊸/ big/asks
Assert ∧´{⟨"REFUSED","too-large"⟩ ≡ Answer 3↑𝕩}¨limited
•Out "amount samples: "∾(•Fmt ≠right)∾" match, "∾(•Fmt ≠limited)∾" refused as too-large, "∾(•Fmt (+´big)-≠limited)∾" not asked"
•Out "test_amount: ok"
