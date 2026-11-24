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
result ← •Import "result.bqn"
Refuse ← result.Refuse
Pad ← {𝕨↑𝕩∾𝕨⥊<""}                           # at least 𝕨 fields
Join ← print.Join
Kind ← ⊑Fields
Amount ← {read.IsInteger 𝕩 ? •ParseFloat 𝕩 ; 0}
# Write _unless failures: the first ⟨code, true⟩ refuses, else Write runs.
_unless ← result._unless
Bytes ⇐ {•ToUTF8 ∾{𝕩∾lf}¨𝕩.lines}

# lines Session reading: the book, or the reading's refusal
Session ← {
  𝕨 𝕊 r: ¬r.ok ? r ;
  ls 𝕊 r: b ← r.book ⋄ {ok⇐1 ⋄ lines⇐ls ⋄ book⇐b}
}
Open ⇐ {(ToLines •FromUTF8⎊⟨⟩ 𝕩) Session read.Read 𝕩}

# Reading the new text decides: Why _admitted lines. Its refusal names bakhlo's
# reason (household/book.ml): a support line refuses as support-admission; for a TX,
# entry-admission:<code>; for a plan, an empty, zero or unbalanced movement is
# invalid-plan-movement and anything else entry-admission.
support ← "support-overlap"‿"duplicate-support"‿"history-unanchored"‿"empty-anchor"‿"also-redundant"‿"duplicate-also"‿"opening-missing-coordinate"
Of3 ← {⊑(<𝕨.code)∊𝕩}
ForEntry ← {𝕩 Of3 support ? Refuse "support-admission" ; Refuse "entry-admission:"∾𝕩.code}
ForBook ← {𝕩 Of3 support ? Refuse "support-admission" ; Refuse "entry-admission"}
ForPlan ← {𝕩 Of3 "no-effect"‿"zero-amount"‿"unbalanced" ? Refuse "invalid-plan-movement" ; ForBook 𝕩}
_admitted ← {r ← read.Read •ToUTF8 ∾{𝕩∾lf}¨𝕩 ⋄ 𝕩 Session 𝔽⍟(¬r.ok) r}
Admit ← ForEntry _admitted

# Where things go in the text: a new TX at the end of the TX section, a PAID-BY
# just before its plan's ENDPLAN.
later ← "PLAN"‿"ZERO-ORIGIN"‿"OPENING"‿"HISTORY-FROM"‿"ANCHOR"‿"ITEM"‿"CLOSE"‿"END"
EndOf ← {⊑/(Kind¨𝕩)∊𝕨}                        # sections EndOf lines: where they begin
Insert ← {at‿new 𝕊 lines: (at↑lines)∾new∾at↓lines}
Swap ← {from‿to‿new 𝕊 lines: (from↑lines)∾new∾(1+to)↓lines}
# lines Span head‿id: the first and last line of that TX or PLAN block
Span ← {lines 𝕊 head‿id:
  k ← Kind¨lines
  at ← ⊑/(k≡¨<head)∧(<id)≡¨{1⊑Fields 𝕩∾tab}¨lines
  at‿(at+⊑/(at↓k)≡¨<"END"∾head)
}

# A TX that is saved again names its exchange legs: bakhlo gives an unkeyed one a
# fixed key (book.ml entry_of). → ⟨"" or a refusal's code, the block, the legs' keys⟩
fixed ← "exchange-source"‿"exchange-destination"
Keyed ← {
  f ← 5 Pad¨Fields¨𝕩
  first‿measure‿key ← 0‿2‿4⊑¨¨<f
  x‿y ← 1‿2⊏⊑((first≡¨<"EXCHANGE")/f)∾<5⥊<""
  effect ← first≡¨<"EFFECT"
  from‿to ← (<effect)∧¨((measure≡¨<x)∧0>Amount¨3⊑¨f)‿((measure≡¨<y)∧0<Amount¨3⊑¨f)
  name ← (0=≠¨key)×from+2×to                    # 1, 2: the fixed key it gets
  code ← ⊑(⟨(0<≠x)∧∨´1≠+´¨from‿to, ∨´((name>0)/name⊏(<"")∾fixed)∊key⟩/"exchange-ambiguous"‿"exchange-key-taken")∾<""
  legs ← fixed {0=≠𝕩 ? 𝕨 ; 𝕩}¨ {⊑(𝕩/key)∾<""}¨from‿to
  ⟨code, 𝕩∾¨name⊏⟨""⟩∾(tab∾⊢)¨fixed, legs⟩
}

# PUT-ENTRY NEW <plan|->, or PUT-ENTRY REPLACE -, then a TX block. NEW adds the TX
# at the end of the TX section (and, paying a plan, a PAID-BY in it); REPLACE puts
# it in the place of the TX with its ID, which keeps the plans that it paid.
# EXCHANGE names its legs by their keys here; the book names them by Measure. The
# memo is written as in book.txt (\t, \n, \\ escaped), so a line stays a line; an
# empty memo is no memo.
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
      ⊑block
    }
    tx ← ⟨head⟩∾{"EXCHANGE"≡Kind 𝕩 ? Join "EXCHANGE"‿mx‿my ; 𝕩}¨1↓block
    Paid ← {(1⊑𝕩 Span "PLAN"‿plan)‿⟨Join "PAID-BY"‿id⟩ Insert 𝕩}
    Add ← {𝕊: lines ← paying◶⟨⊢,Paid⟩ s.lines ⋄ Admit (later EndOf lines)‿tx Insert lines}
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
    code‿block‿· ← Keyed {Join day⌾(2⊸⊑) Fields 𝕩}⌾⊑ (from+↕1+to-from)⊏s.lines
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
    code‿block‿· ← Keyed (⊑/(Kind¨old)∊"EXCHANGE"‿"ENDTX")‿⟨line⟩ Insert old
    (0<≠code)◶⟨{𝕊: Admit from‿to‿block Swap s.lines}, {𝕊: Refuse code}⟩ @
  }
  Write _unless ⟨
    "merchant-kind"‿(¬⊑(⋈how)∊"MERCHANT"‿"NONMERCHANT")   # ours: bakhlo has no sample
    "merchant-unknown"‿(tx=≠s.book.tx.id)
    "merchant-classified"‿(⊑(⋈tx)∊s.book.merchant.tx)
    "merchant-token"‿(("MERCHANT"≡how) ∧ (0=≠name) ∨ ∨´name∊" "∾@+9‿10‿13)
  ⟩
}

# PUT-PLAN NEW|REPLACE, then a PLAN block: an open plan, added at the end of the
# PLAN section or put in the place of the open plan with its ID.
PutPlan ← {s 𝕊 replace‿block:
  b ← s.book
  f ← Fields¨block
  id‿day‿measure ← 1↓4 Pad ⊑f
  p ← ⊑b.plan.id⊐⋈id
  known ← p<≠b.plan.id
  Write ← {𝕊:
    Add ← {𝕊: ((1↓later) EndOf s.lines)‿block Insert s.lines}
    Correct ← {𝕊: ((s.lines Span "PLAN"‿id)∾<block) Swap s.lines}
    ForPlan _admitted replace◶⟨Add, Correct⟩ @
  }
  Write _unless ⟨
    "plan-terminal-not-input"‿(∨´(⊑¨f)∊"PAID-BY"‿"CANCELLED")
    replace⊑⟨"duplicate-plan"‿known, "unknown-plan"‿(¬known)⟩
    "plan-already-paid"‿(replace∧⊑(⋈p)∊b.paid.plan)
    "plan-cancelled"‿(replace∧⊑(⋈p)∊b.cancelled.plan)
    "locus-unapproved"‿(∨´¬(1⊑¨((⊑¨f)≡¨<"CHANGE")/f)∊(¬b.locus.hidden)/b.locus.id)
    "invalid-plan-id"‿(0=≠id)
    "invalid-date"‿(¬read.IsDate day)
    "measure-scale-not-supplied"‿(¬⊑(⋈measure)∊b.measure.id)
  ⟩
}

# CANCEL-PLAN <plan ID> <date>: an open plan ends, CANCELLED on that day.
CancelPlan ← {s 𝕊 id‿day:
  b ← s.book
  p ← ⊑b.plan.id⊐⋈id
  Write ← {𝕊: ForBook _admitted (1⊑s.lines Span "PLAN"‿id)‿⟨Join "CANCELLED"‿day⟩ Insert s.lines}
  Write _unless ⟨
    "unknown-plan"‿(p=≠b.plan.id)
    "plan-already-paid"‿(⊑(⋈p)∊b.paid.plan)
    "plan-cancelled"‿(⊑(⋈p)∊b.cancelled.plan)
    "invalid-date"‿(¬read.IsDate day)
  ⟩
}

# Accounts, as bk loci adds, names and gives them a role (household/book.ml
# add_locus, set_locus_label, role_refusal; cli/locus_roles.ml). bakhlo's change
# samples have none, so these commands are ours, named after its Book changes, and
# refuse with its codes; invalid-role is ours. The role samples are bakhlo's
# (test/loci).
#   ADD-LOCUS <id>                 offered for new entries, named by its ID until
#                                  named; a hidden account is offered again
#   SET-LOCUS-LABEL <id> <name>    the name (escaped, as a memo is); a description
#                                  already written stays, else it is the name too
#   SET-ROLE <id> ASSET|LIABILITY|EQUITY|INCOME|EXPENSE
#                                  once only; the ROLE lines are kept by account
LocusAt ← {lines 𝕊 id: ⊑/((Kind¨lines)≡¨<"LOCUS")∧(<id)≡¨{1⊑Fields 𝕩∾tab}¨lines}
OfferedLoci ← {(¬𝕩.locus.hidden)/𝕩.locus.id}
ForLocus ← {𝕊: Refuse "invalid-locus"}

AddLocus ← {s 𝕊 ⟨id⟩:
  b ← s.book
  Write ← {𝕊:
    Unhide ← {𝕊: at ← s.lines LocusAt id ⋄ ⟨at, at, ⟨Join 4↑Fields at⊑s.lines⟩⟩ Swap s.lines}
    Add ← {𝕊: (("ROLE"‿"TX"∾later) EndOf s.lines)‿⟨Join "LOCUS"‿id‿(print.Escape id)‿""⟩ Insert s.lines}
    ForLocus _admitted (⊑(⋈id)∊b.locus.id)◶⟨Add, Unhide⟩ @
  }
  Write _unless ⟨
    "invalid-locus"‿(0=≠id)
    "duplicate-locus"‿(⊑(⋈id)∊OfferedLoci b)
  ⟩
}

LabelLocus ← {s 𝕊 id‿name:
  b ← s.book
  white ← " "∾@+9‿10‿12‿13
  label ← read.IsText◶⟨""˙, read.Unescaped⟩ name      # a bad escape is no name
  label ↩ (+´∧`label∊white)↓(-+´∧`(⌽label)∊white)↓label
  Valid ← {(0<≠𝕩) ∧ (80≥≠•ToUTF8 𝕩) ∧ ∧´(𝕩≥@+32)∧𝕩≠@+127}
  Write ← {𝕊:
    at ← s.lines LocusAt id
    old ← 3⊑4 Pad Fields at⊑s.lines
    help ← (0<≠old)◶⟨print.Escape label, old⟩ @       # written as it was
    ForBook _admitted ⟨at, at, ⟨Join "LOCUS"‿id‿(print.Escape label)‿help⟩⟩ Swap s.lines
  }
  Write _unless ⟨
    "invalid-locus"‿(0=≠id)
    "locus-not-approved"‿(¬⊑(⋈id)∊OfferedLoci b)
    "invalid-label"‿(¬Valid label)
  ⟩
}

roleNames ← "ASSET"‿"LIABILITY"‿"EQUITY"‿"INCOME"‿"EXPENSE"
SetRole ← {s 𝕊 id‿name:
  b ← s.book
  Write ← {𝕊:
    rest ← ((Kind¨s.lines)≢¨<"ROLE")/s.lines
    loci ← b.role.locus∾<id
    roles ← (⍋loci) ⊏ loci {Join "ROLE"‿𝕨‿𝕩}¨ b.role.name∾<name
    {Refuse 𝕩.code} _admitted ((⟨"TX"⟩∾later) EndOf rest)‿roles Insert rest
  }
  Write _unless ⟨
    "suspense-no-role"‿("suspense"≡id)
    "role-already-set"‿(⊑(⋈id)∊b.role.locus)
    "invalid-role"‿(¬⊑(⋈name)∊roleNames)
  ⟩
}

# The change that would put an entry or a plan back as it is: where a screen's
# edit starts. An entry's EXCHANGE names its legs' keys, as a change does.
#   book Edit "TX"‿id | "PLAN"‿id → the change's lines, or {ok⇐0, code}
Edit ⇐ {s 𝕊 head‿id:
  isTx ← "TX"≡head
  Show ← {𝕊:
    from‿to ← s.lines Span head‿id
    block ← (from+↕1+to-from)⊏s.lines
    AsPlan ← {𝕊: ⟨Join "PUT-PLAN"‿"REPLACE"⟩∾block}
    AsTx ← {𝕊:
      code‿withKeys‿legs ← Keyed block
      Back ← {𝕊: ⟨Join "PUT-ENTRY"‿"REPLACE"‿"-"⟩ ∾ {"EXCHANGE"≡Kind 𝕩 ? Join ⟨"EXCHANGE"⟩∾legs ; 𝕩}¨withKeys}
      (0<≠code)◶⟨Back, {𝕊: Refuse code}⟩ @
    }
    isTx◶⟨AsPlan, AsTx⟩ @
  }
  Show _unless ⟨(isTx⊑"unknown-plan"‿"unknown-entry")‿(¬⊑(⋈id)∊isTx⊑s.book.plan.id‿s.book.tx.id)⟩
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
  s 𝕊 c:
  command ← 3 Pad Fields ⊑c
  ("PUT-PLAN"≡⊑command) ∧ ⊑(⋈1⊑command)∊"NEW"‿"REPLACE" ? s PutPlan ⟨"REPLACE"≡1⊑command, 1↓c⟩ ;
  s 𝕊 c:
  command ← 3 Pad Fields ⊑c
  "CANCEL-PLAN"≡⊑command ? s CancelPlan 1↓command ;
  s 𝕊 c:
  command ← 3 Pad Fields ⊑c
  "ADD-LOCUS"≡⊑command ? s AddLocus 1↑1↓command ;
  s 𝕊 c:
  command ← 3 Pad Fields ⊑c
  "SET-LOCUS-LABEL"≡⊑command ? s LabelLocus 1↓command ;
  s 𝕊 c:
  command ← 3 Pad Fields ⊑c
  "SET-ROLE"≡⊑command ? s SetRole 1↓command ;
  Refuse "unsupported-change:"∾⊑Fields ⊑𝕩
}

commands ← "PUT-ENTRY"‿"PUT-PLAN"‿"CANCEL-PLAN"‿"CORRECT-ENTRY-DATE"‿"CLASSIFY-MERCHANT"‿"ADD-LOCUS"‿"SET-LOCUS-LABEL"‿"SET-ROLE"
Apply ⇐ {s 𝕊 lines:
  starts ← (⊑∘Fields¨lines)∊commands
  changes ← (¯1++`starts)⊔lines
  Run ← {0=≠𝕩 ? 𝕨 ; ¬𝕨.ok ? 𝕨 ; (𝕨 Change ⊑𝕩) 𝕊 1↓𝕩}
  s Run changes
}
