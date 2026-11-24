# Today's spending guide (Daily Pace), its restatement on a past day, and what moved
# the pool each day, as bakhlo computes them (household/book.ml; the rules in
# bakhlo test/scheduled/README.md). Pure.
#
#   book Pace measure‿pool‿observed‿end      → {ok⇐1, balances, plans, drains,
#   book Past measure‿pool‿day‿end              available, days, daily} or {ok⇐0, code}
#   book Activity measure‿pool              → {days, values}: per day that moved,
#                                              DISCRETIONARY-OUT/IN, SCHEDULED-OUT/IN,
#                                              PROTECTION-RELEASED
#   book Ask lines                          → the answer lines, in bakhlo's question
#                                              language (PACE, PAST, ACTIVITY with POOL)
#
# pool: the Loci counted, in the asked order. end is excluded. Amounts are integers
# in the Measure's smallest unit.

read ← •Import "read.bqn"
balance ← •Import "balance.bqn"
Refuse ← {why←𝕩 ⋄ {ok⇐0, code⇐why}}
_unless ← {bad←1⊑¨𝕩 ⋄ (∨´bad)◶⟨𝔽, {Refuse ⊑⊑bad/𝕩}⟩ 𝕩}

# A date as a day count (proleptic Gregorian), so that days subtract.
Ordinal ← {
  y‿m‿d ← •ParseFloat¨ '-' ((⊢-˜¬×+`)∘=⊔⊢) 𝕩
  y -↩ m≤2
  era ← ⌊y÷400
  yoe ← y-400×era
  doy ← (⌊(2+153×m+(m≤2)⊑¯3‿9)÷5)+d-1
  (146097×era)+doy+(365×yoe)+(⌊yoe÷4)-⌊yoe÷100
}

# What each plan takes out of the pool: the net of its changes on the pool's Loci,
# when negative. A move between pool Loci nets to zero; a planned inflow takes nothing.
Drains ← {b 𝕊 pool: 0⌈-+´¨(b.change.plan∾≠b.plan.id)⊔(b.change.locus∊pool)×b.change.amount}

# The plans the guide sets money aside for, in book order: in the Measure, due
# before the end, never cancelled (a cancellation counts on every day), owed, and
# draining the pool. → ⟨plan indices, their drains⟩
Protected ← {b 𝕊 measure‿pool‿end‿owed:
  drain ← b Drains pool
  keep ← (b.plan.measure≡¨<measure) ∧ ((Ordinal end)>Ordinal¨b.plan.day) ∧ (¬(↕≠b.plan.id)∊b.cancelled.plan) ∧ owed ∧ drain>0
  ⟨/keep, keep/drain⟩
}

# The guide from a pool's total: what is left after the protected plans, per day.
Guide ← {b 𝕊 measure‿pool‿from‿end‿owed‿total‿each:
  ids‿taken ← b Protected measure‿pool‿end‿owed
  n ← end -○Ordinal from
  left ← total-+´taken
  {ok⇐1 ⋄ balances⇐each ⋄ pooled⇐total ⋄ plans⇐ids⊏b.plan.id ⋄ amounts⇐taken ⋄ available⇐left ⋄ days⇐n ⋄ daily⇐⌊left÷n}
}

Horizon ← {from‿end: "daily-pace-non-positive-horizon"‿(0≥end -○Ordinal from)}
# the first Locus of the pool with a reason, in pool order: ⟨its code, whether any⟩
FirstOf ← {measure‿pool 𝕊 codes: c ← ⊑((0<≠¨codes)/codes{𝕨∾𝕩∾":"∾measure}¨pool)∾<"" ⋄ c‿(0<≠c)}

# Today's balances already hold every recorded payment: only open plans are owed.
Pace ⇐ {b 𝕊 measure‿pool‿observed‿end:
  known ← b balance.Balances pool⋈¨<measure
  Write ← {𝕊: b Guide measure‿pool‿observed‿end‿(¬(↕≠b.plan.id)∊b.paid.plan)‿(+´known)‿known}
  Write _unless ⟨
    Horizon observed‿end
    "unknown-measure"‿(¬⊑(⋈measure)∊b.measure.id)
    "daily-pace-duplicate-coordinate"‿(¬∧´∊pool)
    measure‿pool FirstOf (@≡¨known)⊑¨<""‿"daily-pace-balance-support-unknown:"
  ⟩
}

# A past day's pool, restated from today's book: a ZERO-ORIGIN sums the Effects
# recorded through that day; a HISTORY-FROM takes today's count less what came
# after it. A paid plan stays protected until the day it was paid; a cancelled one
# never is.
Past ⇐ {b 𝕊 measure‿pool‿day‿end:
  e ← b.effect
  After ← {(Ordinal day) < Ordinal¨ 𝕩⊏b.tx.day}
  Sum ← {+´((e.locus≡¨<𝕩)∧e.measure≡¨<measure)×e.amount×𝕨}
  At ← {𝕩.locus⋈¨𝕩.measure}
  coords ← pool⋈¨<measure
  zero ← coords∊At b.zeroOrigin
  start ← (At b.historyFrom)⊐coords
  bounded ← start<≠b.historyFrom.day
  count ← {@≡𝕩 ? 0 ; 𝕩}¨ b balance.Balances coords
  early ← bounded ∧ (1+Ordinal day) < Ordinal¨ start⊏b.historyFrom.day∾<"0001-01-01"
  asserted ← coords∊At b.assert
  # per Locus, the reason it cannot be restated (bakhlo walks the pool in order)
  reasons ← "history-support-missing:"‿"history-precedes-bounded-start:"‿"history-bounded-anchor-missing:"‿""
  why ← {⊑(𝕩∾1)/reasons}¨ <˘⍉>⟨(¬bounded)∧¬zero, bounded∧early, bounded∧(¬early)∧¬asserted⟩
  later ← After e.tx
  restated ← +´ bounded ⊑¨ ((<¬later) Sum¨ pool) ⋈¨ count - (<later) Sum¨ pool
  paidLater ← (Ordinal day) < Ordinal¨ (b.tx.id⊐b.paid.tx)⊏b.tx.day
  owed ← (¬(↕≠b.plan.id)∊b.paid.plan) ∨ (↕≠b.plan.id)∊paidLater/b.paid.plan
  Write ← {𝕊: b Guide measure‿pool‿day‿end‿owed‿restated‿⟨⟩}
  Write _unless ⟨
    "unknown-measure"‿(¬⊑(⋈measure)∊b.measure.id)
    "history-duplicate-coordinate"‿(¬∧´∊pool)
    measure‿pool FirstOf why
    Horizon day‿end
  ⟩
}

# What moved the pool on each day. A TX counts by its net on the pool, so a move
# inside the pool is quiet. A TX that pays a plan, or reverses such a payment, is
# scheduled; the rest is discretionary. A reversal recorded on its target's day
# cancels both out. The day a plan is paid also releases what it had protected.
categories ⇐ "DISCRETIONARY-OUT"‿"DISCRETIONARY-IN"‿"SCHEDULED-OUT"‿"SCHEDULED-IN"‿"PROTECTION-RELEASED"
Activity ⇐ {b 𝕊 measure‿pool:
  e‿t‿r ← b.effect‿b.tx‿b.reversal
  delta ← +´¨(e.tx∾≠t.id)⊔((e.locus∊pool)∧e.measure≡¨<measure)×e.amount
  paying ← t.id∊b.paid.tx
  target ← t.id⊐r.target
  scheduled ← paying ∨ (↕≠t.id)∊(target⊏paying∾0)/r.tx
  same ← (r.tx⊏t.day) ≡¨ target⊏t.day∾<""
  moving ← (delta≠0) ∧ ¬(↕≠t.id)∊(same/r.tx)∾same/target
  # the plans paid in this Measure that protected part of the pool
  drain ← b Drains pool
  released ← ((b.paid.plan⊏b.plan.measure)≡¨<measure) ∧ 0<b.paid.plan⊏drain
  day ← (moving/t.day) ∾ released/(t.id⊐b.paid.tx)⊏t.day
  kind ← (moving/(2×scheduled)+delta>0) ∾ 4¨released/b.paid.plan
  amount ← (|moving/delta) ∾ released/b.paid.plan⊏drain
  days ← ∧⍷day
  {days⇐days ⋄ values⇐(≠days)‿5⥊+´¨((kind+5×days⊐day)∾5×≠days)⊔amount}
}

# Questions and answers as bakhlo's samples write them: a question is its head line
# and POOL lines; the answer follows and ends with END<kind>.
tab ← @+9
Join ← {1↓∾(tab∾⊢)¨𝕩}
Int ← {𝕩<0 ? "-"∾𝕊-𝕩 ; 𝕩<10 ? ⋈'0'+𝕩 ; (𝕊⌊𝕩÷10)∾'0'+10|𝕩}
Ask ⇐ {b 𝕊 lines:
  head‿pool ← ⟨read.SplitFields ⊑lines, 1⊑¨read.SplitFields¨1↓lines⟩
  kind ← ⊑head
  Guided ← {
    ¬𝕩.ok ? ⟨Join "REFUSED"‿𝕩.code⟩ ;
    g ← 𝕩
    ∾⟨
      ("PACE"≡kind)◶⟨⟨Join "RESTATED"‿(Int g.pooled)⟩˙, {𝕊: pool {Join "BALANCE"‿𝕨‿(Int 𝕩)}¨ g.balances}⟩ @
      g.plans {Join "DEDUCTION"‿𝕨‿(Int 𝕩)}¨ g.amounts
      ⟨Join "AVAILABLE"‿(Int g.available), Join "DAYS"‿(Int g.days), Join "DAILY"‿(Int g.daily)⟩
    ⟩
  }
  Moved ← {
    OnDay ← {⟨Join "ON"‿𝕨⟩ ∾ (0≠𝕩)/categories {Join 𝕨‿(Int 𝕩)}¨ 𝕩}
    ∾ 𝕩.days OnDay¨ <˘𝕩.values
  }
  answer ← (⊑"PACE"‿"PAST"‿"ACTIVITY"⊐<kind)◶⟨
    {𝕊: Guided b Pace (1⊑head)‿pool‿(2⊑head)‿(3⊑head)}
    {𝕊: Guided b Past (1⊑head)‿pool‿(2⊑head)‿(3⊑head)}
    {𝕊: Moved b Activity (1⊑head)‿pool}
    {𝕊: ⟨Join "REFUSED"‿"unknown-question"⟩}
  ⟩ @
  lines ∾ answer ∾ ⟨"END"∾kind⟩
}
