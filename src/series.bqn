# Plans in series, as bakhlo groups them (household/schedule.ml; samples in bakhlo
# test/scheduled/series.answers). A series is not stored: it is the open plans of
# one Measure that move between the same accounts the same way (which pay, which
# receive), whatever their amounts. Rent paid every month from the bank is one
# series; the same rent paid once from the wallet is another. Pure.
#
#   Series book            → the open plans (indices) in series: series by their
#                            first day, plans by day then ID
#   book SeriesOf id       → the series holding plan id, or {ok⇐0, code⇐"source-not-open"}
#   Shapes book            → per plan, ⟨accounts paid from, accounts received by⟩,
#                            each sorted, each once
#   Simple book            → per plan, its amount when it is two rows between two
#                            accounts, or @ (a split plan)
#   book Watch rules‿today‿months
#                          → per series, ⟨its coverage rule's index or ¯1, the
#                            first month that rule expects and nothing fills, or ""⟩
#   Slot anchor‿every‿k    → the k-th day every so many months after anchor: its
#                            day of the month kept, or ⟨"MISSING", year-month, day⟩
#                            when that month has no such day (a person dates it),
#                            or "NONE" outside the calendar
#   s More source‿days‿ids → the change adding plans like the open plan source, on
#                            those days with those IDs, or {ok⇐0, code}
#   book Reprice plans‿q   → a batch amount change: the plans (indices) whose
#                            amount becomes q, or {ok⇐0, code}: split-plan:<id>,
#                            unchanged
#   s Repriced plans‿q     → the change that does it (PUT-PLAN REPLACE each), or a code
#   book Ask lines         → the answer lines (SERIES, SERIES-OF, SLOT, AMOUNT), as
#                            the samples say

read ← •Import "read.bqn"
change ← •Import "change.bqn"
tab ← @+9
print ← •Import "print.bqn"
Join ← print.Join
Int ← print.Int
result ← •Import "result.bqn"
Refuse ← result.Refuse
_unless ← result._unless
_either_ ← result._either_
Unpaid ← {b←𝕩 ⋄ ¬(↕≠b.plan.id)∊b.paid.plan∾b.cancelled.plan}   # open: neither paid nor cancelled

Shapes ⇐ {
  b ← 𝕩
  n ← ≠b.plan.id
  Side ← {k←𝕩 ⋄ ∧∘⍷¨ ¯1↓ ((k/b.change.plan)∾n) ⊔ (k/b.change.locus)∾<""}
  (Side b.change.amount<0) ⋈¨ Side b.change.amount>0
}

Series ⇐ {
  b ← 𝕩
  order ← ⍋ b.plan.day ⋈¨ b.plan.id
  open ← ((Unpaid b)⊏˜order) / order
  (⊐ open ⊏ b.plan.measure ⋈¨ Shapes b) ⊔ open
}

SeriesOf ⇐ {b 𝕊 id:
  p ← ⊑b.plan.id⊐⋈id
  ¬(p<≠b.plan.id) ∧ p⊑(Unpaid b)∾0 ? Refuse "source-not-open" ;
  b 𝕊 id:
  p ← ⊑b.plan.id⊐⋈id
  ⊑ {⊑(⋈p)∊𝕩}¨⊸/ Series b
}

Simple ⇐ {
  b ← 𝕩
  n ← ≠b.plan.id
  rows ← ¯1↓ (b.change.plan∾n) ⊔ (b.change.locus⋈¨b.change.amount)∾<⟨"",0⟩
  {(2=≠𝕩) ∧ (≢´⊑¨𝕩) ∧ 0>×´1⊑¨𝕩 ? ⌈´1⊑¨𝕩 ; @}¨ rows
}

# Coverage rules (scheduled-coverage.tsv, read in config.bqn) watch a series by
# its accounts and expect a plan every so many months from an anchor's month. A
# month is missing when it is expected and no open or paid plan of that shape
# falls in it. Months are counted from today's, as bk plans counts them.
Month ← {(12×•ParseFloat 4↑𝕩) + (•ParseFloat 2↑5↓𝕩) - 1}
MonthText ← {y‿m←(⌊𝕩÷12)‿(12|𝕩) ⋄ ∾⟨¯4↑"000"∾•Fmt y, "-", ¯2↑"0"∾•Fmt m+1⟩}
Watch ⇐ {b 𝕊 rules‿today‿months:
  shaped ← Shapes b
  # each rule's shape: ⟨paid from, received by⟩, as Shapes gives a plan's
  watching ← {𝕩.negative⋈𝕩.positive}¨rules
  counted ← ¬(↕≠b.plan.id)∊b.cancelled.plan        # open or paid
  span ← (Month today) + ↕months
  Missing ← {𝕊 r:
    filled ← Month¨ (counted ∧ shaped ≡¨ <r⊑watching) / b.plan.day
    rule ← r⊑rules
    every ← rule.every
    expected ← (every>0) ∧ (span ≥ Month rule.anchor) ∧ 0 = (1⌈every) | span - Month rule.anchor
    gaps ← (expected ∧ ¬span∊filled) / span
    (0<≠gaps)◶⟨"", {𝕊: MonthText ⊑gaps}⟩ @
  }
  {𝕊 s: r ← ⊑ watching ⊐ <(⊑s)⊑shaped ⋄ (r<≠rules)◶⟨¯1‿"", {𝕊: r ⋈ Missing r}⟩ @}¨ Series b
}

# Filling the coming months: the k-th occurrence keeps the anchor's day, never
# clamped to another day (household/schedule.ml slot).
Slot ⇐ {𝕊 anchor‿every‿k:
  m ← (Month anchor) + k×every
  y ← ⌊m÷12
  day ← •ParseFloat 8↓anchor
  date ← (MonthText m)∾"-"∾¯2↑"0"∾•Fmt day
  (y<1) ∨ y>9999 ? "NONE" ;
  𝕊 anchor‿every‿k:
  m ← (Month anchor) + k×every
  date ← (MonthText m)∾"-"∾8↓anchor
  read.IsDate date ? date ;
  𝕊 anchor‿every‿k:
  ⟨"MISSING", MonthText (Month anchor) + k×every, •Fmt •ParseFloat 8↓anchor⟩
}

More ⇐ {s 𝕊 source‿days‿ids:
  b ← s.book
  p ← ⊑b.plan.id⊐⋈source
  Copies ← {𝕊:
    rows ← 2↓ s change.Edit "PLAN"‿source       # its CHANGE lines and ENDPLAN
    ∾ days {⟨Join "PUT-PLAN"‿"NEW", Join "PLAN"‿𝕩‿𝕨‿(p⊑b.plan.measure)⟩ ∾ rows}¨ ids
  }
  Copies _unless ⟨"source-not-open"‿(¬(p<≠b.plan.id) ∧ p⊑(Unpaid b)∾0)⟩
}

# A price change: every chosen two-row plan gets the new amount, each account's
# sign kept; a plan already at it is left out. A split plan is refused: no
# allocation is guessed (household/schedule.ml change_amount).
Reprice ⇐ {b 𝕊 plans‿q:
  amounts ← plans ⊏ Simple b
  split ← (@≡¨amounts)/plans
  changed ← (q≢¨amounts)/plans
  {𝕊: changed} _unless ⟨
    ("split-plan:"∾⊑(split⊏b.plan.id)∾<"")‿(0<≠split)
    "unchanged"‿(0=≠changed)
  ⟩
}
# each changed plan's rows: its accounts, the new amount with their signs
NewRows ← {b 𝕊 p‿q: c ← /b.change.plan=p ⋄ (c⊏b.change.locus) ⋈¨ q×× c⊏b.change.amount}
Repriced ⇐ {s 𝕊 plans‿q:
  b ← s.book
  Block ← {p ← 𝕩 ⋄ ∾⟨
    ⟨Join "PUT-PLAN"‿"REPLACE", Join "PLAN"‿(p⊑b.plan.id)‿(p⊑b.plan.day)‿(p⊑b.plan.measure)⟩
    {Join "CHANGE"‿(⊑𝕩)‿(Int 1⊑𝕩)}¨ b NewRows p‿q
    ⟨"ENDPLAN"⟩
  ⟩}
  ∾∘(Block¨) _either_ ⊢ b Reprice plans‿q
}

# The samples' questions: SERIES lists every series as GROUP lines; SERIES-OF
# names a plan's series.
Ask ⇐ {b 𝕊 lines:
  head ← read.SplitFields ⊑lines
  Of ← {𝕊:
    ⟨Join ⟨"SERIES-OF", 1⊑head⟩ ∾ {𝕩⊏b.plan.id} _either_ {"REFUSED"‿𝕩.code} b SeriesOf 1⊑head⟩
  }
  Slotted ← {𝕊:
    r ← Slot (1⊑head)‿(•ParseFloat 2⊑head)‿(•ParseFloat 3⊑head)
    ⟨Join (4↑head) ∾ (2=≡r)⊑⟨⋈r, r⟩⟩
  }
  Priced ← {𝕊:
    ids ← 1⊑¨ (("PLAN"≡⊑)¨⊸/ read.SplitFields¨ 1↓lines)
    q ← •ParseFloat 1⊑head
    Plan ← {p←𝕩 ⋄ Join ⟨"PLAN", p⊑b.plan.id⟩ ∾ ∾{(⊑𝕩)‿(Int 1⊑𝕩)}¨ b NewRows p‿q}
    Plan¨ _either_ {⟨Join "REFUSED"‿𝕩.code⟩} b Reprice (b.plan.id⊐ids)‿q
  }
  (⊑"SERIES"‿"SERIES-OF"‿"SLOT"‿"AMOUNT"⊐<⊑head)◶⟨
    {𝕊: ⟨"SERIES"⟩ ∾ ({Join ⟨"GROUP"⟩∾𝕩⊏b.plan.id}¨ Series b) ∾ ⟨"ENDSERIES"⟩}
    Of
    Slotted
    Priced
    {𝕊: ⟨Join "REFUSED"‿"unknown-question"⟩}
  ⟩ @
}
