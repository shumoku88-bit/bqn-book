#!/usr/bin/env bqn
# bk's settings: the cycle that holds a day, for every CYCLE question in bakhlo's
# period samples (fixtures/periods); and the guide's accounts from daily-pace.tsv.
Assert ← {𝕩 ? 1 ; •Out "test_config: FAILED" ⋄ •Exit 1}
config ← •Import "../src/config.bqn"
tab‿lf ← @+9‿10
Split ← {m←tab=𝕩 ⋄ ((((¬m)×1++`m)-1)∾1++´m)⊔𝕩}
dir ← "fixtures/periods/"
CycleAsks ← {𝕊 file:
  lines ← Split¨ (0<≠¨)⊸/ •FLines dir∾file
  use ← (<"-") {0=≠𝕩 ? 𝕨 ; ⊑𝕩}` {"USE"≡⊑𝕩 ? ⋈2⊑𝕩 ; ⟨⟩}¨lines   # the file in use
  (("CYCLE"≡⊑)¨lines) / use ⋈¨ lines
}
asks ← ∾CycleAsks¨ (".answers"≡¯8⊸↑)¨⊸/ •file.List dir
Answer ← {𝕊 presets‿line:
  day ← 1⊑line
  text ← ("-"≡presets)◶⟨{𝕊: •FChars dir∾presets}, @˙⟩ @
  r ← text config.Cycle day
  r.ok◶⟨{𝕊: "REFUSED"‿r.code}, {𝕊: r.name‿r.start‿r.end}⟩ @
}
right ← {(2↓1⊑𝕩) ≡ Answer 𝕩}¨asks
{•Out "wrong: "∾(1↓∾(tab∾⊢)¨1⊑𝕩)∾" → "∾•Fmt Answer 𝕩}¨ (¬right)/asks
Assert ∧´right
•Out "cycle samples: "∾•Fmt ≠right

pool ← "jpy" config.Pool "# the guide's accounts"∾lf∾"wallet"∾tab∾"jpy"∾lf∾" bank"∾tab∾"jpy "∾lf
Assert pool ≡ "wallet"‿"bank"
Assert "other-measure" ≡ ("jpy" config.Pool "cash"∾tab∾"usd"∾lf).code
Assert "malformed" ≡ ("jpy" config.Pool "cash"∾lf).code
Assert "not-configured" ≡ ("jpy" config.Pool @).code
•Out "test_config: ok"
