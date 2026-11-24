# Reading bakhlo's book.txt (Common Format v0: bakhlo docs/COMMON_FORMAT.ja.md).
#
#   Read bytes → {ok⇐1, book⇐…}  or  {ok⇐0, code⇐"bad-date", line⇐7}
#
# bytes are the file's bytes as characters (•file.Bytes). A refusal names the same
# code and line as bakhlo (book_txt/book_txt.ml); tests/test_book.bqn checks
# every shared sample in tests/fixtures/common_format/. Like bakhlo, reading runs four
# stages: bytes and lines, block structure and order, field syntax, definitions and
# references. Each stage collects all of its faults; the first stage with any
# refuses with its earliest line. Faults on one line keep the order in which bakhlo
# finds them, except where OCaml leaves the order of a tuple's fields unspecified:
# there a line with two faults may name a different code (never a different line).
#
# One rule of our own: an amount has at most 15 digits ("too-large"). BQN numbers
# are exact integers only up to 2⋆53, and this keeps every amount exact.

tab‿lf‿cr ← @+9‿10‿13

# ---- refusals ----

# A fault is ⟨code, line, order⟩. The earliest line wins; on one line, the lowest
# order, which is the one bakhlo finds first.
Refusal ← {c‿l‿· ← (⊑⍋1‿2⊸⊏¨𝕩)⊑𝕩 ⋄ {ok⇐0, code⇐c, line⇐l}}
# value Next _gate faults: refuse with the earliest fault, or go on with the value.
_gate ← {0<≠𝕩 ? Refusal 𝕩 ; 𝔽 𝕨}
# code Report lines‿order: one fault per line, all with the same order;
# codes Coded lines‿order: the lines whose code is not "".
Report ← {c 𝕊 l‿o: {⟨c,𝕩,o⟩}¨l}
Coded ← {c 𝕊 l‿o: (0<≠¨c)/c {⟨𝕨,𝕩,o⟩}¨ l}

# ---- field syntax ----

Split ← {sep 𝕊 s: m←sep=s ⋄ ((((¬m)×1++`m)-1)∾1++´m) ⊔ s}
Token ← {(0<≠𝕩) ∧ ¬∨´𝕩∊' '∾cr}
# YYYY-MM-DD, a real date in year 1 or later
Date ← {
  10≠≠𝕩 ? 0 ;
  shape ← "dddd-dd-dd"
  ¬∧´((𝕩∊'0'+↕10) = 'd'=shape) ∧ (𝕩='-') = '-'=shape ? 0 ;
  y‿m‿d ← •ParseFloat¨ '-' Split 𝕩
  leap ← ((0=4|y)∧0≠100|y) ∨ 0=400|y
  (y≥1) ∧ (1≤d) ∧ d ≤ (⊑(1+↕12)⊐⋈m)⊑⟨31,28+leap,31,30,31,30,31,31,30,31,30,31,0⟩
}
# "0", or an optional "-" and digits that do not start with 0.
Digits ← {('-'=⊑𝕩∾' ')↓𝕩}
Integer ← {d←Digits 𝕩 ⋄ (𝕩≡"0") ∨ (0<≠d) ∧ ('0'≠⊑d∾'0') ∧ ∧´d∊'0'+↕10}
Number ← •ParseFloat

# Text escapes are \\ \n \r \t. In a run of backslashes the even positions start
# an escape; the character after each start must be one of \nrt, and a raw CR is
# not allowed.
EscapeStarts ← {b←'\'=𝕩 ⋄ b ∧ 0=2|(↕≠𝕩)-⌈`(¬b)×1+↕≠𝕩}
TextOk ← {s←EscapeStarts 𝕩 ⋄ (¬∨´cr=𝕩) ∧ (¬¯1⊑0∾s) ∧ ∧´((»s)/𝕩)∊"\nrt"}
Unescape ← {s←EscapeStarts 𝕩 ⋄ (¬s)/(»s){𝕨 ? (lf‿cr‿tab∾'\')⊑˜⊑"nrt\"⊐⋈𝕩 ; 𝕩}¨𝕩}

# Field checks give "" or the fault's code.
Tok ← {Token 𝕩 ? "" ; "bad-token"}
Day ← {Date 𝕩 ? "" ; "bad-date"}
Amount ← {¬Integer 𝕩 ? "bad-integer" ; 15≥≠Digits 𝕩 ? "" ; "too-large"}
Scale ← {¬Integer 𝕩 ? "bad-integer" ; ⊑(⋈Number 𝕩)∊↕10 ? "" ; "bad-scale"}
Text ← {¬TextOk 𝕩 ? "bad-escape" ; 0=≠𝕩 ? "empty-text" ; ""}
Help ← {TextOk 𝕩 ? "" ; "bad-escape"}
Hidden ← {𝕩≡"HIDDEN" ? "" ; "bad-hidden"}
RoleName ← {⊑(⋈𝕩)∊"ASSET"‿"LIABILITY"‿"EQUITY"‿"INCOME"‿"EXPENSE" ? "" ; "bad-role"}
Last ← {𝕩≡"-" ? "" ; Tok 𝕩}
CloseKind ← {⊑(⋈𝕩)∊"RESOLVED"‿"DROPPED" ? "" ; "bad-close"}

# ---- line kinds ----

# 0–12 are the sections in file order (their rank), 13–23 live inside a block,
# 24–26 close one. TX, PLAN and ANCHOR open a block.
kinds ← ⟨"BOOK","MEASURE","LOCUS","ROLE","TX","PLAN","ZERO-ORIGIN","OPENING","HISTORY-FROM","ANCHOR","ITEM","CLOSE","END"
         "EFFECT","REVERSAL-OF","ORIGINAL","MERCHANT","NONMERCHANT","EXCHANGE","CHANGE","PAID-BY","CANCELLED","ALSO","ASSERT"
         "ENDTX","ENDPLAN","ENDANCHOR"⟩
KindOf ← kinds⊸⊐
Kind ← {⊑kinds⊐⋈𝕩}                     # one kind name
# Field counts each kind may have; an unknown kind has none.
arity ← ∾⟨
  ⟨2⟩‿⟨3⟩‿⟨4,5⟩‿⟨3⟩‿⟨3,5⟩‿⟨4⟩‿⟨3⟩‿⟨4⟩‿⟨4⟩‿⟨2⟩‿⟨5⟩‿⟨4⟩‿⟨1⟩
  ⟨4,5⟩‿⟨2⟩‿⟨3⟩‿⟨2⟩‿⟨1⟩‿⟨3⟩‿⟨3⟩‿⟨2⟩‿⟨2⟩‿⟨2⟩‿⟨4⟩
  ⟨1⟩‿⟨1⟩‿⟨1⟩‿⟨⟩
⟩
opens ← KindOf "TX"‿"PLAN"‿"ANCHOR"
closers ← KindOf "ENDTX"‿"ENDPLAN"‿"ENDANCHOR"
# slot: block (TX, PLAN, ANCHOR) × kind → position of the line inside that block,
# ¯1 where it does not belong. Slot 0, and ASSERT, may repeat.
slot ← > {names‿at: (at∾¯1)⊏˜(KindOf names)⊐↕≠kinds}¨ ⟨
  ⟨"EFFECT","REVERSAL-OF","ORIGINAL","MERCHANT","NONMERCHANT","EXCHANGE"⟩‿⟨0,1,2,3,3,4⟩
  ⟨"CHANGE","PAID-BY","CANCELLED"⟩‿⟨0,1,1⟩
  ⟨"ALSO","ASSERT"⟩‿⟨0,1⟩
⟩
# kind, field position, check
fieldRules ← ⟨
  "MEASURE"‿1‿tok, "MEASURE"‿2‿scale
  "LOCUS"‿1‿tok, "LOCUS"‿2‿text, "LOCUS"‿3‿help, "LOCUS"‿4‿hidden
  "ROLE"‿1‿tok, "ROLE"‿2‿roleName
  "TX"‿2‿day
  "EFFECT"‿1‿tok, "EFFECT"‿2‿tok, "EFFECT"‿3‿amount, "EFFECT"‿4‿tok
  "REVERSAL-OF"‿1‿tok, "ORIGINAL"‿1‿tok, "ORIGINAL"‿2‿amount, "MERCHANT"‿1‿tok
  "EXCHANGE"‿1‿tok, "EXCHANGE"‿2‿tok
  "PLAN"‿1‿tok, "PLAN"‿2‿day, "PLAN"‿3‿tok, "CHANGE"‿1‿tok, "CHANGE"‿2‿amount
  "PAID-BY"‿1‿tok, "CANCELLED"‿1‿day
  "ZERO-ORIGIN"‿1‿tok, "ZERO-ORIGIN"‿2‿tok
  "OPENING"‿1‿tok, "OPENING"‿2‿tok, "OPENING"‿3‿tok
  "HISTORY-FROM"‿1‿tok, "HISTORY-FROM"‿2‿tok, "HISTORY-FROM"‿3‿day
  "ANCHOR"‿1‿last, "ALSO"‿1‿tok, "ASSERT"‿1‿tok, "ASSERT"‿2‿tok, "ASSERT"‿3‿amount
  "ITEM"‿1‿tok, "ITEM"‿4‿text
  "CLOSE"‿1‿tok, "CLOSE"‿2‿day, "CLOSE"‿3‿closeKind
⟩

# ---- stage 1: bytes and lines ----

Utf8 ← {𝕊 bytes:
  Canonical ← {c←𝕩-@ ⋄ ∧´((c<55296)∨c>57343)∧c<1114112 ? bytes≡•ToUTF8 𝕩 ; 0}
  s ← •FromUTF8⎊0 bytes
  (0≡s)◶⟨Canonical,0˙⟩ s
}

Lines ← {𝕊 bytes:
  0=≠bytes ? Refusal ⟨"bad-header"‿1‿0⟩ ;
  𝕊 bytes:
  nl ← lf=bytes
  final ← ¯1⊑nl
  count ← (+´nl)+¬final
  raw ← ((((¬nl)×1++`»nl)-1)∾count) ⊔ bytes
  crlf ← {(0<≠𝕩) ∧ cr=¯1⊑' '∾𝕩}¨raw
  lines ← (-crlf)↓¨raw
  n ← 1+↕count
  lines Ends _gate ∾⟨
    (¬final)/⟨"no-final-newline"‿count‿0⟩
    "crlf" Report ⟨crlf/n, 1⟩
    "not-utf8" Report ⟨(¬Utf8¨lines)/n, 2⟩
  ⟩
}

# The first line names the format; END is the last line.
Ends ← {
  ("BOOK"∾tab∾"1") ≢ ⊑𝕩 ? Refusal ⟨"bad-header"‿1‿0⟩ ;
  (⊑𝕩⊐⟨"END"⟩) EndAt 𝕩
}
EndAt ← {
  e 𝕊 lines: e=≠lines ? Refusal ⟨"missing-end"‿(≠lines)‿0⟩ ;
  e 𝕊 lines: e<¯1+≠lines ? Refusal ⟨"after-end"‿(e+2)‿0⟩ ;
  Structure •FromUTF8¨𝕩
}

# ---- stage 2: block structure and order ----

Structure ← {𝕊 lines:
  # axis: lines 2…END
  n ← 2+↕¯1+≠lines
  f ← tab⊸Split¨1↓lines
  k ← KindOf ⊑¨f
  blank ← 0=≠¨1↓lines
  fits ← (≠¨f) {∨´𝕨=𝕩}¨ k⊏arity
  # axis: the lines that fit (v); o: the block open before each line, as an
  # index on this axis, ¯1 at the top level. A section line inside a block
  # leaves it unclosed; bakhlo stops there, so what follows does not matter.
  v ← fits∧¬blank
  kv‿nv‿fv ← v⊸/¨k‿n‿f
  Step ← {o 𝕊 j:
    kj ← j⊑kv
    top ← o<0
    open ← ⊑(⋈kj)∊opens
    closes ← (¬top) ∧ kj=(⊑opens⊐⋈(0⌈o)⊑kv)⊑closers∾¯9
    ⊑(top‿closes‿open‿1)/⟨open⊑¯1‿j, ¯1, j, o⟩
  }
  o ← ¯1»¯1 Step`↕≠kv
  top ← o<0
  block ← 2⌊⊑∘(opens⊐⋈)¨(0⌈o)⊏kv       # TX, PLAN, ANCHOR: 0, 1, 2 (meaningless at the top)
  closes ← (¬top) ∧ kv=block⊏closers
  unclosed ← (¬top) ∧ (¬closes) ∧ kv<13
  s ← (block⋈¨kv)⊑¨<slot
  inner ← (¬top) ∧ (¬closes) ∧ kv≥13
  # section order at the top level: rank never falls
  ranked ← top∧kv<13
  r ← ranked/kv
  # order inside each block: slot never falls, and repeats only where allowed
  slotted ← inner∧s≥0
  sb‿ss‿so ← slotted⊸/¨block‿s‿o
  previous ← ¯1+(so=¯2»so)×1+¯1»ss
  late ← (ss<previous) ∨ (ss=previous) ∧ ¬(ss=0)∨(sb=2)∧ss=1
  # each fault is found at its own line, except an unclosed block: found at the
  # line that leaves it open, reported at its head
  Found ← {c 𝕊 l: c Report l‿l}
  faults ← ∾⟨
    "blank-line" Found blank/n
    "unknown-line" Found (fits<¬blank)/n
    "unknown-line" Found ((top∧kv≥13) ∨ inner∧s<0)/nv
    "section-order" Found (r<0»⌈`r)/ranked/nv
    "section-order" Found late/slotted/nv
    ((0⌈unclosed/o)⊏nv) {⟨"unclosed-block",𝕨,𝕩⟩}¨ unclosed/nv
  ⟩
  # the book's lines: section lines and block lines, without END and closers;
  # h: for a block line, the index of its block's head on this axis
  keep ← (¬closes) ∧ kv≠Kind "END"
  h ← (top×↕≠kv) + (¬top)×o
  ⟨keep/nv, keep/fv, keep/kv, (keep/h)⊐˜/keep⟩ Fields _gate faults
}

# ---- stage 3: field syntax ----

Fields ← {𝕊 lines:
  n‿f‿k‿h ← lines
  Rule ← {name‿at‿Check:
    m ← (k=Kind name) ∧ at<≠¨f
    (Check¨at⊑¨m/f) Coded ⟨m/n, at⟩
  }
  # TX: the ID "-" is refused; five fields must be DESC and a memo
  tx ← k=Kind "TX"
  tf‿tn ← tx⊸/¨f‿n
  dash ← "-"⊸≡¨1⊑¨tf
  five ← (¬dash) ∧ 5=≠¨tf
  desc ← five ∧ {4<≠𝕩 ? "DESC"≡3⊑𝕩 ; 0}¨tf
  # ITEM: DUE_ON carries a date; the other two carry "-"
  item ← k=Kind "ITEM"
  due‿when ← 2‿3 ⊑¨¨ <item/f
  on ← due≡¨<"DUE_ON"
  dash2 ← when≡¨<"-"
  badDue ← (on∧dash2) ∨ (¬on) ∧ (¬due∊"NO_DUE_DATE"‿"DUE_UNDETERMINED") ∨ ¬dash2
  dated ← on>dash2
  lines References _gate ∾⟨
    ∾Rule¨fieldRules
    "bad-token" Report ⟨dash/tn, 0⟩
    "unknown-line" Report ⟨(five>desc)/tn, 0⟩
    (Tok¨1⊑¨(¬dash)/tf) Coded ⟨(¬dash)/tn, 1⟩
    (Text¨4⊑¨desc/tf) Coded ⟨desc/tn, 3⟩
    "bad-due" Report ⟨badDue/item/n, 1⟩
    "bad-date" Report ⟨(¬Date¨dated/when)/dated/item/n, 1⟩
  ⟩
}

# ---- stage 4: definitions and references ----

# Each rule is ⟨code, kind, fault⟩: fault is a mask over the lines of that kind in
# file order. A rule's place in the table is its order, so on one line the earlier
# rule gives bakhlo's code. IDs resolve to their first definition.
References ← {𝕊 lines:
  n‿f‿k‿h ← lines
  Of ← {k=Kind 𝕩}
  Col ← {kind 𝕊 i: i⊑¨(Of kind)/f}              # field i of each line of the kind
  Owner ← {head 𝕊 kind: (/Of head)⊐(Of kind)/h}  # its TX, PLAN or ANCHOR, by index
  Rows ← {<˘⍉>𝕩}                                 # aligned columns → rows
  Among ← {m 𝕊 x: (¬∊m/x)⌾(m⊸/) 0¨x}            # repeats among the items m selects
  measures‿loci‿txs‿plans‿items ← Col⟜1¨"MEASURE"‿"LOCUS"‿"TX"‿"PLAN"‿"ITEM"
  Coordinate ← {(𝕩 Col 1)⋈¨𝕩 Col 2}             # (Locus, Measure)
  # the Locus and Measure of a ZERO-ORIGIN, OPENING, ASSERT or HISTORY-FROM line
  Defined ← {⟨"unknown-locus"‿𝕩‿(¬(𝕩 Col 1)∊loci), "unknown-measure"‿𝕩‿(¬(𝕩 Col 2)∊measures)⟩}

  # TX: Effects, and the net of each (TX, Measure) that has one
  et ← "TX" Owner "EFFECT"
  el‿em ← "EFFECT"⊸Col¨1‿2
  eq ← Number¨"EFFECT" Col 3
  ek ← {5=≠𝕩 ? 4⊑𝕩 ; ""}¨(Of "EFFECT")/f
  keys ← ⍷et⋈¨em
  net ← +´¨(keys⊐et⋈¨em)⊔eq
  NetOf ← {⊑(net∾0)⊏˜keys⊐⋈𝕩}
  # EXCHANGE: from goes down, to goes up, every other Measure nets to 0
  xt ← "TX" Owner "EXCHANGE"
  xx‿xy ← "EXCHANGE"⊸Col¨1‿2
  Others ← {t‿x‿y: ∨´(0≠net)∧(t=⊑¨keys)∧¬(1⊑¨keys)∊x‿y}
  exchangeOk ← (xx≢¨xy) ∧ (0>NetOf¨xt⋈¨xx) ∧ (0<NetOf¨xt⋈¨xy) ∧ ¬Others¨Rows xt‿xx‿xy
  # REVERSAL-OF: a TX takes part in at most one reversal, on either side, and
  # reverses its target's Effects exactly (Locus, Measure, amount; keys and order aside)
  rt ← "TX" Owner "REVERSAL-OF"
  reversed ← "REVERSAL-OF" Col 1
  known ← reversed∊txs
  ends ← ∾(known/rt⊏txs)⋈¨known/reversed
  reused ← (known/reversed≡¨rt⊏txs) ∨ ∨˝˘(2÷˜≠ends)‿2⥊(⊐˜ends) < 2×⌊2÷˜↕≠ends
  byTx ← (et∾≠txs)⊔Rows el‿em‿eq
  inverse ← (∧¨(known/rt)⊏byTx) ≢¨ {∧{-⌾(2⊸⊑)𝕩}¨𝕩}¨(txs⊐known/reversed)⊏byTx
  # PLAN
  cp ← "PLAN" Owner "CHANGE"
  cq ← Number¨"CHANGE" Col 2
  changed ← (↕≠plans)∊cp
  paidTx ← "PAID-BY" Col 1
  # Support: a (Locus, Measure) has at most one of ZERO-ORIGIN, OPENING and
  # ASSERT. Claims run in file order; a repeated ZERO-ORIGIN or OPENING claims nothing.
  support ← "ZERO-ORIGIN"‿"OPENING"‿"ASSERT"
  sm ← Of¨support
  which ← (∨´sm)/+´(↕3)×sm                        # 0, 1, 2 for each support line
  sc ← (1⊸⊑⋈2⊸⊑)¨(∨´sm)/f
  overlap ← ((which=2) ∨ ∊which⋈¨sc) Among sc
  OverlapOf ← {(which=⊑support⊐⋈𝕩)/overlap}
  ot ← "OPENING" Col 3
  # ANCHOR: the position of its last TX; "-" (¯1) is before the first.
  # ALSO may not name a TX up to the one just after it.
  anchorLast ← "ANCHOR" Col 1
  dash ← anchorLast≡¨<"-"
  pointer ← dash {𝕨 ? ¯1 ; ⊑txs⊐⋈𝕩}¨ anchorLast
  aa ← "ANCHOR" Owner "ALSO"
  alsoTx ← "ALSO" Col 1
  closed ← "CLOSE" Col 1

  rules ← ∾⟨
    ⟨
      "duplicate-measure"‿"MEASURE"‿(¬∊measures)
      "duplicate-locus"‿"LOCUS"‿(¬∊loci)
      "unknown-locus"‿"ROLE"‿(¬("ROLE" Col 1)∊loci)
      "duplicate-role"‿"ROLE"‿(¬∊"ROLE" Col 1)
      "suspense-role"‿"ROLE"‿("suspense"⊸≡¨"ROLE" Col 1)
      "duplicate-tx"‿"TX"‿(¬∊txs)
      "no-effect"‿"TX"‿(¬(↕≠txs)∊et)
      "unbalanced"‿"TX"‿((¬(↕≠txs)∊xt∾rt) ∧ (↕≠txs)∊(0≠net)/⊑¨keys)
      "unknown-locus"‿"EFFECT"‿(¬el∊loci)
      "unknown-measure"‿"EFFECT"‿(¬em∊measures)
      "zero-amount"‿"EFFECT"‿(0=eq)
      "duplicate-key"‿"EFFECT"‿((0<≠¨ek) Among et⋈¨ek)
      "unknown-measure"‿"EXCHANGE"‿(¬xx∊measures)
      "unknown-measure"‿"EXCHANGE"‿(¬xy∊measures)
      "bad-exchange"‿"EXCHANGE"‿(¬exchangeOk)
      "unknown-measure"‿"ORIGINAL"‿(¬("ORIGINAL" Col 1)∊measures)
      "bad-original"‿"ORIGINAL"‿(0≥Number¨"ORIGINAL" Col 2)
      "unknown-tx"‿"REVERSAL-OF"‿(¬known)
      "reversal-reused"‿"REVERSAL-OF"‿(reused⌾(known⊸/) 0¨known)
      "reversal-not-inverse"‿"REVERSAL-OF"‿(inverse⌾(known⊸/) 0¨known)
      "duplicate-plan"‿"PLAN"‿(¬∊plans)
      "unknown-measure"‿"PLAN"‿(¬("PLAN" Col 3)∊measures)
      "no-effect"‿"PLAN"‿(¬changed)
      "unbalanced"‿"PLAN"‿(changed ∧ 0≠+´¨(cp∾≠plans)⊔cq)
      "unknown-locus"‿"CHANGE"‿(¬("CHANGE" Col 1)∊loci)
      "zero-amount"‿"CHANGE"‿(0=cq)
      "unknown-tx"‿"PAID-BY"‿(¬paidTx∊txs)
      "paid-by-reused"‿"PAID-BY"‿((paidTx∊txs) Among paidTx)
    ⟩
    Defined "ZERO-ORIGIN"
    ⟨
      "duplicate-support"‿"ZERO-ORIGIN"‿(¬∊Coordinate "ZERO-ORIGIN")
      "support-overlap"‿"ZERO-ORIGIN"‿(OverlapOf "ZERO-ORIGIN")
    ⟩
    Defined "OPENING"
    ⟨
      "unknown-tx"‿"OPENING"‿(¬ot∊txs)
      "opening-missing-coordinate"‿"OPENING"‿((ot∊txs) ∧ ¬(Rows ⟨txs⊐ot⟩∾"OPENING"⊸Col¨1‿2)∊Rows et‿el‿em)
      "duplicate-support"‿"OPENING"‿(¬∊Coordinate "OPENING")
      "support-overlap"‿"OPENING"‿(OverlapOf "OPENING")
      "unknown-tx"‿"ANCHOR"‿((¬dash) ∧ ¬anchorLast∊txs)
      "empty-anchor"‿"ANCHOR"‿(¬(↕≠anchorLast)∊"ANCHOR" Owner "ASSERT")
      "unknown-tx"‿"ALSO"‿(¬alsoTx∊txs)
      "also-redundant"‿"ALSO"‿((alsoTx∊txs) ∧ (aa⊏pointer<≠txs) ∧ (txs⊐alsoTx) ≤ 1+aa⊏pointer)
      "duplicate-also"‿"ALSO"‿(¬∊aa⋈¨alsoTx)
    ⟩
    Defined "ASSERT"
    ⟨"support-overlap"‿"ASSERT"‿(OverlapOf "ASSERT")⟩
    Defined "HISTORY-FROM"
    ⟨
      "duplicate-support"‿"HISTORY-FROM"‿(¬∊Coordinate "HISTORY-FROM")
      "history-unanchored"‿"HISTORY-FROM"‿(¬(Coordinate "HISTORY-FROM")∊Coordinate "ASSERT")
      "duplicate-item"‿"ITEM"‿(¬∊items)
      "unknown-item"‿"CLOSE"‿(¬closed∊items)
      "duplicate-close"‿"CLOSE"‿(¬∊closed)
    ⟩
  ⟩
  faults ← ∾ rules {code‿kind‿fault 𝕊 order: {⟨code,𝕩,order⟩}¨ fault/(Of kind)/n}¨ ↕≠rules

  # The admitted book: one namespace per section, its columns aligned on that
  # section's lines; a block line names its TX, PLAN or ANCHOR by index.
  memoAt ← 5=≠¨(Of "TX")/f
  merchantAt ← (Of "MERCHANT")∨Of "NONMERCHANT"
  book ← {
    measure ⇐ {id⇐measures ⋄ scale⇐Number¨"MEASURE" Col 2}
    locus ⇐ {id⇐loci ⋄ label‿help⇐Unescape¨¨"LOCUS"⊸Col¨2‿3 ⋄ hidden⇐5=≠¨(Of "LOCUS")/f}
    role ⇐ {locus‿name⇐"ROLE"⊸Col¨1‿2}
    tx ⇐ {id⇐txs ⋄ day⇐"TX" Col 2 ⋄ hasMemo⇐memoAt ⋄ memo⇐memoAt {𝕨 ? Unescape 4⊑𝕩 ; ""}¨(Of "TX")/f}
    effect ⇐ {tx⇐et ⋄ locus⇐el ⋄ measure⇐em ⋄ amount⇐eq ⋄ key⇐ek}
    reversal ⇐ {tx⇐rt ⋄ target⇐reversed}
    original ⇐ {tx⇐"TX" Owner "ORIGINAL" ⋄ measure⇐"ORIGINAL" Col 1 ⋄ amount⇐Number¨"ORIGINAL" Col 2}
    merchant ⇐ {tx⇐(/Of "TX")⊐merchantAt/h ⋄ name⇐{2=≠𝕩 ? 1⊑𝕩 ; ""}¨merchantAt/f}
    exchange ⇐ {tx⇐xt ⋄ from⇐xx ⋄ to⇐xy}
    plan ⇐ {id⇐plans ⋄ day‿measure⇐"PLAN"⊸Col¨2‿3}
    change ⇐ {plan⇐cp ⋄ locus⇐"CHANGE" Col 1 ⋄ amount⇐cq}
    paid ⇐ {plan⇐"PLAN" Owner "PAID-BY" ⋄ tx⇐paidTx}
    cancelled ⇐ {plan⇐"PLAN" Owner "CANCELLED" ⋄ day⇐"CANCELLED" Col 1}
    zeroOrigin ⇐ {locus‿measure⇐"ZERO-ORIGIN"⊸Col¨1‿2}
    opening ⇐ {locus‿measure‿tx⇐"OPENING"⊸Col¨1‿2‿3}
    historyFrom ⇐ {locus‿measure‿day⇐"HISTORY-FROM"⊸Col¨1‿2‿3}
    anchor ⇐ {last⇐anchorLast}
    also ⇐ {anchor⇐aa ⋄ tx⇐alsoTx}
    assert ⇐ {anchor⇐"ANCHOR" Owner "ASSERT" ⋄ locus‿measure⇐"ASSERT"⊸Col¨1‿2 ⋄ amount⇐Number¨"ASSERT" Col 3}
    item ⇐ {id⇐items ⋄ due‿when⇐"ITEM"⊸Col¨2‿3 ⋄ context⇐Unescape¨"ITEM" Col 4}
    close ⇐ {item‿day‿kind⇐"CLOSE"⊸Col¨1‿2‿3}
  }
  book {{ok⇐1, book⇐𝕩}} _gate faults
}

Read ⇐ Lines
# Field syntax for other parts that take book text (change.bqn)
SplitFields ⇐ tab⊸Split
IsDate ⇐ Date
IsInteger ⇐ Integer
