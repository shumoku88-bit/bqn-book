;;; bqn-book.el --- bakhlo's book.txt in Emacs, through bqn-book's bin/book  -*- lexical-binding: t; -*-

;; A screen for bqn-book. It never reads or writes book.txt itself: every list and
;; every change goes through bin/book, in tab-separated lines (README.md).
;;
;;   M-x bqn-book-entries   the entries of `bqn-book-file', in recorded order
;;     +     record a new entry: day, memo, then accounts and amounts, asked one by
;;           one (an account by its name, an amount like -1200 or +500+300); the
;;           preview, then saving, as bakhlo's Record form does
;;     RET   correct the entry in a form: its day, memo, accounts and amounts;
;;           C-c C-c previews and saves, C-c C-a inserts an account
;;     r     refund the entry
;;     e     edit the entry as a change (for exchanges and refunds, which no form opens)
;;     g     read the book again
;;   M-x bqn-book-home      the book at a glance: today's guide (the accounts in
;;                          `bqn-book-pace-pool'), balances, open plans, recent entries;
;;                          + new entry, RET (or p) on a plan pays it, l entries, g reread
;;   M-x bqn-book-demo      the home of a copy of a synthetic sample book
;;
;; Text in a change is written as in book.txt: a memo's tab is \t, a backslash \\.

;;; Code:

(require 'tabulated-list)
(require 'subr-x)
(require 'cl-lib)
(require 'seq)
(require 'time-date)

(defgroup bqn-book nil
  "bakhlo's book.txt through bqn-book."
  :group 'applications)

(defcustom bqn-book-command
  (expand-file-name "../bin/book" (file-name-directory (or load-file-name buffer-file-name)))
  "The bin/book program of bqn-book."
  :type 'file)

(defcustom bqn-book-file nil
  "The book.txt that `bqn-book-entries' opens.
Saving writes this file. Do not point it at the household (bakhlo-data) until
moko has decided so (bqn-book docs/PLAN.ja.md, stage 5)."
  :type '(choice (const :tag "Ask" nil) file))

(defcustom bqn-book-backup nil
  "After each save, commit and push the book's own Git repository, as bk does when
it ends (bin/backup). For the household book, whose folder is its backup repository."
  :type 'boolean)

;;;; Keys: ? (C-c ? where typing) shows what each screen's keys do

(defconst bqn-book--keys
  '((bqn-book-home-mode
     ("RET" . "予定の上：支払う　記帳の上：直す")
     ("+" . "新しい記帳")
     ("n" . "新しい予定")
     ("d" . "予定の期日を変える")
     ("e" . "予定をフォームで直す（期日・科目・金額）")
     ("E" . "予定を変更の文で直す")
     ("c" . "予定を取り消す（印を付けて残す）")
     ("s" . "予定のまとまり")
     ("a" . "科目の一覧（追加・名前・役割）")
     ("l" . "記帳の一覧")
     ("g" . "読み直す"))
    (bqn-book-entries-mode
     ("RET" . "記帳をフォームで直す")
     ("+" . "新しい記帳")
     ("r" . "返金（元を残し、打ち消す記帳を足す）")
     ("e" . "記帳を変更の文で直す")
     ("S" . "この列で並べ替える（見出しの列で）")
     ("g" . "読み直す"))
    (bqn-book-series-mode
     ("RET" . "このまとまりの予定")
     ("a" . "ある日から先の金額を変える（値上げなど）")
     ("m" . "先の月を埋める（最後の予定を写す）")
     ("n" . "新しい予定")
     ("S" . "この列で並べ替える（見出しの列で）")
     ("g" . "読み直す"))
    (bqn-book-series-plans-mode
     ("RET" . "支払う")
     ("d" . "期日を変える")
     ("e" . "フォームで直す（期日・科目・金額）")
     ("E" . "変更の文で直す")
     ("c" . "取り消す（印を付けて残す）")
     ("a" . "この予定から先の金額を変える（値上げなど）")
     ("m" . "先の月を埋める（最後の予定を写す）")
     ("n" . "新しい予定")
     ("g" . "読み直す"))
    (bqn-book-accounts-mode
     ("+" . "科目を足す（ID・名前・役割）")
     ("r" . "名前を変える")
     ("R" . "役割を付ける（1回だけ）")
     ("S" . "この列で並べ替える（見出しの列で）")
     ("g" . "読み直す"))
    (bqn-book-form-mode
     ("C-c C-c" . "下見して保存")
     ("C-c C-a" . "科目を名前で選んで入れる")
     ("C-c C-k" . "保存せずに閉じる")
     ("TAB" . "欄の区切り（タブ）"))
    (bqn-book-change-mode
     ("C-c C-p" . "下見（保存しない）")
     ("C-c C-c" . "保存")
     ("C-c C-k" . "保存せずに閉じる")
     ("TAB" . "欄の区切り（タブ）")))
  "Each screen's keys and what they do, as ? shows them.")

(defun bqn-book-keys ()
  "Show what this screen's keys do; again, or q there, closes it."
  (interactive)
  (let* ((mode major-mode)
         (window (get-buffer-window "*book keys*")))
    (if (and window (eq last-command 'bqn-book-keys))
        (quit-window nil window)
      (with-current-buffer (get-buffer-create "*book keys*")
        (let ((inhibit-read-only t))
          (erase-buffer)
          (dolist (key (cdr (assq mode bqn-book--keys)))
            (insert "  " (propertize (bqn-book--cell (car key) 8) 'face 'help-key-binding) "  " (cdr key) "\n"))
          (insert "  " (propertize (bqn-book--cell (if (derived-mode-p 'text-mode) "C-c ?" "?") 8) 'face 'help-key-binding)
                  "  このヒントを閉じる\n"))
        (special-mode)
        (goto-char (point-min)))
      (display-buffer "*book keys*" '((display-buffer-in-side-window) (side . bottom)
                                       (window-height . fit-window-to-buffer))))))

;;;; Talking to bin/book

(defun bqn-book--call (file args &optional input)
  "Run bin/book on FILE with ARGS, INPUT on stdin.
Return (EXIT . LINES)."
  (with-temp-buffer
    (let* ((coding-system-for-read 'utf-8-unix)
           (coding-system-for-write 'utf-8-unix)
           (exit (if input
                     (progn (insert input)
                            (apply #'call-process-region (point-min) (point-max)
                                   bqn-book-command t t nil (expand-file-name file) args))
                   (apply #'call-process bqn-book-command nil t nil (expand-file-name file) args))))
      (cons exit (split-string (buffer-string) "\n" t)))))

(defun bqn-book--rows (file command)
  "The rows bin/book lists for COMMAND (a word, or a list with its arguments) on
FILE, each a list of fields."
  (let ((args (ensure-list command)))
    (pcase (bqn-book--call file args)
      (`(0 . ,lines) (mapcar (lambda (line) (split-string line "\t")) lines))
      (`(,_ . ,lines) (user-error "bin/book %s: %s" (car args) (string-join lines " "))))))

(defun bqn-book--shown (text)
  "TEXT as written in book.txt, made readable on one line."
  (replace-regexp-in-string
   "\\\\\\(.\\)"
   (lambda (m) (pcase (match-string 1 m) ("t" " ") ("n" " ⏎ ") ("r" "") (c c)))
   text t t))

(defun bqn-book--backup (file)
  "Back up FILE's repository in the background, when `bqn-book-backup' says so."
  (when bqn-book-backup
    (let ((buffer (get-buffer-create "*book backup*")))
      (with-current-buffer buffer (erase-buffer))
      (make-process
       :name "bqn-book-backup" :buffer buffer
       :command (list (expand-file-name "backup" (file-name-directory bqn-book-command))
                      (expand-file-name file))
       :sentinel (lambda (process _)
                   (when (memq (process-status process) '(exit signal))
                     (if (zerop (process-exit-status process))
                         (message "Saved and backed up.")
                       (message "Saved, but the backup failed: see *book backup*"))))))))

;;;; Entries

(defvar-local bqn-book--file nil "The book.txt this buffer shows or changes.")

(defvar bqn-book-entries-mode-map (make-sparse-keymap))
(define-keymap :keymap bqn-book-entries-mode-map   ; again on reload: a new key takes effect
  :parent tabulated-list-mode-map
  "RET" #'bqn-book-correct-entry
  "+" #'bqn-book-new-entry
  "r" #'bqn-book-refund-entry
  "e" #'bqn-book-edit-entry
  "g" #'bqn-book-refresh
  "?" #'bqn-book-keys)

(define-derived-mode bqn-book-entries-mode tabulated-list-mode "Book"
  "The entries of a book.txt, in recorded order."
  (setq tabulated-list-format
        [("#" 5 (lambda (a b) (< (car a) (car b))) :right-align t)
         ("Day" 10 t) ("ID" 16 t) ("Memo" 32 t) ("Merchant" 14 t)
         ("Reverses" 10 t) ("Pays" 14 t)])
  (setq tabulated-list-padding 1)
  (add-hook 'tabulated-list-revert-hook #'bqn-book--list nil t)
  (display-line-numbers-mode -1)                 ; a table, not text: no line numbers
  (tabulated-list-init-header))

(defun bqn-book--list ()
  "Fill the entries buffer from bin/book."
  (let ((n 0))
    (setq tabulated-list-entries
          (mapcar (lambda (row)
                    (pcase-let ((`(,id ,day ,memo ,merchant ,reverses ,pays) row))
                      (setq n (1+ n))
                      (list id (vector (number-to-string n) day id (bqn-book--shown memo)
                                       merchant reverses pays))))
                  (bqn-book--rows bqn-book--file "entries")))))

;;;###autoload
(defun bqn-book-entries (file)
  "Show the entries of the book FILE."
  (interactive (list (or bqn-book-file (read-file-name "book.txt: " nil nil t))))
  (let ((buffer (get-buffer-create (format "*book %s*" (abbreviate-file-name file)))))
    (with-current-buffer buffer
      (bqn-book-entries-mode)
      (setq bqn-book--file (expand-file-name file))
      (bqn-book--list)
      (tabulated-list-print))
    (pop-to-buffer-same-window buffer)
    (message "? keys")))

(defun bqn-book-refresh ()
  "Read the book again."
  (interactive)
  (revert-buffer))

;;;###autoload
(defun bqn-book-demo ()
  "Open a copy of a synthetic sample book, in a new temporary directory."
  (interactive)
  (let* ((sample (expand-file-name "../tests/fixtures/scheduled/base.txt"
                                   (file-name-directory bqn-book-command)))
         (copy (expand-file-name "book.txt" (make-temp-file "bqn-book-demo" t))))
    (copy-file sample copy)
    (with-current-buffer (bqn-book-home copy)
      ;; the sample book lives in 2027; count from there, with the bank to spend
      (setq bqn-book--today "2027-02-01" bqn-book--pool '("bank"))
      (revert-buffer))))

;;;; Changes

(defvar-local bqn-book--list-buffer nil "The entries buffer a change came from.")

(defvar bqn-book-change-mode-map (make-sparse-keymap))
(define-keymap :keymap bqn-book-change-mode-map   ; again on reload: a new key takes effect
  "C-c C-p" #'bqn-book-preview
  "C-c C-c" #'bqn-book-save
  "C-c C-k" #'bqn-book-discard
  "C-c ?" #'bqn-book-keys
  "TAB" #'bqn-book-insert-tab)

(define-derived-mode bqn-book-change-mode text-mode "Book change"
  "A change to a book.txt, in bakhlo's change language.
C-c C-p previews it, C-c C-c saves it, C-c C-k discards it."
  (setq-local indent-tabs-mode t)
  (setq-local tab-width 12)
  (setq-local require-final-newline nil)
  (setq-local font-lock-defaults
              '((("^\\(PUT-ENTRY\\|PUT-PLAN\\|CANCEL-PLAN\\|CORRECT-ENTRY-DATE\\|CLASSIFY-MERCHANT\\)\\b"
                  . font-lock-keyword-face)
                 ("^[A-Z-]+" . font-lock-builtin-face)))))

(defun bqn-book-insert-tab ()
  "Insert a field separator."
  (interactive)
  (insert "\t"))

(defun bqn-book--change (lines title)
  "Open LINES as a change titled TITLE, for the book of the current list."
  (let ((file bqn-book--file)
        (list (current-buffer))
        (buffer (generate-new-buffer (format "*book change %s*" title))))
    (with-current-buffer buffer
      (bqn-book-change-mode)
      (setq bqn-book--file file
            bqn-book--list-buffer list)
      (insert (string-join lines "\n") "\n")
      (goto-char (point-min))
      (forward-line 1))
    (pop-to-buffer buffer)
    (message "C-c C-c save   C-c ? keys")))

(defun bqn-book--entry-at-point ()
  "The entry at point: a list's row, or a home line."
  (or (get-text-property (point) 'bqn-book-entry)
      (and (derived-mode-p 'bqn-book-entries-mode) (tabulated-list-get-id))))

(defun bqn-book-edit-entry ()
  "Open the entry at point as a change that would keep it."
  (interactive)
  (let ((id (bqn-book--entry-at-point)))
    (unless id (user-error "No entry here"))
    (pcase (bqn-book--call bqn-book--file (list "entry" id))
      (`(0 . ,lines) (bqn-book--change lines id))
      (`(,_ . ,lines) (user-error "%s" (string-join lines " "))))))

(defun bqn-book--refusal (lines)
  "Say why bin/book refused, from its LINES."
  (message "Refused: %s" (string-remove-prefix "REFUSED\t" (string-join lines " "))))

(defun bqn-book--send (command)
  "Send this buffer's change to bin/book COMMAND. Return (EXIT . LINES)."
  (bqn-book--call bqn-book--file (list command) (buffer-string)))

(defun bqn-book-preview ()
  "Show what this change would add, or why it is refused. Nothing is saved."
  (interactive)
  (pcase (bqn-book--send "preview")
    (`(0 . ,lines) (message "Would save:\n%s" (string-join (cdr lines) "\n")))
    (`(,_ . ,lines) (bqn-book--refusal lines))))

(defun bqn-book-save ()
  "Save this change. On success, close it and read the book again."
  (interactive)
  (pcase (bqn-book--send "save")
    (`(0 . ,_)
     (let ((list bqn-book--list-buffer) (file bqn-book--file))
       (kill-buffer)
       (when (buffer-live-p list)
         (with-current-buffer list (revert-buffer)))
       (message "Saved.")
       (bqn-book--backup file)))
    (`(,_ . ,lines) (bqn-book--refusal lines))))

(defun bqn-book-discard ()
  "Close this change without saving."
  (interactive)
  (kill-buffer))

;;;; The Record form

(defun bqn-book--accounts (file)
  "The accounts offered for new entries in FILE: (\"id  name\" . id).
The ID comes first, so typing its start and TAB finds it (co TAB → coffee)."
  (delq nil (mapcar (lambda (row)
                      (pcase-let ((`(,id ,label ,_help ,hidden ,_role) row))
                        (unless (equal hidden "HIDDEN")
                          (let ((name (bqn-book--shown label)))
                            (cons (if (member name (list "" id)) id (format "%s  %s" id name)) id)))))
                    (bqn-book--rows file "loci"))))

(defun bqn-book--read-account (file prompt)
  "Ask for an account of FILE by its ID or name; nil when left empty.
TAB completes from the start of the ID, or from any part of the name."
  (let* ((accounts (bqn-book--accounts file))
         (completion-styles '(basic substring))
         (completion-ignore-case t)
         (choice (completing-read prompt accounts nil t)))
    (unless (string-empty-p choice) (cdr (assoc choice accounts)))))

(defun bqn-book--save-change (file change list)
  "Preview CHANGE (lines) on FILE, ask, and save it; then reread LIST.
Return non-nil when saved."
  (pcase (bqn-book--call file '("preview") (concat (string-join change "\n") "\n"))
    (`(0 . ,added)
     (with-current-buffer (get-buffer-create "*book preview*")
       (let ((inhibit-read-only t))
         (erase-buffer)
         (insert (mapconcat #'bqn-book--shown (cdr added) "\n") "\n"))
       (special-mode)
       (display-line-numbers-mode -1))
     (display-buffer "*book preview*")
     (when (y-or-n-p "Save this? ")
       (pcase (bqn-book--call file '("save") (concat (string-join change "\n") "\n"))
         (`(0 . ,_)
          (when (buffer-live-p list) (with-current-buffer list (revert-buffer)))
          (message "Saved.")
          (bqn-book--backup file)
          t)
         (`(,_ . ,lines) (bqn-book--refusal lines) nil))))
    (`(,_ . ,lines) (bqn-book--refusal lines) nil)))

(defun bqn-book--fill (file mode target lines)
  "The change FILE's form MODE (NEW, EDIT, PAY) with TARGET makes of LINES, or nil."
  (pcase (bqn-book--call file (list "form" mode target) (concat (string-join lines "\n") "\n"))
    (`(0 . ,change) change)
    (`(,_ . ,out) (bqn-book--refusal out) nil)))

(defvar-local bqn-book--form nil "The form's (MODE TARGET).")

(defvar bqn-book-form-mode-map (make-sparse-keymap))
(define-keymap :keymap bqn-book-form-mode-map   ; again on reload: a new key takes effect
  "C-c C-c" #'bqn-book-form-submit
  "C-c C-a" #'bqn-book-form-insert-account
  "C-c C-k" #'bqn-book-discard
  "C-c ?" #'bqn-book-keys
  "TAB" #'bqn-book-insert-tab)

(define-derived-mode bqn-book-form-mode text-mode "Book form"
  "A Record form: DAY, MEMO, MEASURE, then ROW key|- account ±amount lines.
An amount may be an expression (-(500+300)/2). C-c C-c previews and saves,
C-c C-a inserts an account by its name, C-c C-k discards."
  (setq-local indent-tabs-mode t)
  (setq-local tab-width 12)
  (setq-local font-lock-defaults '((("^[A-Z]+" . font-lock-keyword-face)))))

(defun bqn-book--form-buffer (file list mode target lines)
  "Open LINES as a form of MODE for TARGET on FILE, from LIST."
  (let ((buffer (generate-new-buffer (format "*book form %s*" (if (equal target "-") "new" target)))))
    (with-current-buffer buffer
      (bqn-book-form-mode)
      (setq bqn-book--file file
            bqn-book--list-buffer list
            bqn-book--form (list mode target))
      (insert (string-join lines "\n") "\n")
      (goto-char (point-min)))
    (pop-to-buffer buffer)
    (message "C-c C-c preview and save   C-c ? keys")
    buffer))

(defun bqn-book-form-insert-account ()
  "Insert an account ID, chosen by its name."
  (interactive)
  (let ((id (bqn-book--read-account bqn-book--file "Account: ")))
    (when id (insert id))))

(defun bqn-book-form-submit ()
  "Make the entry this form describes, preview it, and save it when asked to."
  (interactive)
  (pcase-let* ((`(,mode ,target) bqn-book--form)
               (lines (split-string (buffer-string) "\n" t))
               (change (bqn-book--fill bqn-book--file mode target lines)))
    (when (and change (bqn-book--save-change bqn-book--file change bqn-book--list-buffer))
      (kill-buffer))))

(defun bqn-book-new-entry ()
  "Record a new entry: asked one field at a time, as bakhlo's Record form does."
  (interactive)
  (let* ((file bqn-book--file)
         (list (current-buffer))
         (day (read-string "Day: " (format-time-string "%Y-%m-%d")))
         (memo (read-string "Memo: ")))
    (bqn-book--ask-and-save file list "NEW" "-"
                            (append (list (concat "DAY\t" day) (concat "MEMO\t" memo))
                                    (bqn-book--ask-rows file)))))

(defun bqn-book--ask-rows (file)
  "Ask for FILE's Measure, then accounts and signed amounts until an empty account:
the form's MEASURE and ROW lines."
  (let* ((measures (mapcar #'car (bqn-book--rows file "measures")))
         (measure (if (cdr measures) (completing-read "Measure: " measures nil t nil nil (car measures))
                    (car measures)))
         (rows '()))
    (while (let ((account (bqn-book--read-account
                           file (format "Account %d (empty to finish): " (1+ (length rows))))))
             (when account
               (push (format "ROW\t-\t%s\t%s" account
                             (read-string (format "Amount for %s (-1200, +500+300): " account)))
                     rows))))
    (cons (concat "MEASURE\t" measure) (nreverse rows))))

(defun bqn-book--ask-and-save (file list mode target lines)
  "Make the change form MODE with TARGET makes of LINES, preview it and save it
when asked to; when it is refused, keep what was typed in a form to fix."
  (let ((change (bqn-book--fill file mode target lines)))
    (if change
        (bqn-book--save-change file change list)
      (bqn-book--form-buffer file list mode target lines))))

(defun bqn-book-new-plan ()
  "Make a new plan: its due day, then accounts and amounts, as an entry asks them."
  (interactive)
  (let ((file bqn-book--file) (list (current-buffer)))
    (bqn-book--ask-and-save file list "PLAN" "-"
                            (cons (concat "DAY\t" (bqn-book--typed-day (read-string "Due day: " (bqn-book--day-today))))
                                  (bqn-book--ask-rows file)))))

(defun bqn-book--day-and-memo (file id)
  "Entry ID's day and memo in FILE, the memo as typed (a form line holds tabs)."
  (let ((row (assoc id (bqn-book--rows file "entries"))))
    (list (nth 1 row)
          (replace-regexp-in-string
           "\\\\\\([t\\\\]\\)" (lambda (m) (if (equal (match-string 1 m) "t") "\t" "\\"))
           (nth 2 row) t t))))

(defun bqn-book-correct-entry ()
  "Correct the entry at point in a form; an entry no form opens opens as a change."
  (interactive)
  (let ((id (bqn-book--entry-at-point)))
    (unless id (user-error "No entry here"))
    (pcase (bqn-book--call bqn-book--file (list "open" "ENTRY" id))
      (`(0 . ,rows)
       (pcase-let ((`(,day ,memo) (bqn-book--day-and-memo bqn-book--file id)))
         (bqn-book--form-buffer bqn-book--file (current-buffer) "EDIT" id
                                (append (list (concat "DAY\t" day) (concat "MEMO\t" memo)) rows))))
      (`(,_ . ,lines)
       (message "%s; opening it as a change" (string-join lines " "))
       (bqn-book-edit-entry)))))

(defun bqn-book-refund-entry ()
  "Refund the entry at point: a new entry that reverses it, after a preview."
  (interactive)
  (let ((id (tabulated-list-get-id)))
    (unless id (user-error "No entry here"))
    (pcase (bqn-book--call bqn-book--file
                           (list "refund" id (read-string "Day: " (format-time-string "%Y-%m-%d"))))
      (`(0 . ,change) (bqn-book--save-change bqn-book--file change (current-buffer)))
      (`(,_ . ,lines) (bqn-book--refusal lines)))))

;;;; Home: today's guide, balances, open plans and recent entries

(defcustom bqn-book-pace-pool nil
  "The accounts today's guide counts as money to spend, like (\"bank\" \"wallet\").
nil uses bk's own choice (daily-pace.tsv next to the book), so both agree."
  :type '(repeat string))

(defun bqn-book--answer (file args)
  "bin/book's lines for ARGS on FILE, or nil when it refuses."
  (pcase (bqn-book--call file args) (`(0 . ,lines) lines)))

(defvar-local bqn-book--today nil "The day the home counts from; nil for today.")
(defvar-local bqn-book--pool nil "The guide's accounts in this home; nil for `bqn-book-pace-pool'.")

(defun bqn-book--day-today ()
  (or bqn-book--today (format-time-string "%Y-%m-%d")))

(defun bqn-book--next-month (day)
  "The first day of the month after DAY (YYYY-MM-DD)."
  (let* ((y (string-to-number (substring day 0 4)))
         (m (string-to-number (substring day 5 7))))
    (if (= m 12) (format "%04d-01-01" (1+ y)) (format "%04d-%02d-01" y (1+ m)))))

(defun bqn-book--cell (text width &optional right)
  "TEXT in WIDTH columns, cut with … if longer; RIGHT aligns it right.
Columns, not characters: a Japanese character takes two."
  (let* ((cut (truncate-string-to-width text width nil nil "…"))
         (pad (make-string (max 0 (- width (string-width cut))) ?\s)))
    (if right (concat pad cut) (concat cut pad))))

(defun bqn-book--plan-name (row names)
  "What plan ROW (a `plans' row) moves: its accounts by NAMES, from → to."
  (pcase-let ((`(,_id ,_day ,_m ,_state ,_detail ,_q ,from ,to) row))
    (cl-flet ((named (ids) (mapconcat (lambda (l) (or (cdr (assoc l names)) l))
                                      (split-string (or ids "") "+" t) "+")))
      (concat (named from) " → " (named to)))))

(defun bqn-book--money (quanta scale)
  "QUANTA (smallest units, as text) shown with SCALE decimals and thousands commas."
  (let* ((n (string-to-number quanta))
         (whole (/ (abs n) (expt 10 scale)))
         (part (% (abs n) (expt 10 scale)))
         (digits (number-to-string whole))
         (grouped (replace-regexp-in-string "\\([0-9]\\)\\(\\([0-9]\\{3\\}\\)+\\)\\'"
                                            (lambda (m) (concat (match-string 1 m) ","
                                                                (mapconcat #'identity
                                                                           (seq-partition (match-string 2 m) 3) ",")))
                                            digits)))
    (concat (if (< n 0) "-" "") grouped
            (if (> scale 0) (format (format ".%%0%dd" scale) part) ""))))

(defvar bqn-book-home-mode-map (make-sparse-keymap))
(define-keymap :keymap bqn-book-home-mode-map   ; again on reload: a new key takes effect
  :parent special-mode-map
  "+" #'bqn-book-new-entry
  "l" #'bqn-book-home-entries
  "RET" #'bqn-book-home-open
  "p" #'bqn-book-pay-plan
  "d" #'bqn-book-move-plan
  "c" #'bqn-book-cancel-plan
  "e" #'bqn-book-edit-plan
  "E" #'bqn-book-edit-plan-as-change
  "n" #'bqn-book-new-plan
  "s" #'bqn-book-home-series
  "a" #'bqn-book-home-accounts
  "?" #'bqn-book-keys
  "g" #'revert-buffer)

(define-derived-mode bqn-book-home-mode special-mode "Book home"
  "A book at a glance: today's guide, balances, open plans and recent entries."
  (setq-local revert-buffer-function (lambda (&rest _) (bqn-book--draw-home)))
  (display-line-numbers-mode -1))

(defun bqn-book--draw-home ()
  (let* ((inhibit-read-only t)
         (file bqn-book--file)
         (today (bqn-book--day-today))
         ;; the guide runs to the end of bk's cycle (boundary-presets.tsv), as bk's does
         (cycle (split-string (or (car (bqn-book--answer file (list "cycle" today))) "") "\t" t))
         (end (or (nth 2 cycle) (bqn-book--next-month today)))
         (scales (mapcar (lambda (r) (cons (car r) (string-to-number (cadr r))))
                         (bqn-book--rows file "measures")))
         (measure (caar scales))
         (Money (lambda (q m) (bqn-book--money q (or (cdr (assoc m scales)) 0))))
         (names (mapcar (lambda (r) (cons (car r) (bqn-book--shown (nth 1 r))))
                        (bqn-book--rows file "loci")))
         (pool (or bqn-book--pool bqn-book-pace-pool (bqn-book--answer file '("pool"))))
         (plans (bqn-book--rows file "plans"))
         (Plan (lambda (id) (let ((row (assoc id plans))) (if row (bqn-book--plan-name row names) id))))
         (point (point)))
    (erase-buffer)
    ;; the book by its folder and name: the whole path can be long
    (insert (propertize (file-name-concat (file-name-nondirectory (directory-file-name (file-name-directory file)))
                                          (file-name-nondirectory file))
                        'face 'bold)
            "    " today "\n\n")
    ;; today's guide
    (insert (propertize "Today's guide" 'face 'bold))
    (if (null pool)
        (insert "\n  Choose the accounts you spend from: `bk pace pool', or `bqn-book-pace-pool'.\n\n")
      (let ((answer (cdr (bqn-book--call
                          file '("ask")
                          (concat (string-join (list "PACE" measure today end) "\t") "\n"
                                  (mapconcat (lambda (p) (concat "POOL\t" p "\n")) pool ""))))))
        (insert (format "  %s, until %s%s\n" measure end
                        (if cycle (format " (cycle %s)" (car cycle)) " (no cycle in bk's settings)")))
        (dolist (line answer)
          (pcase (split-string line "\t")
            (`("BALANCE" ,locus ,q) (insert (format "  %-14s %12s  %s\n" "Spendable" (funcall Money q measure)
                                                    (or (cdr (assoc locus names)) locus))))
            (`("DEDUCTION" ,plan ,q) (insert (propertize (format "  %-14s %12s  %s\n" "Set aside" (funcall Money (concat "-" q) measure)
                                                                 (funcall Plan plan))
                                                         'bqn-book-plan plan)))
            (`("AVAILABLE" ,q) (insert (format "  %-14s %12s\n" "Left" (funcall Money q measure))))
            (`("DAYS" ,n) (insert (format "  %-14s %12s\n" "Days" n)))
            (`("DAILY" ,q) (insert (propertize (format "  %-14s %12s\n" "Per day" (funcall Money q measure)) 'face 'success)))
            (`("REFUSED" ,why) (insert (format "  Not known: %s\n" why)))))
        (insert "\n")))
    ;; balances
    (insert (propertize "Balances" 'face 'bold) "\n")
    ;; the balances bk shows (balance-view.tsv), in its order; without it, every known one
    (let* ((all (bqn-book--rows file "balances"))
           (view (bqn-book--answer file '("view")))
           (rows (if view
                     (mapcar (lambda (line)
                               (pcase-let ((`(,locus ,m) (split-string line "\t")))
                                 (or (seq-find (lambda (r) (and (equal (car r) locus) (equal (nth 1 r) m))) all)
                                     (list locus m "?"))))
                             view)
                   (seq-remove (lambda (r) (equal (nth 2 r) "?")) all)))
           (width (min 24 (apply #'max 8 (mapcar (lambda (r) (string-width (or (cdr (assoc (car r) names)) (car r))))
                                                 rows)))))
      (dolist (row rows)
        (pcase-let ((`(,locus ,m ,q) row))
          (insert "  " (bqn-book--cell (or (cdr (assoc locus names)) locus) width)
                  "  " (bqn-book--cell m 4)
                  " " (bqn-book--cell (if (equal q "?") "?" (funcall Money q m)) 12 t) "\n")))
      (unless view
        (insert (propertize "  (every account with a known balance: choose them in bk's Balances, c)\n" 'face 'shadow))))
    ;; open plans
    (insert "\n" (propertize "Open plans" 'face 'bold) "\n")
    (dolist (row (sort (seq-filter (lambda (r) (equal (nth 3 r) "open")) plans)
                       (lambda (a b) (string< (nth 1 a) (nth 1 b)))))
      (pcase-let ((`(,id ,day ,m ,_ ,_ ,q) row))
        (insert (propertize (concat "  " day "  " (bqn-book--cell (bqn-book--plan-name row names) 30)
                                    "  " (bqn-book--cell m 4) " " (bqn-book--cell (funcall Money q m) 12 t)
                                    (if (string< day today) (propertize "  overdue" 'face 'warning) "")
                                    "\n")
                            'bqn-book-plan id))))
    ;; recent entries
    (insert "\n" (propertize "Recent entries" 'face 'bold) "\n")
    (dolist (row (last (bqn-book--rows file "entries") 5))
      (insert (propertize (format "  %s  %s\n" (nth 1 row)
                                  (if (string-empty-p (nth 2 row)) (propertize "(no memo)" 'face 'shadow)
                                    (bqn-book--shown (nth 2 row))))
                          'bqn-book-entry (car row))))
    (insert "\n" (propertize "? keys" 'face 'shadow) "\n")
    (goto-char (min point (point-max)))))

;;;###autoload
(defun bqn-book-home (file)
  "Show the book FILE at a glance."
  (interactive (list (or bqn-book-file (read-file-name "book.txt: " nil nil t))))
  (let ((buffer (get-buffer-create (format "*book home %s*" (abbreviate-file-name file)))))
    (with-current-buffer buffer
      (bqn-book-home-mode)
      (setq bqn-book--file (expand-file-name file))
      (bqn-book--draw-home))
    (pop-to-buffer-same-window buffer)
    buffer))

(defun bqn-book--plan-at-point (what)
  "The open plan at point: a home line, or a series' row; else say how to WHAT."
  (or (get-text-property (point) 'bqn-book-plan)
      (and (derived-mode-p 'bqn-book-series-plans-mode) (tabulated-list-get-id))
      (user-error "Move to an open plan to %s" what)))

(defun bqn-book-home-open ()
  "On the home, RET: pay the plan at point, or correct the entry at point."
  (interactive)
  (if (get-text-property (point) 'bqn-book-entry)
      (bqn-book-correct-entry)
    (bqn-book-pay-plan)))

(defun bqn-book--plan-change (plan)
  "PLAN as the change that would keep it: PUT-PLAN REPLACE, its PLAN line second."
  (pcase (bqn-book--call bqn-book--file (list "plan" plan))
    (`(0 . ,lines) lines)
    (`(,_ . ,lines) (user-error "%s" (string-join lines " ")))))

(defun bqn-book--typed-day (text)
  "TEXT as YYYY-MM-DD when typed as the Record form takes a day: 2027/2/8,
2027.02.08, full-width digits; else TEXT, for the book to refuse."
  (let ((s (japanese-hankaku (string-trim text) t)))
    (if (string-match "\\`\\([0-9]\\{4\\}\\)\\([-/.]\\)\\([0-9]\\{1,2\\}\\)\\2\\([0-9]\\{1,2\\}\\)\\'" s)
        (format "%s-%02d-%02d" (match-string 1 s)
                (string-to-number (match-string 3 s)) (string-to-number (match-string 4 s)))
      text)))

(defun bqn-book-move-plan ()
  "Move the open plan at point to another due day, after a preview.
Its ID, accounts and amounts stay."
  (interactive)
  (let* ((plan (bqn-book--plan-at-point "move its day"))
         (lines (bqn-book--plan-change plan))
         (fields (split-string (nth 1 lines) "\t"))
         (day (read-string (format "Due day (now %s): " (nth 2 fields)) (nth 2 fields))))
    (setf (nth 2 fields) (bqn-book--typed-day day)
          (nth 1 lines) (string-join fields "\t"))
    (bqn-book--save-change bqn-book--file lines (current-buffer))))

(defun bqn-book-cancel-plan ()
  "Cancel the open plan at point, today, after a preview. It is kept, marked
cancelled: nothing is erased."
  (interactive)
  (let ((plan (bqn-book--plan-at-point "cancel it")))
    (bqn-book--save-change bqn-book--file
                           (list (string-join (list "CANCEL-PLAN" plan (bqn-book--day-today)) "\t"))
                           (current-buffer))))

(defun bqn-book-edit-plan ()
  "Change the open plan at point in a form: its due day, accounts and amounts."
  (interactive)
  (let ((plan (bqn-book--plan-at-point "change it")))
    (pcase (bqn-book--call bqn-book--file (list "open" "PLAN" plan))
      (`(0 . ,rows)
       (let ((day (nth 2 (split-string (nth 1 (bqn-book--plan-change plan)) "\t"))))
         (bqn-book--form-buffer bqn-book--file (current-buffer) "PLAN" plan
                                (cons (concat "DAY\t" day) rows))))
      (`(,_ . ,lines) (bqn-book--refusal lines)))))

(defun bqn-book-edit-plan-as-change ()
  "Open the open plan at point as a change, in bakhlo's change language."
  (interactive)
  (let ((plan (bqn-book--plan-at-point "edit it")))
    (bqn-book--change (bqn-book--plan-change plan) plan)))

(defun bqn-book--fill-months (source every list)
  "Add plans like SOURCE (the last of its series) in the coming months, EVERY
months apart by default, after a preview, as bk plans more does. A month without
SOURCE's day is dated by the person, or skipped."
  (let* ((file bqn-book--file)
         (anchor (nth 1 (assoc source (bqn-book--rows file "plans"))))
         (months (bqn-book--ask-number "Every how many months" every 1 12))
         (count (bqn-book--ask-number "How many more" 3 1 24))
         (days '()))
    (dolist (slot (bqn-book--rows file (list "slots" anchor (number-to-string months) (number-to-string count))))
      (pcase slot
        (`(,day) (push day days))
        (`("MISSING" ,month ,d)
         (let ((day (bqn-book--ask-missing month d anchor)))
           (when day (push day days))))))
    (if (null days)
        (message "No plans to add.")
      (pcase (bqn-book--call file (list "more" source) (concat (string-join (nreverse days) "\n") "\n"))
        (`(0 . ,change) (bqn-book--save-change file change list))
        (`(,_ . ,lines) (bqn-book--refusal lines))))))

(defun bqn-book--ask-number (prompt default low high)
  "Ask for a whole number from LOW to HIGH, DEFAULT on Enter, until one is given."
  (let ((n (string-to-number (read-string (format "%s (%d-%d): " prompt low high) nil nil
                                          (number-to-string default)))))
    (if (<= low n high) n
      (message "Enter %d to %d." low high)
      (sit-for 1)
      (bqn-book--ask-number prompt default low high))))

(defun bqn-book--real-day-p (day)
  "Whether DAY is a real YYYY-MM-DD date: 2027-02-30 is not."
  (and (string-match "\\`\\([0-9]\\{4\\}\\)-\\([0-9][0-9]\\)-\\([0-9][0-9]\\)\\'" day)
       (let ((y (string-to-number (match-string 1 day)))
             (m (string-to-number (match-string 2 day)))
             (d (string-to-number (match-string 3 day))))
         (and (<= 1 y) (<= 1 m 12) (<= 1 d (date-days-in-month y m))))))

(defun bqn-book--ask-missing (month day after)
  "MONTH has no DAY: ask for its date, after AFTER; nil when skipped."
  (let ((text (read-string (format "%s has no day %s. Date (empty skips that month): " month day))))
    (cond ((string-empty-p text) nil)
          ((let ((d (bqn-book--typed-day text)))
             (and (bqn-book--real-day-p d) (string< after d) d)))
          (t (message "Enter a real date after %s, or nothing to skip." after)
             (sit-for 1)
             (bqn-book--ask-missing month day after)))))

(defun bqn-book-reprice ()
  "Give a series' open plans a new amount from a day on, as bk plans amount does:
in a series' plans, from the plan at point; in the series list, from a day asked
for. Each account's sign stays; a plan already at that amount is left out, and a
split plan is refused (change it on its own)."
  (interactive)
  (let* ((file bqn-book--file)
         (rows (bqn-book--rows file "plans"))
         (ids (if (derived-mode-p 'bqn-book-series-mode)
                  (split-string (or (tabulated-list-get-id) (user-error "No series here")) "," t)
                bqn-book--series-ids))
         (from (if (derived-mode-p 'bqn-book-series-mode)
                   (bqn-book--typed-day (read-string "From: " (bqn-book--day-today)))
                 (nth 1 (assoc (bqn-book--plan-at-point "change amounts from it") rows))))
         (chosen (seq-filter (lambda (id) (not (string< (nth 1 (assoc id rows)) from))) ids)))
    (unless chosen (user-error "No open plan in this series from %s" from))
    (let ((amount (read-string (format "New amount from %s: " from))))
      (pcase (bqn-book--call file (list "reprice" amount) (concat (string-join chosen "\n") "\n"))
        (`(0 . ,change) (bqn-book--save-change file change (current-buffer)))
        (`(,_ "REFUSED\tunchanged") (message "Every plan already has that amount."))
        (`(,_ ,(and line (pred (string-prefix-p "REFUSED\tsplit-plan:"))))
         (message "%s is split between accounts: change it on its own (e)." (substring line 20)))
        (`(,_ . ,lines) (bqn-book--refusal lines))))))

(defun bqn-book-fill-months ()
  "Fill the coming months of the series at point, or of this series' plans."
  (interactive)
  (pcase-let ((`(,ids . ,every)
               (if (derived-mode-p 'bqn-book-series-mode)
                   (let ((ids (or (tabulated-list-get-id) (user-error "No series here"))))
                     (cons (split-string ids "," t) (cdr (assoc ids bqn-book--series-every))))
                 (cons bqn-book--series-ids bqn-book--series-every))))
    (bqn-book--fill-months (car (last ids)) (if (and every (> every 0)) every 1) (current-buffer))))

(defun bqn-book-pay-plan ()
  "Pay the open plan at point: a form with its accounts and amounts, dated today.
Change an amount to pay a different one; C-c C-c previews and saves."
  (interactive)
  (let ((plan (bqn-book--plan-at-point "pay it")))
    (pcase (bqn-book--call bqn-book--file (list "open" "PLAN" plan))
      (`(0 . ,rows)
       (bqn-book--form-buffer bqn-book--file (current-buffer) "PAY" plan
                              (append (list (concat "DAY\t" (bqn-book--day-today)) "MEMO\t") rows)))
      (`(,_ . ,lines) (bqn-book--refusal lines)))))

(defun bqn-book-home-entries ()
  "The entries of this home's book."
  (interactive)
  (bqn-book-entries bqn-book--file))

;;;; Plans in series: what bk plans lists

(defun bqn-book--names (file)
  "FILE's accounts: (id . name)."
  (mapcar (lambda (r) (cons (car r) (bqn-book--shown (nth 1 r)))) (bqn-book--rows file "loci")))

(defun bqn-book--scale (file measure)
  "How many decimals MEASURE has in FILE."
  (string-to-number (or (cadr (assoc measure (bqn-book--rows file "measures"))) "0")))

(defun bqn-book--named (ids names)
  "IDS (joined by commas) by their NAMES, joined by +."
  (mapconcat (lambda (l) (or (cdr (assoc l names)) l)) (split-string ids "," t) " + "))

(defvar bqn-book-series-mode-map (make-sparse-keymap))
(define-keymap :keymap bqn-book-series-mode-map   ; again on reload: a new key takes effect
  :parent tabulated-list-mode-map
  "RET" #'bqn-book-series-plans
  "a" #'bqn-book-reprice
  "m" #'bqn-book-fill-months
  "n" #'bqn-book-new-plan
  "g" #'revert-buffer
  "?" #'bqn-book-keys)

(define-derived-mode bqn-book-series-mode tabulated-list-mode "Book series"
  "Open plans in series, as bk plans lists them: the same accounts paying and
receiving, whatever the amounts. RET shows a series' plans."
  (setq tabulated-list-format
        [("From" 14 t) ("To" 18 t) ("Amount" 10 nil :right-align t) ("" 4 t)
         ("Next" 10 t) ("Last" 10 t) ("Open" 4 nil :right-align t) ("" 0 nil)])
  (setq tabulated-list-padding 1)
  (add-hook 'tabulated-list-revert-hook #'bqn-book--series nil t)
  (display-line-numbers-mode -1)
  (tabulated-list-init-header))

(defun bqn-book--cadence (months)
  "bk's word for a coverage rule's MONTHS."
  (pcase months ("0" "undecided") ("1" "monthly") ("12" "yearly") (_ (format "every %sm" months))))

(defvar-local bqn-book--series-every nil
  "In a series list, (IDS . months) of each series a coverage rule watches; in a
series' plans, its months, or nil.")

(defun bqn-book--series ()
  "Fill the series buffer from bin/book."
  (let* ((file bqn-book--file)
         (today (bqn-book--day-today))
         (names (bqn-book--names file)))
    (setq bqn-book--series-every nil)
    (setq tabulated-list-entries
          (mapcar (lambda (row)
                    (pcase-let ((`(,from ,to ,q ,m ,next ,last ,count ,every ,missing ,ids) row))
                      (unless (string-empty-p every)
                        (push (cons ids (string-to-number every)) bqn-book--series-every))
                      (list ids
                            (vector (bqn-book--named from names) (bqn-book--named to names)
                                    (if (equal q "split") "split" (bqn-book--money q (bqn-book--scale file m)))
                                    m next last count
                                    (string-join
                                     (delq nil (list (and (string< next today) (propertize "overdue" 'face 'warning))
                                                     (and (not (string-empty-p every)) (bqn-book--cadence every))
                                                     (and (not (string-empty-p missing))
                                                          (propertize (concat "missing " missing) 'face 'warning))))
                                     ", ")))))
                  (bqn-book--rows file (list "series" today))))))

(defun bqn-book-home-series ()
  "The open plans of this home's book, in series."
  (interactive)
  (let ((file bqn-book--file) (today bqn-book--today)
        (buffer (get-buffer-create (format "*book series %s*" (abbreviate-file-name bqn-book--file)))))
    (with-current-buffer buffer
      (bqn-book-series-mode)
      (setq bqn-book--file file bqn-book--today today)
      (bqn-book--series)
      (tabulated-list-print))
    (pop-to-buffer-same-window buffer)
    (message "? keys")
    buffer))

(defvar-local bqn-book--series-ids nil "The plans this series buffer shows.")

(defvar bqn-book-series-plans-mode-map (make-sparse-keymap))
(define-keymap :keymap bqn-book-series-plans-mode-map   ; again on reload: a new key takes effect
  :parent tabulated-list-mode-map
  "RET" #'bqn-book-pay-plan
  "p" #'bqn-book-pay-plan
  "d" #'bqn-book-move-plan
  "c" #'bqn-book-cancel-plan
  "e" #'bqn-book-edit-plan
  "E" #'bqn-book-edit-plan-as-change
  "a" #'bqn-book-reprice
  "m" #'bqn-book-fill-months
  "n" #'bqn-book-new-plan
  "g" #'revert-buffer
  "?" #'bqn-book-keys)

(define-derived-mode bqn-book-series-plans-mode tabulated-list-mode "Book plans"
  "One series' open plans by day. RET pays the plan at point."
  (setq tabulated-list-format [("Due" 10 t) ("Amount" 10 nil :right-align t) ("" 4 t) ("" 0 nil)])
  (setq tabulated-list-padding 1)
  (add-hook 'tabulated-list-revert-hook #'bqn-book--series-plans nil t)
  (display-line-numbers-mode -1)
  (tabulated-list-init-header))

(defun bqn-book--series-plans ()
  "Fill a series' plans buffer: those of its plans still open."
  (let* ((file bqn-book--file)
         (today (bqn-book--day-today))
         (rows (bqn-book--rows file "plans")))
    (setq tabulated-list-entries
          (delq nil
                (mapcar (lambda (id)
                          (pcase (assoc id rows)
                            (`(,id ,day ,m "open" ,_ ,q . ,_)
                             (list id (vector day (bqn-book--money q (bqn-book--scale file m)) m
                                              (if (string< day today) (propertize "overdue" 'face 'warning) ""))))))
                        bqn-book--series-ids)))))

(defun bqn-book-series-plans ()
  "The plans of the series at point."
  (interactive)
  (let ((ids (tabulated-list-get-id))
        (every nil)
        (title (aref (tabulated-list-get-entry) 1))
        (file bqn-book--file) (today bqn-book--today) (series (current-buffer)))
    (unless ids (user-error "No series here"))
    (setq every (cdr (assoc ids bqn-book--series-every)))
    (let ((buffer (get-buffer-create (format "*book plans → %s*" title))))
      (with-current-buffer buffer
        (bqn-book-series-plans-mode)
        (setq bqn-book--file file bqn-book--today today
              bqn-book--series-ids (split-string ids "," t)
              bqn-book--series-every every
              bqn-book--list-buffer series)
        (bqn-book--series-plans)
        (tabulated-list-print))
      (pop-to-buffer-same-window buffer)
      (message "? keys")
      buffer)))

;;;; Accounts: what bk loci shows, adds and names

(defvar bqn-book-accounts-mode-map (make-sparse-keymap))
(define-keymap :keymap bqn-book-accounts-mode-map   ; again on reload: a new key takes effect
  :parent tabulated-list-mode-map
  "+" #'bqn-book-add-account
  "r" #'bqn-book-name-account
  "R" #'bqn-book-set-role
  "g" #'revert-buffer
  "?" #'bqn-book-keys)

(define-derived-mode bqn-book-accounts-mode tabulated-list-mode "Book accounts"
  "The book's accounts: name, ID, role, and whether new entries are offered it."
  (setq tabulated-list-format [("Name" 20 t) ("ID" 16 t) ("Role" 10 t) ("" 0 nil)])
  (setq tabulated-list-padding 1)
  (add-hook 'tabulated-list-revert-hook #'bqn-book--accounts-list nil t)
  (display-line-numbers-mode -1)
  (tabulated-list-init-header))

(defun bqn-book--accounts-list ()
  "Fill the accounts buffer from bin/book."
  (setq tabulated-list-entries
        (mapcar (lambda (row)
                  (pcase-let ((`(,id ,label ,_help ,hidden ,role) row))
                    (list id (vector (bqn-book--shown label) id (downcase role)
                                     (if (equal hidden "HIDDEN") (propertize "hidden" 'face 'shadow) "")))))
                (bqn-book--rows bqn-book--file "loci"))))

(defun bqn-book-home-accounts ()
  "The accounts of this home's book."
  (interactive)
  (let ((file bqn-book--file)
        (buffer (get-buffer-create (format "*book accounts %s*" (abbreviate-file-name bqn-book--file)))))
    (with-current-buffer buffer
      (bqn-book-accounts-mode)
      (setq bqn-book--file file)
      (bqn-book--accounts-list)
      (tabulated-list-print))
    (pop-to-buffer-same-window buffer)
    (message "? keys")
    buffer))

(defun bqn-book--read-role (prompt)
  "Ask for a role by its first letters; nil for none."
  (let* ((roles '("asset" "liability" "equity" "income" "expense"))
         (answer (completing-read prompt (cons "-" roles) nil t)))
    (unless (member answer '("" "-")) (upcase answer))))

(defun bqn-book--escaped (text)
  "TEXT as a change's field holds it: \\, tab and newlines escaped."
  (replace-regexp-in-string "[\\\t\n\r]"
                            (lambda (c) (pcase c ("\\" "\\\\") ("\t" "\\t") ("\n" "\\n") ("\r" "\\r")))
                            text t t))

(defun bqn-book-add-account ()
  "Add an account as bk loci add does: its ID (one word, used inside the book),
its name (its ID when left as is) and a role (or none), after a preview. An
account that was hidden is offered again."
  (interactive)
  (let* ((id (string-trim (read-string "ID (one word, used inside the book): ")))
         (name (read-string "Name: " nil nil id))
         (role (bqn-book--read-role "Role (asset, liability, equity, income, expense, or - for none): ")))
    (bqn-book--save-change
     bqn-book--file
     (append (list (concat "ADD-LOCUS\t" id))
             (unless (equal name id) (list (concat "SET-LOCUS-LABEL\t" id "\t" (bqn-book--escaped name))))
             (when role (list (concat "SET-ROLE\t" id "\t" role))))
     (current-buffer))))

(defun bqn-book-name-account ()
  "Give the account at point a new name, after a preview."
  (interactive)
  (let* ((id (or (tabulated-list-get-id) (user-error "No account here")))
         (old (aref (tabulated-list-get-entry) 0))
         (name (read-string (format "New name for %s: " old) old)))
    (bqn-book--save-change bqn-book--file
                           (list (concat "SET-LOCUS-LABEL\t" id "\t" (bqn-book--escaped name)))
                           (current-buffer))))

(defun bqn-book-set-role ()
  "Give the account at point its role, once: roles are never replaced."
  (interactive)
  (let* ((id (or (tabulated-list-get-id) (user-error "No account here")))
         (role (bqn-book--read-role (format "Role for %s: " (aref (tabulated-list-get-entry) 0)))))
    (when role
      (bqn-book--save-change bqn-book--file (list (concat "SET-ROLE\t" id "\t" role)) (current-buffer)))))

(provide 'bqn-book)
;;; bqn-book.el ends here
