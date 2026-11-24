# Changing a book, one change at a time, in bakhlo's change language
# (bakhlo test/records/README.md, test/scheduled/README.md). Pure: no files.
#
# A book is its text and its admitted reading: {ok⇐1, lines, book}. A change edits
# the text; reading the whole new text admits it. That is what bakhlo asks of its
# own changes ("Book_txt.change must admit exactly what reading the whole printed
# file admits"), so there is no second set of rules. Before it, bakhlo's write
# policies refuse in bakhlo's order.
#
# The change language is also how a screen asks for a change: a TUI or a GUI hands
# Apply the same lines, so screens can come and go without touching this file.
#
#   Open bytes            → a book, or the refusal of reading it
#   book Apply lines      → the changed book, or {ok⇐0, code}; all changes or none
#   Bytes book            → its bytes

read ← •Import "read.bqn"
print ← •Import "print.bqn"
tab‿lf ← @+9‿10
Fields ← read.SplitFields
ToLines ← {m←lf=𝕩 ⋄ ¯1↓((((¬m)×1++`m)-1)∾1++´m)⊔𝕩}
Refuse ← {why←𝕩 ⋄ {ok⇐0, code⇐why}}
Pad ← {𝕨↑𝕩∾𝕨⥊<""}                           # at least 𝕨 fields
Join ← {1↓∾(tab∾⊢)¨𝕩}                        # fields → a line
Kind ← ⊑Fields
Amount ← {read.IsInteger 𝕩 ? •ParseFloat 𝕩 ; 0}
# Write _unless failures: the first ⟨code, true⟩ refuses, else Write runs.
_unless ← {bad←1⊑¨𝕩 ⋄ (∨´bad)◶⟨𝔽, {Refuse ⊑⊑bad/𝕩}⟩ 𝕩}
Bytes ⇐ {•ToUTF8 ∾{𝕩∾lf}¨𝕩.lines}

# lines Session reading: the book, or the reading's refusal
Session ← {
  𝕨 𝕊 r: ¬r.ok ? r ;
  ls 𝕊 r: b ← r.book ⋄ {ok⇐1 ⋄ lines⇐ls ⋄ book⇐b}
}
Open ⇐ {(ToLines •FromUTF8⎊⟨⟩ 𝕩) Session read.Read 𝕩}

# Reading the new text decides. Its refusal names bakhlo's reason: a support line
# refuses as support-admission, anything else as entry-admission:<code>.
support ← "support-overlap"‿"duplicate-support"‿"history-unanchored"‿"empty-anchor"‿"also-redundant"‿"duplicate-also"‿"opening-missing-coordinate"
Reason ← {⊑(<𝕩.code)∊support ? Refuse "support-admission" ; Refuse "entry-admission:"∾𝕩.code}
Admit ← {r ← read.Read •ToUTF8 ∾{𝕩∾lf}¨𝕩 ⋄ 𝕩 Session Reason⍟(¬r.ok) r}

# Where things go in the text: a new TX at the end of the TX section, a PAID-BY
# just before its plan's ENDPLAN.
later ← "PLAN"‿"ZERO-ORIGIN"‿"OPENING"‿"HISTORY-FROM"‿"ANCHOR"‿"ITEM"‿"CLOSE"‿"END"
Insert ← {at‿new 𝕊 lines: (at↑lines)∾new∾at↓lines}
Swap ← {from‿to‿new 𝕊 lines: (from↑lines)∾new∾(1+to)↓lines}
# lines Span head‿id: the first and last line of that TX or PLAN block
Span ← {lines 𝕊 head‿id:
  k ← Kind¨lines
  at ← ⊑/(k≡¨<head)∧(<id)≡¨{1⊑Fields 𝕩∾tab}¨lines
  at‿(at+⊑/(at↓k)≡¨<"END"∾head)
}

# A TX that is saved again names its exchange legs: bakhlo gives an unkeyed one a
# fixed key (book.ml entry_of). → ⟨"" or a refusal's code, the block⟩
fixed ← "exchange-source"‿"exchange-destination"
Keyed ← {
  f ← 5 Pad¨Fields¨𝕩
  first‿measure‿key ← 0‿2‿4⊑¨¨<f
  x‿y ← 1‿2⊏⊑((first≡¨<"EXCHANGE")/f)∾<5⥊<""
  effect ← first≡¨<"EFFECT"
  from‿to ← (<effect)∧¨((measure≡¨<x)∧0>Amount¨3⊑¨f)‿((measure≡¨<y)∧0<Amount¨3⊑¨f)
  name ← (0=≠¨key)×from+2×to                    # 1, 2: the fixed key it gets
  code ← ⊑(⟨(0<≠x)∧∨´1≠+´¨from‿to, ∨´((name>0)/name⊏(<"")∾fixed)∊key⟩/"exchange-ambiguous"‿"exchange-key-taken")∾<""
  ⟨code, 𝕩∾¨name⊏⟨""⟩∾(tab∾⊢)¨fixed⟩
}

# PUT-ENTRY NEW <plan|->, or PUT-ENTRY REPLACE -, then a TX block. NEW adds the TX
# at the end of the TX section (and, paying a plan, a PAID-BY in it); REPLACE puts
# it in the place of the TX with its ID, which keeps the plans that it paid.
# EXCHANGE names its legs by their keys here; the book names them by Measure. The
# memo is not escaped here.
PutEntry ← {s 𝕊 replace‿plan‿block:
  b ← s.book
  f ← Fields¨block
  Of ← {((⊑¨f)≡¨<𝕩)/f}
  id‿day‿desc‿memo ← 1↓5 Pad ⊑f
  eff ← 5 Pad¨Of "EFFECT"
  el‿em‿ek ← 1‿2‿4⊑¨¨<eff
  eq ← Amount¨3⊑¨eff
  om ← 1⊑¨Of "ORIGINAL"
  t ← ⊑b.tx.id⊐⋈id                        # the TX with this ID, ≠ if none
  known ← t<≠b.tx.id
  # HIDDEN keeps a Locus out of new flows. A correction keeps the Loci its TX had,
  # and a refund may return money to the Loci of the TX it reverses.
  kept ← (b.effect.tx∊(replace/⋈t)∾b.tx.id⊐1⊑¨Of "REVERSAL-OF")/b.effect.locus
  offered ← (¬b.locus.hidden)/b.locus.id
  # a merchant, once classified, stays: its name, "" for NONMERCHANT, @ for none
  old ← ⊑((b.merchant.tx=t)/b.merchant.name)∾<@
  new ← ⊑(1⊑¨Of "MERCHANT")∾((≠Of "NONMERCHANT")⥊<"")∾<@
  paying ← plan≢"-"
  p ← ⊑b.plan.id⊐⋈plan
  # EXCHANGE <from key> <to key>: each key names one Effect; read back, the book
  # names the only negative Effect of the from Measure and the only positive one of
  # the to Measure, keyed as given (an unkeyed leg would get a fixed key).
  xs ← Of "EXCHANGE"
  ex ← 1=≠xs
  kx‿ky ← 1↓3 Pad ⊑xs∾<⟨⟩
  pointed ← ∧´{1=+´ek≡¨<𝕩}¨kx‿ky             # each key names one Effect
  mx‿my ← {⊑((ek≡¨<𝕩)/em)∾<""}¨kx‿ky
  legs ← ((em≡¨<mx)∧eq<0)‿((em≡¨<my)∧eq>0)
  unique ← ∧´1=+´¨legs
  given ← {⊑(𝕩/ek)∾<""}¨legs
  named ← fixed {0=≠𝕩 ? 𝕨 ; 𝕩}¨ given
  taken ← ∨´(0=≠¨given)∧named∊ek
  Write ← {𝕊:
    head ← {
      "DESC"≢desc ? ⊑block ;
      0=≠memo ? Join "TX"‿id‿day ;
      Join "TX"‿id‿day‿"DESC"‿(print.Escape memo)
    }
    tx ← ⟨head⟩∾{"EXCHANGE"≡Kind 𝕩 ? Join "EXCHANGE"‿mx‿my ; 𝕩}¨1↓block
    Paid ← {(1⊑𝕩 Span "PLAN"‿plan)‿⟨Join "PAID-BY"‿id⟩ Insert 𝕩}
    Add ← {𝕊: lines ← paying◶⟨⊢,Paid⟩ s.lines ⋄ Admit (⊑/(Kind¨lines)∊later)‿tx Insert lines}
    Correct ← {𝕊: Admit ((s.lines Span "TX"‿id)∾<tx) Swap s.lines}
    replace◶⟨Add, Correct⟩ @
  }
  Write _unless ⟨
    "locus-unapproved"‿(∨´¬el∊offered∾kept)
    replace⊑⟨"duplicate-entry"‿known, "unknown-entry"‿(¬known)⟩
    "merchant-classified"‿(replace ∧ (old≢@) ∧ new≢old)
    "cannot-attach-plan-on-edit"‿(replace∧paying)
    "unknown-plan"‿(paying∧p=≠b.plan.id)
    "plan-already-paid"‿(paying∧⊑(⋈p)∊b.paid.plan)
    "plan-cancelled"‿(paying∧⊑(⋈p)∊b.cancelled.plan)
    "invalid-entry-id"‿(0=≠id)
    "measure-scale-not-supplied"‿(¬∧´(em∾om)∊b.measure.id)
    "entry-admission:bad-date"‿(¬read.IsDate day)
    "entry-admission:exchange-key"‿(ex∧¬pointed)
    "entry-admission:exchange-ambiguous"‿(ex∧pointed∧¬unique)
    "exchange-key-taken"‿(ex∧pointed∧unique∧taken)
    "entry-not-representable"‿(ex∧pointed∧unique∧named≢kx‿ky)
  ⟩
}

# CORRECT-ENTRY-DATE <TX ID> <date>: only the date changes, so Loci no longer
# offered for new entries stay.
CorrectDate ← {s 𝕊 id‿day:
  Write ← {𝕊:
    from‿to ← s.lines Span "TX"‿id
    code‿block ← Keyed {Join day⌾(2⊸⊑) Fields 𝕩}⌾⊑ (from+↕1+to-from)⊏s.lines
    (0<≠code)◶⟨{𝕊: Admit from‿to‿block Swap s.lines}, {𝕊: Refuse code}⟩ @
  }
  Write _unless ⟨
    "invalid-entry-id"‿(0=≠id)
    "invalid-date"‿(¬read.IsDate day)
    "unknown-entry"‿(¬⊑(⋈id)∊s.book.tx.id)
  ⟩
}

# CLASSIFY-MERCHANT <TX ID> MERCHANT <name> | NONMERCHANT: once only. The name
# arrives escaped (\t \r \n \\) and must be one token.
Classify ← {s 𝕊 id‿how‿name:
  name ↩ read.IsText◶⟨""˙, read.Unescaped⟩ name      # a bad escape is no token
  tx ← ⊑s.book.tx.id⊐⋈id
  line ← ("MERCHANT"≡how)◶⟨"NONMERCHANT"˙, {𝕊: "MERCHANT"∾tab∾name}⟩ @
  Write ← {𝕊:
    from‿to ← s.lines Span "TX"‿id
    old ← (from+↕1+to-from)⊏s.lines
    code‿block ← Keyed (⊑/(Kind¨old)∊"EXCHANGE"‿"ENDTX")‿⟨line⟩ Insert old
    (0<≠code)◶⟨{𝕊: Admit from‿to‿block Swap s.lines}, {𝕊: Refuse code}⟩ @
  }
  Write _unless ⟨
    "merchant-kind"‿(¬⊑(⋈how)∊"MERCHANT"‿"NONMERCHANT")   # ours: bakhlo has no sample
    "merchant-unknown"‿(tx=≠s.book.tx.id)
    "merchant-classified"‿(⊑(⋈tx)∊s.book.merchant.tx)
    "merchant-token"‿(("MERCHANT"≡how) ∧ (0=≠name) ∨ ∨´name∊" "∾@+9‿10‿13)
  ⟩
}

# One change: its command line and the lines of its block.
Change ← {s 𝕊 c:
  command ← Fields ⊑c
  ("PUT-ENTRY"≡⊑command) ∧ ⊑(⋈1⊑command∾<"")∊"NEW"‿"REPLACE" ? s PutEntry ⟨"REPLACE"≡1⊑command, 2⊑3 Pad command, 1↓c⟩ ;
  s 𝕊 c:
  command ← 3 Pad Fields ⊑c
  "CORRECT-ENTRY-DATE"≡⊑command ? s CorrectDate 1↓command ;
  s 𝕊 c:
  command ← 4 Pad Fields ⊑c
  "CLASSIFY-MERCHANT"≡⊑command ? s Classify 1↓command ;
  Refuse "unsupported-change:"∾⊑Fields ⊑𝕩
}

commands ← "PUT-ENTRY"‿"PUT-PLAN"‿"CANCEL-PLAN"‿"CORRECT-ENTRY-DATE"‿"CLASSIFY-MERCHANT"
Apply ⇐ {s 𝕊 lines:
  starts ← (⊑∘Fields¨lines)∊commands
  changes ← (¯1++`starts)⊔lines
  Run ← {0=≠𝕩 ? 𝕨 ; ¬𝕨.ok ? 𝕨 ; (𝕨 Change ⊑𝕩) 𝕊 1↓𝕩}
  s Run changes
}
