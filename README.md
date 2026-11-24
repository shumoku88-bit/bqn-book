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
| | `src/result.bqn` | 断り方を一か所に：`Refuse`（断る）、`_unless`（断る条件の表）、`_either_`（答えか断りかで分ける） |
| | `src/pace.bqn` | 今日の目安（Daily Pace）、過去の日の目安、日ごとの動き。bakhlo の問いの言語（PACE・PAST・ACTIVITY）で答える |
| | `src/amount.bqn` | 入力した金額を、通貨の桁で厳密に最小単位へ（`(500+300)/2`、全角、桁区切り）。表示はその逆 |
| | `src/form.bqn` | 記帳フォーム：記帳や予定をフォームの行で開く、入力（日付・メモ・通貨・科目と ± 金額）から記帳を組み立てる、返金、両替 |
| | `src/series.bqn` | 予定のまとまり（同じ科目から同じ科目へのまだの予定）と、補充の見張り（scheduled-coverage.tsv） |
| | `src/config.bqn` | bk の設定を読む：今日の目安の科目（daily-pace.tsv）、周期（boundary-presets.tsv） |
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
bin/book book.txt open ENTRY|PLAN <ID>   # 記帳や開いている予定を、フォームの行で
bin/book book.txt form NEW - < form  # フォーム（DAY・MEMO・MEASURE・ROW 鍵|- 科目 ±金額）から、保存できる変更を
bin/book book.txt form EDIT <ID> < form   # 訂正。PAY <予定ID> はその予定を払う新しい記帳
bin/book book.txt refund <ID> <日付>     # 返金の変更
bin/book book.txt pool | cycle <日>     # bk の設定：目安の科目、その日を含む周期
bin/book book.txt series <今日>        # 予定のまとまり（bk plans と同じ）
bin/book book.txt slots <起点日> <何か月ごと> <何件>   # 先の月の日付（その日がない月は MISSING）
bin/book book.txt more <予定> < 日付   # その予定を写した新しい予定の変更
bin/book book.txt reprice <金額> < 予定ID   # 予定の金額をまとめて変える変更（bk plans amount と同じ）
bin/book book.txt view                 # bk が残高画面で見せる科目
bin/backup book.txt                  # 保存のあとのバックアップ（帳簿の Git に commit と push。bk と同じ）
```

`change` は bakhlo の見本と同じ書き方（`tests/fixtures/records/README.md`）。ただしメモと一覧の文字は book.txt と同じくエスケープして書く（`\t`・`\n`・`\\`）ので、1行が1行のまま保たれる。今は `PUT-ENTRY NEW`・`REPLACE`（記帳を足す・訂正する）、`CORRECT-ENTRY-DATE`（日付だけの訂正）、`CLASSIFY-MERCHANT`（店の分類）、`PUT-PLAN NEW`・`REPLACE`（予定を作る・置き換える）、`CANCEL-PLAN`（予定の取り消し）。bakhlo の変更の見本にある種類はすべて。ほかに、bk の `bk loci` に合わせた科目の変更 `ADD-LOCUS`（科目を足す。隠した科目は戻す）・`SET-LOCUS-LABEL`（名前）・`SET-ROLE`（役割、1回だけ）。この3つは見本に無いので bqn-book の言葉で、同じ操作を bk でした帳簿とバイト単位で同じになることを確かめている。

```
PUT-ENTRY	NEW	-
TX	lunch	2027-01-12	DESC	昼ごはん
EFFECT	bank	jpy	-900
EFFECT	food	jpy	900
ENDTX
```

## Emacs

`emacs/bqn-book.el` は、`bin/book` だけを通して帳簿を見る画面。bakhlo の記帳フォームと同じく、聞かれたことに答えれば記帳になる。

- `M-x bqn-book-home`：ホーム。今日の目安（`bqn-book-pace-pool` の科目を使えるお金として、来月の1日まで）、残高、開いている予定（期日を過ぎたら overdue）、最近の記帳。`+` で記帳、開いている予定（または今日の目安の差し引く予定）の行で RET か `p` を押すとその予定を払うフォーム（日付は今日、金額は直せる）、`l` で記帳の一覧、`g` で読み直し。
- `M-x bqn-book-demo`：見本の帳簿のコピーを一時フォルダに作って、そのホームを開く（見本に合わせて 2027-02-01 を今日、bank を使えるお金とする）。
- `M-x bqn-book-entries`：`bqn-book-file`（なければ聞く）の記帳の一覧。
  - `+`：新しい記帳。日付（初めは今日）、メモ、科目（表示名で補完）と金額（`-1200`、`+500+300`、`-(500+300)/2`）を順に聞き、下見を見せて保存するか聞く。釣り合わないなどで断られたら、入れた内容をフォームに残す。
  - RET：その記帳をフォームで訂正。`C-c C-c` で下見して保存、`C-c C-a` で科目を補完して入れる、`C-c C-k` でやめる。
  - `r`：返金。`e`：フォームで開けない記帳（両替・返金）を変更の形で直す。`g`：読み直し。
- 本物の家計簿（bakhlo-data）：`emacs/local.el.example` を `emacs/local.el`（Git に入れない）に写して使う。ターミナルの bk と並べて使える（片方が書いている間、もう片方は断られるだけで、記帳は消えない）。保存のたびに bk と同じ形でバックアップする。
- 今日の目安は、bk の設定（`config/daily-pace.tsv` の科目、`config/boundary-presets.tsv` の周期）をそのまま使う。

BQN から直接使うときは `src/store.bqn` の `Load`・`Save` と `src/change.bqn` の `Apply`。

```sh
./check.sh                            # bakhlo の見本、合成の帳簿での保存、bin/book、Emacs の画面
```

計画と進み具合は `docs/PLAN.ja.md`。CBQN と macOS が要る（保存は F_FULLFSYNC を使う）。
