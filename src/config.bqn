# bk's settings that sit next to the book (in config/ when that holds the file):
# which accounts today's guide spends from, and the household's cycles. Read
# as bakhlo reads them (cli/pace.ml, household/period.ml; samples in bakhlo
# test/periods). Pure: the caller gives each file's text, or @ when it is missing.
#
#   measure Pool text      daily-pace.tsv → the accounts, or {ok⇐0, code}
#   View text              balance-view.tsv → the balances to show, locus‿measure
#                          each, in order, or {ok⇐0, code}: not-configured, malformed
#   text Cycle day         boundary-presets.tsv → {ok⇐1, name, start, end} for the
#                          window holding day (end excluded), or {ok⇐0, code}:
#                          not-configured, malformed, no-cycle:<day>, ambiguous:<day>

read ← •Import "read.bqn"
tab‿lf‿cr ← @+9‿10‿13
Refuse ← {why←𝕩 ⋄ {ok⇐0, code⇐why}}
Split ← {sep 𝕊 s: m←sep=s ⋄ ((((¬m)×1++`m)-1)∾1++´m)⊔s}
Trim ← {w←𝕩∊" "∾tab‿cr ⋄ (+´∧`w)↓(-+´∧`⌽w)↓𝕩}
# a file's lines that say something: trimmed, neither blank nor a # comment
Said ← {('#'≢⊑)¨⊸/ (0<≠¨)⊸/ Trim¨ lf Split 𝕩}
Token ← {(0<≠𝕩) ∧ ∧´(𝕩>@+32)∧𝕩≠@+127}
DayNumber ← {•ParseFloat 𝕩/˜'-'≠𝕩}              # a real date as a number that orders
_unless ← {bad←1⊑¨𝕩 ⋄ (∨´bad)◶⟨𝔽, {Refuse ⊑⊑bad/𝕩}⟩ 𝕩}
Lines ← {(@≢𝕩)◶⟨⟨⟩˙, {𝕊: tab Split¨ Said 𝕩}⟩ 𝕩}   # a missing file says nothing

# daily-pace.tsv: one account and the guide's Measure per line
Pool ⇐ {measure 𝕊 text:
  rows ← Lines text
  {𝕊: ⊑¨rows} _unless ⟨
    "not-configured"‿(@≡text)
    "malformed"‿(∨´{(2≠≠𝕩) ∨ ¬∧´Token¨𝕩}¨rows)
    "other-measure"‿(∨´{measure≢1⊑𝕩∾<""}¨rows)
    "duplicate"‿(¬∧´∊⊑¨rows)
    "empty"‿(0=≠rows)
  ⟩
}

# balance-view.tsv: bk writes it, one account and Measure per line, nothing else;
# any other line refuses the whole file (bakhlo cli/balance_view_data.ml)
View ⇐ {
  # one final newline ends the last line; an empty file shows nothing
  Coordinates ← {body ← (-⊑lf∊¯1↑𝕩)↓𝕩 ⋄ (0<≠body)◶⟨⟨⟩˙, {𝕊: tab⊸Split¨ lf Split body}⟩ @}
  rows ← (@≢𝕩)◶⟨⟨⟩˙, Coordinates⟩ 𝕩
  {𝕊: rows} _unless ⟨
    "not-configured"‿(@≡𝕩)
    "malformed"‿(∨´{(2≠≠𝕩) ∨ ¬∧´Token¨𝕩}¨rows)
  ⟩
}

# boundary-presets.tsv: a name and two or more increasing days per preset; two
# neighbouring days are a window, its start in, its end out. A day's cycle is the
# window holding it, when exactly one preset has one.
Cycle ⇐ {text 𝕊 day:
  rows ← Lines text
  dates ← 1↓¨rows
  Dated ← {(2≤≠𝕩) ∧ ∧´read.IsDate¨𝕩 ? ∧´0<-˜´˘2↕DayNumber¨𝕩 ; 0}
  formed ← (∧´Token¨⊑¨rows) ∧ (∧´∊⊑¨rows) ∧ ∧´Dated¨dates
  n ← DayNumber day
  Window ← {i←+´n≥DayNumber¨𝕩 ⋄ (0<i)∧i<≠𝕩 ? i-1 ; ¯1}   # where day falls, ¯1 outside
  windows ← formed◶⟨(≠rows)⥊¯1˙, Window¨⟩ dates
  hits ← /windows≥0
  Found ← {𝕊: r←(⊑hits)⊑rows ⋄ w←1+(⊑hits)⊑windows ⋄ {ok⇐1 ⋄ name⇐⊑r ⋄ start⇐w⊑r ⋄ end⇐(w+1)⊑r}}
  Found _unless ⟨
    "not-configured"‿(@≡text)
    "malformed"‿(¬formed)
    ("no-cycle:"∾day)‿(0=≠hits)
    ("ambiguous:"∾day)‿(1<≠hits)
  ⟩
}
