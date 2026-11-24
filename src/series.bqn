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
#   book Ask lines         → the answer lines (SERIES, SERIES-OF, SLOT), as the
#                            samples say

read ← •Import "read.bqn"
change ← •Import "change.bqn"
tab ← @+9
Join ← {1↓∾(tab∾⊢)¨𝕩}
Refuse ← {why←𝕩 ⋄ {ok⇐0, code⇐why}}
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
  ((p<≠b.plan.id) ∧ p⊑(Unpaid b)∾0)◶⟨{𝕊: Refuse "source-not-open"}, Copies⟩ @
}

# The samples' questions: SERIES lists every series as GROUP lines; SERIES-OF
# names a plan's series.
Ask ⇐ {b 𝕊 lines:
  head ← read.SplitFields ⊑lines
  Of ← {𝕊:
    r ← b SeriesOf 1⊑head
    ⟨Join ⟨"SERIES-OF", 1⊑head⟩ ∾ (6=•Type r)◶⟨{𝕊: r⊏b.plan.id}, {𝕊: "REFUSED"‿r.code}⟩ @⟩
  }
  Slotted ← {𝕊:
    r ← Slot (1⊑head)‿(•ParseFloat 2⊑head)‿(•ParseFloat 3⊑head)
    ⟨Join (4↑head) ∾ (2=≡r)⊑⟨⋈r, r⟩⟩
  }
  (⊑"SERIES"‿"SERIES-OF"‿"SLOT"⊐<⊑head)◶⟨
    {𝕊: ⟨"SERIES"⟩ ∾ ({Join ⟨"GROUP"⟩∾𝕩⊏b.plan.id}¨ Series b) ∾ ⟨"ENDSERIES"⟩}
    Of
    Slotted
    {𝕊: ⟨Join "REFUSED"‿"unknown-question"⟩}
  ⟩ @
}
