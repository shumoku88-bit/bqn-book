# From typed text to exact money, as bakhlo reads it (household/amount.ml; the
# rules and samples in bakhlo test/amounts). A Measure's scale says how many
# decimal places its smallest unit has: 123 is 123 yen at scale 0, 1.23 at scale 2.
#
#   scale Positive text   an amount to record: a decimal, or + - * / and ( ) over
#                         decimals, computed exactly; only the result must be a
#                         positive whole number of smallest units
#   scale Signed text     a signed decimal (no expression); zero allowed
#   scale Format n        n smallest units as a decimal, sign kept, no grouping
#
# Positive and Signed give {ok⇐1, value} or {ok⇐0, code}: invalid-amount,
# amount-precision, non-positive-amount, division-by-zero, indivisible-amount,
# empty-amount; and ours, too-large, past the 2⋆53 that BQN numbers hold exactly
# (bakhlo's integers have no limit). Pure.

print ← •Import "print.bqn"
result ← •Import "result.bqn"
Refuse ← result.Refuse
Valued ← {v←𝕩 ⋄ {ok⇐1, value⇐v}}
digit ← '0'+↕10
exact ← 2⋆53

# Full-width digits, punctuation, operators, parentheses and space, and × ÷, are
# typing conveniences: write them the ASCII way. Anything else stays, to be refused.
wide‿narrow ← "０１２３４５６７８９，．＋－＊／（）×÷　"‿"0123456789,.+-*/()*/ "
Normal ← {i←wide⊐𝕩 ⋄ ((i<≠wide)/i⊏narrow∾' ')⌾((i<≠wide)⊸/)𝕩}

# A refusal travels as its code (text); F _then x gives it on, or applies F.
IsCode ← result.IsCode
_then ← result._then

# Digits with optional grouping: 1,234,567 but not 12,34 or 1234,567. → digits or 0
Whole ← {
  m ← ','=𝕩
  groups ← ((((¬m)×1++`m)-1)∾1++´m)⊔𝕩
  first ← ≠⊑groups∾<""
  grouped ← (∧´3=≠¨1↓groups) ∧ (1≤first) ∧ 3≥first   # only when there are commas
  (∧´𝕩∊digit∾',') ∧ (0<≠𝕩) ∧ (¬∨´m) ∨ grouped ? ∾groups ; 0
}

# A decimal → ⟨its digits, how many follow the point⟩, or a code
Decimal ← {
  p ← '.'=𝕩
  parts ← ((((¬p)×1++`p)-1)∾1++´p)⊔𝕩
  w ← Whole ⊑parts
  fraction ← ∾1↓parts
  bad ← (2<≠parts) ∨ (0≡w) ∨ (2=≠parts) ∧ (0=≠fraction) ∨ ¬∧´fraction∊digit
  bad◶⟨⟨w∾fraction, ≠fraction⟩˙, "invalid-amount"˙⟩ @
}
Int ← {15<≠𝕩 ? "too-large" ; •ParseFloat 𝕩}     # at most 15 digits: exact

# Rationals ⟨numerator, denominator⟩: reduced, the denominator positive.
Gcd ← {𝕩=0 ? 𝕨 ; 𝕩 𝕊 𝕩|𝕨}
Q ← {𝕊 n‿d: ∨´exact≤|n‿d ? "too-large" ; 𝕊 n‿d: (×d)×n‿d÷(|n)Gcd|d}
Op ← {
  a‿b 𝕊 o‿c‿d: (o='/')∧c=0 ? "division-by-zero" ;
  a‿b 𝕊 o‿c‿d: Q ⊑(o="+-*/")/⟨⟨(a×d)+c×b, b×d⟩, ⟨(a×d)-c×b, b×d⟩, ⟨a×c, b×d⟩, ⟨a×d, b×c⟩⟩
}
Literal ← {𝕊 d‿places: {Q 𝕩‿(10⋆places)}_then Int d}_then Decimal

# An expression: split at its last operator outside parentheses, sums before
# products, so each side groups to the left; no unary sign. Spaces may stand between
# parts. Both sides are read, and the left one's refusal wins, as in bakhlo's
# left-to-right parser.
Trim ← {(+´∧`' '=𝕩)↓(-+´∧`' '=⌽𝕩)↓𝕩}
Expr ← {
  s ← Trim 𝕩
  depth ← +`('('=s)-')'=s
  Last ← {¯1⊑¯1∾/(depth=0)∧s∊𝕩}                  # ¯1 if none
  plus‿times ← Last¨"+-"‿"*/"
  Bin ← {k←𝕩 ⋄ r←Expr (k+1)↓s ⋄ {l←𝕩 ⋄ {l Op (k⊑s)∾𝕩}_then r}_then Expr k↑s}
  wrapped ← (2≤≠s) ∧ ('('=⊑s∾' ') ∧ (')'=¯1⊑' '∾s) ∧ ∧´0<¯1↓depth
  case ← ⊑/⟨0=≠s, plus≥0, times≥0, wrapped, 1⟩
  case◶⟨"invalid-amount"˙, {𝕊: Bin plus}, {𝕊: Bin times}, {𝕊: Expr 1↓¯1↓s}, {𝕊: Literal s}⟩ @
}

# A literal on its own keeps its precision: at scale 2, 1.000 is refused.
Quanta ← {scale 𝕊 s:
  {𝕊 d‿places: places>scale ? "amount-precision" ; 𝕊 d‿places: Int d∾(scale-places)⥊'0'}_then Decimal s
}

Settled ← {IsCode 𝕩 ? Refuse 𝕩 ; Valued 𝕩}   # a code leaves as a refusal

Positive ⇐ {scale 𝕊 text:
  s ← Normal text
  Money ← {𝕊 n‿d: n≤0 ? "non-positive-amount" ; 𝕊 n‿d: {1≠1⊑𝕩 ? "indivisible-amount" ; ⊑𝕩}_then Q ⟨n×10⋆scale, d⟩}
  Calculated ← {𝕊: 4096<≠•ToUTF8 s ? "invalid-amount" ; Money _then Expr s}
  Written ← {𝕊: {𝕩≤0 ? "non-positive-amount" ; 𝕩}_then scale Quanta s}
  Settled (∨´s∊"+-*/()")◶⟨Written, Calculated⟩ @
}

# Outer ASCII whitespace goes; then an ASCII sign, then a decimal. Zero is allowed;
# a full-width sign is not.
Signed ⇐ {scale 𝕊 text:
  white ← " "∾@+9‿10‿11‿12‿13
  t ← (+´∧`text∊white)↓(-+´∧`(⌽text)∊white)↓text
  0=≠t ? Refuse "empty-amount" ;
  scale 𝕊 text:
  white ← " "∾@+9‿10‿11‿12‿13
  t ← (+´∧`text∊white)↓(-+´∧`(⌽text)∊white)↓text
  minus ← '-'=⊑t
  body ← (⊑(1↑t)∊"+-")↓t
  Settled {(¯1⋆minus)×𝕩}_then scale Quanta Normal body
}

Format ⇐ {scale 𝕊 n:
  digits ← print.Int |n
  digits ↩ ((0⌈scale+1-≠digits)⥊'0')∾digits
  ((n<0)/"-") ∾ (scale=0)◶⟨{𝕊: ((-scale)↓digits)∾"."∾(-scale)↑digits}, digits˙⟩ @
}
