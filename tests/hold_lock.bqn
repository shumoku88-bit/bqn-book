#!/usr/bin/env bqn
# Another process holding a book's writer lock: hold_lock.bqn <lock> <marker> <seconds>
libc ← "/usr/lib/libSystem.B.dylib"
open ← libc •FFI "i32"‿"open"‿"*u8:c8"‿"i32"‿"i32"
lockf ← libc •FFI "i32"‿"lockf"‿"i32"‿"i32"‿"i64"
lock‿marker‿seconds ← •args
fd ← Open ⟨(•ToUTF8 lock)∾@, 2+512, 384⟩
{𝕊: marker •file.Bytes "held" ⋄ •Delay •ParseFloat seconds}⍟(0=Lockf fd‿2‿0) @
