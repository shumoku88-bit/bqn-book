# Saving a book as bakhlo saves it (bakhlo store/book_file.ml): one writer at a
# time, never over a book somebody else saved, the previous book kept as .prev,
# and every save flushed to the drive before it is reported. macOS.
#
#   Load path              → a book (change.bqn) with its path and bytes, or a refusal
#   loaded Save changed    → the saved book, or {ok⇐0, code}:
#     locked      another writer holds book.txt.lock (bk uses the same lock)
#     conflict    the file is no longer the one that was loaded (K12)
#     unwritten   the new file could not be written; the book is as it was
#     uncertain   the replacement was tried and could not be confirmed:
#                 Load again and compare, never retry blindly
#
# Paths are absolute.

change ← •Import "change.bqn"
libc ← "/usr/lib/libSystem.B.dylib"
open ← libc •FFI "i32"‿"open"‿"*u8:c8"‿"i32"‿"i32"
close ← libc •FFI "i32"‿"close"‿"i32"
write ← libc •FFI "i64"‿"write"‿"i32"‿"*u8:c8"‿"u64"
fcntl ← libc •FFI "i32"‿"fcntl"‿"i32"‿"i32"
lockf ← libc •FFI "i32"‿"lockf"‿"i32"‿"i32"‿"i64"
link ← libc •FFI "i32"‿"link"‿"*u8:c8"‿"*u8:c8"
rename ← libc •FFI "i32"‿"rename"‿"*u8:c8"‿"*u8:c8"
unlink ← libc •FFI "i32"‿"unlink"‿"*u8:c8"
C ← {(•ToUTF8 𝕩)∾@}                      # a path for libc
readWrite‿writeOnly‿create‿exclusive ← 2‿1‿512‿2048
barrier‿full ← 85‿51                    # F_BARRIERFSYNC, F_FULLFSYNC
Refuse ← {c←𝕩 ⋄ {ok⇐0, code⇐c}}

# change.bqn's book, with where it came from
Placed ← {
  𝕨 𝕊 s: ¬s.ok ? s ;
  p‿b 𝕊 s: {ok⇐1 ⋄ lines⇐s.lines ⋄ book⇐s.book ⋄ path⇐p ⋄ bytes⇐b}
}
Load ⇐ {b ← •file.Bytes 𝕩 ⋄ 𝕩‿b Placed change.Open b}

# Write a new file and send its bytes to the drive, ordered before what follows
# (not yet durable: a full sync of its directory must follow).
WriteNew ← {𝕊 path‿bytes:
  fd ← Open ⟨C path, writeOnly+create+exclusive, 6×64⟩
  Fill ← {0=≠𝕩 ? 1 ; 𝕩 {𝕨≤0 ? 0 ; Fill 𝕨↓𝕩}˜ Write fd‿𝕩‿(≠𝕩)}
  Finish ← {𝕊:
    written ← Fill bytes                 # BQN runs right to left: one effect a line
    sent ← 0=Fcntl fd‿barrier
    Close ⋈fd
    written ∧ sent ∧ bytes≡•file.Bytes path
  }
  (fd≥0)◶⟨0˙, Finish⟩ @
}
SyncDir ← {fd ← Open ⟨C •file.Parent 𝕩, 0, 0⟩ ⋄ ok ← 0=Fcntl fd‿full ⋄ Close ⋈fd ⋄ ok}

# ⟨code, Step⟩ in turn, one effect each: the first Step that gives 0 names the
# refusal; "" if none.
Run ← {
  0=≠𝕩 ? "" ;
  code‿Step ← ⊑𝕩 ⋄ rest ← 1↓𝕩
  (Step @)◶⟨code˙, {𝕊: Run rest}⟩ @
}

Save ⇐ {loaded 𝕊 changed:
  path ← loaded.path
  bytes ← change.Bytes changed
  nonce ← "0123456789abcdef"⊏˜24 •rand.Range 16
  temp ← path∾".publish-"∾nonce
  lock ← Open ⟨C path∾".lock", readWrite+create, 6×64⟩
  # Leftovers of an interrupted save are discarded; the book stays the authority.
  leftovers ← ((•file.Name path)∾".publish-")⊸{𝕨≡(≠𝕨)↑𝕩}¨⊸/ •file.List •file.Parent path
  code ← Run ⟨
    "locked"‿{𝕊: (lock≥0) ∧ 0=Lockf lock‿2‿0}
    "conflict"‿{𝕊: loaded.bytes ≡ •file.Bytes path}
    "unwritten"‿{𝕊: {Unlink ⋈C (•file.Parent path)•file.At 𝕩}¨leftovers ⋄ WriteNew temp‿bytes}
    # keep the old book reachable throughout: link it, then name the link .prev
    "unwritten"‿{𝕊: 0=Link ⟨C path, C temp∾".prev"⟩}
    "unwritten"‿{𝕊: 0=Rename ⟨C temp∾".prev", C path∾".prev"⟩}
    "uncertain"‿{𝕊: 0=Rename ⟨C temp, C path⟩}
    "uncertain"‿{𝕊: SyncDir path}
    "uncertain"‿{𝕊: bytes≡•file.Bytes path}
  ⟩
  Unlink¨ ⋈¨C¨ temp‿(temp∾".prev")       # whatever is left; errors do not matter
  Close⍟(lock≥0) ⋈lock
  (0<≠code)◶⟨{𝕊: path‿bytes Placed changed}, {𝕊: Refuse code}⟩ @
}
