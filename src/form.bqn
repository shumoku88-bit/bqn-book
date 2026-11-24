# The Record form: what a person fills in, and the entry it makes, as bakhlo does
# it (household/record.ml, day.ml; samples in bakhlo test/records/forms.answers).
# One Measure, rows of an account and a signed amount (an expression allowed); the
# book still decides what may be saved. Pure.
#
#   book Open "ENTRY"‿id | "PLAN"‿id → the form: MEASURE, then ROW key|- locus amount
#   book Fill mode‿target‿id‿lines   → the change that records it (RESULT line and
#                                       TX), or {ok⇐0, code}
#       mode NEW (target -), EDIT (target: the entry), PAY (target: the plan);
#       lines: DAY, MEMO, MEASURE, ROW key|- locus ±amount, optional ORIGINAL m quanta
#   book Refund target‿day‿id        → the refund's TX, or a code
#   book Exchange day‿id‿memo‿from‿to → the exchange's TX and whether the book admits it
#
# Text arrives as typed (a memo is not escaped); the TX lines are book.txt's.

read ← •Import "read.bqn"
print ← •Import "print.bqn"
amount ← •Import "amount.bqn"
change ← •Import "change.bqn"
tab ← @+9
Join ← {1↓∾(tab∾⊢)¨𝕩}
Refuse ← {why←𝕩 ⋄ {ok⇐0, code⇐why}}
IsCode ← {2=•Type ⊑𝕩∾0}
_then ← {IsCode 𝕩 ? 𝕩 ; 𝔽 𝕩}
_unless ← {bad←1⊑¨𝕩 ⋄ (∨´bad)◶⟨𝔽, {Refuse ⊑⊑bad/𝕩}⟩ 𝕩}

# ---- days ----

# A typed day: Y-M-D, Y/M/D or Y.M.D (one kind of separator, twice), full-width
# digits and separators allowed, a four-digit year, one- or two-digit month and day.
wide‿narrow ← "０１２３４５６７８９／．－"‿"0123456789/.-"
TypedDay ⇐ {
  t ← {i←wide⊐𝕩 ⋄ (((i<≠wide)/i)⊏narrow)⌾((i<≠wide)⊸/)𝕩} 𝕩
  counts ← +´¨(<t)=¨"-/."
  sep ← ⊑((2=counts)/"-/.")∾' '
  parts ← (((¬m)×1++`m←sep=t)-1)⊔t
  digits ← ∧´¨(<'0'+↕10)∊˜¨parts
  ok ← (1=+´0<counts) ∧ (2=+´counts) ∧ (3=≠parts) ∧ (∧´digits) ∧ (4=≠⊑parts) ∧ ∧´(1≤≠¨1↓parts)∧2≥≠¨1↓parts
  Pad ← {(-𝕨)↑(𝕨⥊'0')∾𝕩}
  canonical ← ok◶⟨"", {𝕊: 1↓∾('-'∾⊢)¨4‿2‿2 Pad¨ parts}⟩ @
  (ok ∧ read.IsDate canonical)◶⟨"invalid-date"˙, canonical˙⟩ @
}

# ---- the book's rows ----

TxOf ← {b 𝕊 id: ⊑b.tx.id⊐⋈id}                  # ≠ if none
ScaleOf ← {b 𝕊 m: ⊑(b.measure.scale∾¯1)⊏˜b.measure.id⊐⋈m}   # ¯1 if none
Rows ← {𝕊 b‿measure‿keys‿loci‿amounts:
  s ← b ScaleOf measure
  ⟨Join "MEASURE"‿measure⟩ ∾ {Join ⟨"ROW"⟩∾𝕩}¨ <˘⍉>⟨{0=≠𝕩 ? "-" ; 𝕩}¨keys, loci, s amount.Format¨ amounts⟩
}

# An entry opens unless an exchange or a refund links it, and only in one Measure;
# a plan opens while it is open.
Open ⇐ {b 𝕊 kind‿id:
  "PLAN"≡kind ? {𝕊:
    p ← ⊑b.plan.id⊐⋈id
    c ← b.change.plan=p
    Rows b‿(p⊑b.plan.measure)‿((+´c)⥊<"")‿(c/b.change.locus)‿(c/b.change.amount)
  }_unless ⟨
    "unknown-plan"‿(¬⊑(⋈id)∊b.plan.id)
    "plan-already-paid"‿(⊑(⋈⊑b.plan.id⊐⋈id)∊b.paid.plan)
    "plan-cancelled"‿(⊑(⋈⊑b.plan.id⊐⋈id)∊b.cancelled.plan)
  ⟩ ;
  b 𝕊 kind‿id:
  t ← b TxOf id
  e ← b.effect.tx=t
  {𝕊: Rows b‿(⊑e/b.effect.measure)‿(e/b.effect.key)‿(e/b.effect.locus)‿(e/b.effect.amount)} _unless ⟨
    "unknown-entry"‿(t=≠b.tx.id)
    "linked-entry"‿((⊑(⋈t)∊b.exchange.tx∾b.reversal.tx) ∨ ⊑(⋈id)∊b.reversal.target)
    "single-measure-movement-required"‿(1≠≠⍷e/b.effect.measure)
  ⟩
}

# ---- filling it in ----

# A row's amount: an ASCII sign for its direction, then a positive amount (an
# expression allowed) in the Measure's smallest units.
RowAmount ← {scale 𝕊 text:
  scale<0 ? "unknown-measure" ;
  scale 𝕊 text:
  r ← scale amount.Positive (⊑(1↑text)∊"+-")↓text
  r.ok◶⟨{𝕊: r.code}, {𝕊: (¯1⋆'-'=⊑text∾' ')×r.value}⟩ @
}

# The entry a form makes, checked in bakhlo's order: day, rows, the original's
# Measure, balance; then the book (admission:<its code>). EDIT keeps the entry's ID,
# its links, original and merchant, and a row's key only where the entry had that
# key on that account; PAY makes a new entry that pays the plan.
Fill ⇐ {s 𝕊 mode‿target‿id‿lines:
  b ← s.book
  f ← 4⊸{𝕨↑𝕩∾𝕨⥊<""}¨ read.SplitFields¨lines
  Of ← {((⊑¨f)≡¨<𝕩)/f}
  day‿measure ← {⊑(1⊑¨Of 𝕩)∾<""}¨"DAY"‿"MEASURE"
  memo ← ⊑({(1+⊑𝕩⊐tab)↓𝕩}¨("MEMO"∾tab)⊸{𝕨≡(≠𝕨)↑𝕩}¨⊸/lines)∾<""   # all after MEMO and a tab
  keys‿loci‿texts ← 1‿2‿3⊑¨¨<Of "ROW"
  originals ← Of "ORIGINAL"
  edit ← "EDIT"≡mode
  t ← b TxOf target
  day ↩ TypedDay day
  quanta ← (b ScaleOf measure) RowAmount¨ texts
  bad ← IsCode¨quanta
  Row ← {"postings:row-"∾(•Fmt 1+𝕨)∾": "∾𝕩}
  # EDIT: the old entry's keys stay only on their own accounts
  old ← (b.effect.tx=t)/b.effect.key⋈¨b.effect.locus
  keys ↩ edit◶⟨{0=≠𝕩 ? "" ; "-"≡𝕩 ? "" ; 𝕩}¨, {((𝕩⋈¨loci)∊old) {𝕨 ? 𝕩 ; ""}¨ 𝕩}⟩ keys
  Write ← {𝕊:
    tx ← ⟨Join ⟨"TX", edit⊑id‿target, day⟩ ∾ (0<≠memo)/⟨"DESC", print.Escape memo⟩⟩
    tx ∾↩ {Join ⟨"EFFECT", 𝕨, measure, print.Int 1⊑𝕩⟩ ∾ (0<≠⊑𝕩)/⋈⊑𝕩}´¨ loci ⋈¨ keys ⋈¨ quanta
    Links ← {𝕊:                          # what EDIT keeps: links, original, merchant
      old ← 1↓¯1↓ s change.Edit "TX"‿target
      ((⊑∘read.SplitFields¨old)∊"REVERSAL-OF"‿"ORIGINAL"‿"MERCHANT"‿"NONMERCHANT"‿"EXCHANGE")/old
    }
    kept ← edit◶⟨⟨⟩˙, Links⟩ @
    tx ∾↩ kept ∾ {Join 3↑𝕩}¨ (¬edit)/originals            # NEW and PAY: the original as typed
    tx ∾↩ ⟨"ENDTX"⟩
    head ← Join ⟨"PUT-ENTRY", edit⊑"NEW"‿"REPLACE", ("PAY"≡mode)⊑"-"‿target⟩
    r ← s change.Apply ⟨head⟩∾tx
    r.ok◶⟨{𝕊: Refuse "admission:"∾r.code}, (⟨head⟩∾tx)˙⟩ @
  }
  Write _unless ⟨
    "day-format"‿("invalid-date"≡day)
    "postings:posting-required"‿(0=≠quanta)
    (⊑((bad/↕≠bad) Row¨ bad/quanta)∾<"")‿(∨´bad)
    (⊑(((0=≠¨loci)/↕≠loci) Row¨ <"empty-locus")∾<"")‿(∨´0=≠¨loci)
    "original-measure"‿((¬edit) ∧ ∨´¬(1⊑¨originals)∊b.measure.id)
    "unbalanced"‿(0≠+´(¬bad)/quanta)
  ⟩
}

# A refund adds a record and never erases one: every row of the entry negated,
# linked by REVERSAL-OF, memo "Refund: <memo>" (or Refund). No original or merchant.
# A refund is not refunded, and an entry is refunded once.
Refund ⇐ {s 𝕊 target‿day‿id:
  b ← s.book
  t ← b TxOf target
  e ← b.effect.tx=t
  Write ← {𝕊:
    memo ← "Refund"∾(t⊑b.tx.hasMemo)/": "∾t⊑b.tx.memo
    negated ← (e/b.effect.measure) {⟨𝕨, print.Int -⊑𝕩⟩∾(0<≠1⊑𝕩)/1↓𝕩}¨ (e/b.effect.amount)⋈¨e/b.effect.key
    ∾⟨
      ⟨Join "TX"‿id‿day‿"DESC"‿(print.Escape memo)⟩
      (e/b.effect.locus) {Join ⟨"EFFECT", 𝕨⟩∾𝕩}¨ negated
      ⟨Join "REVERSAL-OF"‿target, "ENDTX"⟩
    ⟩
  }
  Write _unless ⟨
    "unknown-entry"‿(t=≠b.tx.id)
    "already-refund"‿(⊑(⋈t)∊b.reversal.tx)
    "already-refunded"‿(⊑(⋈target)∊b.reversal.target)
  ⟩
}

# An exchange: what left one account in one Measure and arrived in another in a
# second Measure, its legs keyed by bakhlo's fixed keys; no rate is kept.
# from and to: account‿Measure‿quanta. → the change, or a code
Exchange ⇐ {𝕊 day‿id‿memo‿from‿to:
  src‿dst ← fixed ← "exchange-source"‿"exchange-destination"
  Leg ← {key 𝕊 locus‿measure‿q: Join "EFFECT"‿locus‿measure‿(print.Int q)‿key}
  Write ← {𝕊:
    ⟨
      Join "PUT-ENTRY"‿"NEW"‿"-"
      Join ⟨"TX", id, day⟩∾(0<≠memo)/⟨"DESC", print.Escape memo⟩
      src Leg -⌾(2⊸⊑) from
      dst Leg to
      Join "EXCHANGE"‿src‿dst
      "ENDTX"
    ⟩
  }
  Write _unless ⟨
    "same-measure"‿(≡´1⊑¨from‿to)
    "non-positive-amount"‿(∨´0≥2⊑¨from‿to)
  ⟩
}
