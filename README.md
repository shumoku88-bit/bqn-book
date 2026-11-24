# bqn-book

bakhlo の家計簿 `book.txt`（共通形式 v0、`bakhlo/docs/COMMON_FORMAT.ja.md`）を、BQN で読み書きする。
bakhlo がしていることを、BQN でどれだけシンプルに書けるか見るための場所。

| ファイル | すること |
|---|---|
| `src/read.bqn` | 読む。受け入れた帳簿を節ごとの列で返すか、bakhlo と同じ理由のコードと行番号で拒否する |
| `src/balance.bqn` | 今の残高。わからない残高は `@`（0 ではない） |
| `src/print.bqn` | 書き出す。読んで書き出すと、バイト単位で元と同じになる |

```sh
./check.sh                   # bakhlo の見本で、読む・残高・書き出しを確かめる
```

```bqn
book ← •Import "src/read.bqn"
r ← book.Read •file.Bytes "book.txt"
r.ok                         # 1、または 0 なら r.code と r.line
```

計画と進み具合は `docs/PLAN.ja.md`。CBQN が要る。
