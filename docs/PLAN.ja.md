# bakhlo の正データ（book.txt）を BQN で読み書きする計画

2026-11-24 作成。moko の決定：bakhlo が使っている正データ `../bakhlo-data/book.txt` を BQN で
読み書きできるようにする。書き込みも計画に入れる。最初は bqn-ledger の中で始め、段階3の後に
このリポジトリ（bqn-book）へ移した（下の「今のコードの扱い」）。

この文書は計画。実データへの書き込みは、下の段階5で moko が改めて決めるまで行わない。

## 前提

- book.txt の形式は bakhlo の `docs/COMMON_FORMAT.ja.md`（共通形式 v0）が決める。BQN 版はその三つ目の実装になる。
  形式を変えたり、BQN 側の都合で行を足したりはしない（bakhlo の AGENTS.md：形式の変更には moko が承認した移行が要る）。
- LOAM が二つ目の実装になったときと同じ物差しで確かめる。共通の見本（`bakhlo/test/common_format/` の 64 件、
  受入 5・拒否 59）で、拒否の理由のコードと行番号、書き直したバイト列、今の残高が、bakhlo と一致すること。
- 書くのは一度に片方だけ（共通形式の原則3）。同時に書かないことは、bakhlo と同じ鍵（下の段階4）で守る。
- 実データは、段階5までは bakhlo の `./tools/household-copy refresh` で作ったコピーだけを読む。原本には触れない。
  私的な値（名前・メモ・金額）は、このリポジトリにも、その履歴にも入れない。

## 今のコードの扱い

bqn-ledger は hledger 風の journal など8つのファイルを読む作りで、book.txt とは事実の形も
予算の考え方も違った。book.txt の読み書きを bqn-ledger の `src/book/` に新しく書き、段階3まで
進めたところで、moko が昔のコードを消すと決めた（2026-11-24）。手続き的な書き方が多く、
使っていなかったため。`src/book/` とその見本・テストだけをこのリポジトリに移し、bqn-ledger は
`../archive/bqn-ledger` に戻した。借りていた日付の確かめは `src/read.bqn` の中に書き直した。

## 段階

各段階は、前の段階の確かめがすべて通ってから始める。

### 段階1：読む（拒否の理由まで一致させる）

**済（2026-11-24）。** `src/read.bqn`。見本64件（`tests/fixtures/common_format/`、bakhlo `31f86a2` の写し）がすべて一致する（`tests/test_book.bqn`）。
写しが bakhlo とずれていないかは `./check.sh` が見る。

- `src/read.bqn`：book.txt のバイト列を受け取り、受け入れた帳簿か、`⟨理由のコード, 行番号⟩` のどちらかを返す。
- 確かめ：`bakhlo/test/common_format/read.answers` の全行（`READ ファイル OK` / `REFUSED コード 行番号`）と一致すること。
  拒否の見本は1ファイルにつき決まりを一つだけ破っているので、外れた見本がそのまま直す場所を指す。

### 段階2：今の残高と、書き直し

**済（2026-11-24）。** `src/balance.bqn`（12行）と `src/print.bqn`（50行）。受入の見本5件すべてで、残高が答えと一致し、書き直すとバイト単位で元と同じになる（`tests/test_book.bqn`）。

- 今の残高を、共通形式の「今の残高の求め方」どおりに計算する（`ZERO-ORIGIN`・`OPENING`・`ANCHOR`＋`ALSO`、どれもなければ不明）。
- 受け入れた帳簿を、書き出しの決まりどおりの文字列に戻す。
- 確かめ：`ok-*.answers` の `BALANCE` が全部一致すること（`UNKNOWN` を 0 にしない）。
  `ok-*.txt` を読んで書き直すと、バイト単位で元と同じになること（K13）。

### 段階3：実データのコピーで読むだけ

**済（2026-11-24）。** bakhlo の `household-copy` で取ったコピーで確かめた（原本は前後で同じバイト列）。

- 読み取りは受け入れ、書き直すとバイト単位で元と同じ。どちらも 30ms 未満。
- `bk bal`（全口座×全 Measure の表示）のすべての行で、残高（不明を含む）が一致した。
- 残高の根拠がある科目のうち `HIDDEN` の科目は、bk の表に出ないので比べていない。
- 件数や金額は、bakhlo の決まりどおりここには書かない。

- `household-copy` で取ったコピーを読んで、残高を出す。同じコピーに対する bakhlo の `./ui balances` と比べる。
- 収支などのレポートは `bakhlo/test/reports/` の見本の問いと答えで合わせる。どのレポートから作るかは moko と決める。
- 記録に残すのは、件数・一致したかどうか・かかった時間だけ。金額やメモは残さない。

### 段階4：書く（合成データだけ）

**一部済（2026-11-24）。** 「記帳を1件足す」（予定を払うことも含む）を作った。moko の決定で、TUI と GUI を後から差し替えられるように、中身・保存・入口の三層に分けた（README）。

- `src/change.bqn`：bakhlo の変更の言語で `PUT-ENTRY NEW` を受け取る。本文に TX（と予定の PAID-BY）を差し込み、新しい本文をまるごと読み直して受け入れる。bakhlo の書き込みの決まり（HIDDEN の科目、同じ ID、開いた予定、通貨、両替の鍵）を、bakhlo の順で先に確かめる。bakhlo の `test/records` と `test/scheduled` の `PUT-ENTRY NEW` の見本46件がすべて一致（帳簿のバイト列か拒否の理由）。`CORRECT-ENTRY-DATE`（日付だけの訂正）の見本5件も一致。同じ場所で TX を差し替えるときは、bakhlo と同じく鍵のない両替の行に決まった鍵を書き足す。`CLASSIFY-MERCHANT`（店の分類）の見本9件も一致（店名は `\t` などを戻してから1語か確かめ、MERCHANT か NONMERCHANT の行を TX の塊の決まった位置に差し込む。どちらでもない書き方は BQN 側の決まりで `merchant-kind`）。`PUT-ENTRY REPLACE`（記帳の訂正）の見本11件も一致（元の記帳にあった科目は HIDDEN でも使える、分類済みの店は変えられない、訂正に予定は付けられない、位置は変えない）。`PUT-PLAN`（予定の作成・置き換え）と `CANCEL-PLAN`（取り消し）の11件も一致。bakhlo の変更の見本82件がすべて一致した。予定の見本に付いている問い27件（今日の目安 PACE、過去の日の目安 PAST、日ごとの動き ACTIVITY）も、`src/pace.bqn` ですべて一致（`bin/book ask`）。
- `src/store.bqn`：bakhlo の `store/book_file.ml` と同じ手順。`book.txt.lock` を `lockf` でつかみ、読んだ後に変わっていたら `conflict`、一時ファイルに書いて `F_BARRIERFSYNC`、元を `.prev` にリンクし、名前を差し替えてディレクトリを `F_FULLFSYNC`、読み直して確かめる。別のプロセスが鍵を持っていると `locked`。合成の帳簿で確かめ、保存したものを bakhlo 本体が読めることも確かめた（`tests/test_store.bqn`）。
- `bin/book`：画面のための入口（balances・preview・save・ask、一覧の measures・loci・entries・plans、取り出しの entry・plan）。取り出した記帳と開いている予定は、そのまま保存すると帳簿が1バイトも変わらない（見本の帳簿37冊のすべてで確かめた、`tests/test_view.bqn`）。
- bk が鍵を持っている間に BQN が拒否されることは、同じ鍵ファイルと同じ `lockf` を使う作りで守っている。bk との同時の書き込みそのものは、まだ試していない。

bakhlo の `store/book_file.ml` と同じ手順で保存する。

1. 読み込んだときの中身の印（revision）を覚えておく。
2. 保存の直前に `book.txt.lock` を `lockf`（F_TLOCK）でつかむ。bakhlo と同じ鍵なので、bk が書いている間は書けない。
3. ファイルが読み込んだときから変わっていないことを確かめる。変わっていたら保存を拒否する（K12）。
4. 新しい帳簿を全部書いた一時ファイルを作って、ディスクまで書き出す（`F_BARRIERFSYNC`）。
5. 今の book.txt を `.prev` に残して、名前を差し替える。
6. ディレクトリを `F_FULLFSYNC` で書き出す。
7. 読み直して、書いたバイト列と同じことを確かめる。

`lockf` と `fcntl` は CBQN の `•FFI` で呼ぶ。最初に作る書き込みは、まず「記帳を1件足す」だけにする（何から書くかは moko と決める）。

確かめ：

- `bakhlo/test/scheduled/` の見本（変更の前・変更・変更の後、または拒否）を、BQN 側でも同じ結果にする。
- BQN が書いた合成の帳簿を、bakhlo が読み直して受け入れ、残高が一致すること。逆向き（bakhlo が書いて BQN が読む）も確かめる。
- bk が鍵を持っている間は、BQN の保存が拒否されること。BQN が鍵を持っている間は、bk の保存が拒否されること。

### 画面：Emacs（2026-11-24）

moko の決定で、最初の画面は Emacs にした（日本語入力がそのまま使え、毎日使う道具の中で開けるため）。`emacs/bqn-book.el` は `bin/book` だけを通す。記帳の一覧と、bakhlo の記帳フォームと同じ流れ（`src/amount.bqn` で金額を厳密に読み、`src/form.bqn` でフォームから記帳を組み立てる。bakhlo の金額の見本75件とフォームの見本38件が一致）：新しい記帳を順に聞く、フォームで訂正する、返金する、下見してから保存する。合成の帳簿で batch のテスト（`tests/test_emacs.el`）。予定の一覧、残高、今日の目安は、これから足す。

### 段階5：実データで使い始める（moko の決定が要る）

- bakhlo の AGENTS.md「Data and authority」の決まり（正データに書くのは moko が `bk` を通してだけ）を、moko が書き換える。
  たとえば「moko が bk か bqn-book を通して書く。同時には書かない。AI は書かない」。
- 書いた後のバックアップの扱いを決める。bk は `./tools/household` の終わりに commit と push をする。bqn-book 側も、同じ入口を通すか、同じことをする入口を作る。
- 最初の書き込みの前に、原本のコピーを残しておく。

## まだ決めていないこと

- 段階3で最初に作るレポート（残高だけか、収支か、Daily Pace か）。
- 段階4で最初に作る書き込み（記帳を足す、予定を足す、訂正する、など）。
