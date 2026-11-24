# How every part says no, in one place. A refusal is {ok⇐0, code} (code: bakhlo's
# reason); any other value is the answer. Inside amount.bqn and form.bqn a reason
# travels as its code alone, text, until it leaves as a refusal. Pure.
#
#   Refuse code              → the refusal
#   Refused x                → whether x is a refusal
#   F _either_ G x           → F x for an answer, G x for a refusal
#   F _unless ⟨code‿bad, …⟩  → F on the list when no bad holds, else the refusal
#                              of the first that does: the rules' order is theirs
#   IsCode x                 → whether x is a code (text) on its way
#   F _then x                → x when it is a code, else F x

Refuse ⇐ {why←𝕩 ⋄ {ok⇐0, code⇐why}}
Refused ⇐ {6=•Type 𝕩 ? ¬𝕩.ok ; 0}
_either_ ⇐ {(Refused 𝕩)◶⟨𝔽, 𝔾⟩ 𝕩}
_unless ⇐ {bad←1⊑¨𝕩 ⋄ (∨´bad)◶⟨𝔽, {Refuse ⊑⊑bad/𝕩}⟩ 𝕩}
IsCode ⇐ {2=•Type ⊑𝕩∾0}
_then ⇐ {IsCode 𝕩 ? 𝕩 ; 𝔽 𝕩}
