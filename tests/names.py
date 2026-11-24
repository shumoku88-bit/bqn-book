#!/usr/bin/env python3
"""BQN names ignore case and underscores: Block and block are one name, so a local
`block` turns a call of the function Block into a call of a list. Report names that
appear in both spellings in one file, except the pairs below, which hold a function
as a value on purpose (an FFI binding, a check kept in a table)."""
import pathlib, re, sys

meant = {
    'store.bqn': {'open', 'close', 'write', 'fcntl', 'lockf', 'link', 'rename', 'unlink'},
    'read.bqn': {'tok', 'day', 'amount', 'scale', 'text', 'help', 'hidden', 'rolename', 'last', 'closekind'},
    'hold_lock.bqn': {'open', 'lockf'},
}
found = []
for f in sorted(pathlib.Path(__file__).resolve().parents[1].glob('*/*.bqn')):
    s = re.sub(r'#.*', '', re.sub(r'"[^"\n]*"', '""', f.read_text()))
    s = re.sub(r"'.'", "''", s)
    spell = {}
    for n in re.findall(r"(?<![\w•.])_?[A-Za-z][A-Za-z0-9_]*", s):
        spell.setdefault(n.replace('_', '').lower(), set()).add(n)
    for key, forms in spell.items():
        if len(forms) > 1 and key not in meant.get(f.name, set()):
            found.append(f'{f.parent.name}/{f.name}: {" ".join(sorted(forms))}')
print('\n'.join(found) if found else 'names: no clashes')
sys.exit(1 if found else 0)
