# bqn-book

bakhlo の家計簿 `book.txt`（共通形式 v0、`bakhlo/docs/COMMON_FORMAT.ja.md`）を、BQN で読み書きする。
bakhlo がしていることを、BQN でどれだけシンプルに書けるか見るための場所。

## 三つの層

画面（TUI・GUI）は外に置き、いつでも差し替えられるようにする。

| 層 | ファイル | すること |
|---|---|---|
| 中身（純粋） | `src/read.bqn` | 読む。受け入れた帳簿を節ごとの列で返すか、bakhlo と同じ理由のコードと行番号で拒否する |
| | `src/balance.bqn` | 今の残高。わからない残高は `@`（0 ではない） |
| | `src/print.bqn` | 書き出す。読んで書き出すと、バイト単位で元と同じになる |
| | `src/pace.bqn` | 今日の目安（Daily Pace）、過去の日の目安、日ごとの動き。bakhlo の問いの言語（PACE・PAST・ACTIVITY）で答える |
| | `src/amount.bqn` | 入力した金額を、通貨の桁で厳密に最小単位へ（`(500+300)/2`、全角、桁区切り）。表示はその逆 |
| | `src/view.bqn` | 画面が並べる一覧：通貨、科目、記帳、予定 |
| | `src/change.bqn` | 変更。bakhlo の変更の言語（`PUT-ENTRY NEW` と TX ブロック）で受け取り、本文を編集して、まるごと読み直して受け入れる |
| 保存 | `src/store.bqn` | bakhlo と同じ鍵（`book.txt.lock`）、読んだ後に変わっていたら拒否、`.prev`、ドライブまで書き出してから報告 |
| 入口 | `bin/book` | 画面のための扉。タブ区切りの行で話す |

```sh
bin/book book.txt balances           # 科目 × 通貨ごとに：科目、通貨、金額（最小単位の整数）か ?
bin/book book.txt preview < change   # 変更を下見：OK と足される行、または REFUSED <理由>
bin/book book.txt save < change      # 保存：SAVED と足された行、または REFUSED <理由>
bin/book book.txt ask < questions    # 問い（PACE・PAST・ACTIVITY と POOL の行）に、答えを付けて返す
bin/book book.txt measures|loci|entries|plans   # 画面が並べる一覧（1行に1つ、タブ区切り）
bin/book book.txt entry <ID>         # その記帳を「訂正の変更」の形で。直して save に渡せば訂正になる
bin/book book.txt plan <ID>          # 予定も同じ
```

`change` は bakhlo の見本と同じ書き方（`tests/fixtures/records/README.md`）。ただしメモと一覧の文字は book.txt と同じくエスケープして書く（`\t`・`\n`・`\\`）ので、1行が1行のまま保たれる。今は `PUT-ENTRY NEW`・`REPLACE`（記帳を足す・訂正する）、`CORRECT-ENTRY-DATE`（日付だけの訂正）、`CLASSIFY-MERCHANT`（店の分類）、`PUT-PLAN NEW`・`REPLACE`（予定を作る・置き換える）、`CANCEL-PLAN`（予定の取り消し）。bakhlo の変更の種類はすべて。

```
PUT-ENTRY	NEW	-
TX	lunch	2027-01-12	DESC	昼ごはん
EFFECT	bank	jpy	-900
EFFECT	food	jpy	900
ENDTX
```

## Emacs

`emacs/bqn-book.el` は、`bin/book` だけを通して帳簿を見る画面。

- `M-x bqn-book-demo`：見本の帳簿のコピーを一時フォルダに作って開く。気軽に試すとき。
- `M-x bqn-book-entries`：`bqn-book-file`（なければ聞く）の記帳の一覧。RET でその記帳を変更として開き、`C-c C-p` で下見、`C-c C-c` で保存、`C-c C-k` でやめる。`+` で新しい記帳の雛形、`g` で読み直し。
- 本物の家計簿（bakhlo-data）は、計画の段階5まで開かない。

BQN から直接使うときは `src/store.bqn` の `Load`・`Save` と `src/change.bqn` の `Apply`。

```sh
./check.sh                            # bakhlo の見本、合成の帳簿での保存、bin/book、Emacs の画面
```

計画と進み具合は `docs/PLAN.ja.md`。CBQN と macOS が要る（保存は F_FULLFSYNC を使う）。
