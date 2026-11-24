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
;;                          + new entry, l entries, g reread
;;   M-x bqn-book-demo      the home of a copy of a synthetic sample book
;;
;; Text in a change is written as in book.txt: a memo's tab is \t, a backslash \\.

;;; Code:

(require 'tabulated-list)
(require 'subr-x)

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
  "The rows bin/book lists for COMMAND on FILE, each a list of fields."
  (pcase (bqn-book--call file (list command))
    (`(0 . ,lines) (mapcar (lambda (line) (split-string line "\t")) lines))
    (`(,_ . ,lines) (user-error "bin/book %s: %s" command (string-join lines " ")))))

(defun bqn-book--shown (text)
  "TEXT as written in book.txt, made readable on one line."
  (replace-regexp-in-string
   "\\\\\\(.\\)"
   (lambda (m) (pcase (match-string 1 m) ("t" " ") ("n" " ⏎ ") ("r" "") (c c)))
   text t t))

;;;; Entries

(defvar-local bqn-book--file nil "The book.txt this buffer shows or changes.")

(defvar-keymap bqn-book-entries-mode-map
  :parent tabulated-list-mode-map
  "RET" #'bqn-book-correct-entry
  "+" #'bqn-book-new-entry
  "r" #'bqn-book-refund-entry
  "e" #'bqn-book-edit-entry
  "g" #'bqn-book-refresh)

(define-derived-mode bqn-book-entries-mode tabulated-list-mode "Book"
  "The entries of a book.txt, in recorded order."
  (setq tabulated-list-format
        [("#" 5 (lambda (a b) (< (car a) (car b))) :right-align t)
         ("Day" 10 t) ("ID" 16 t) ("Memo" 32 t) ("Merchant" 14 t)
         ("Reverses" 10 t) ("Pays" 14 t)])
  (setq tabulated-list-padding 1)
  (add-hook 'tabulated-list-revert-hook #'bqn-book--list nil t)
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
    (message "+ new entry   RET correct   r refund   e edit as a change   g reread")))

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

(defvar-keymap bqn-book-change-mode-map
  "C-c C-p" #'bqn-book-preview
  "C-c C-c" #'bqn-book-save
  "C-c C-k" #'bqn-book-discard
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
    (message "C-c C-p preview, C-c C-c save, C-c C-k discard")))

(defun bqn-book-edit-entry ()
  "Open the entry at point as a change that would keep it."
  (interactive)
  (let ((id (tabulated-list-get-id)))
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
     (let ((list bqn-book--list-buffer))
       (kill-buffer)
       (when (buffer-live-p list)
         (with-current-buffer list (revert-buffer)))
       (message "Saved.")))
    (`(,_ . ,lines) (bqn-book--refusal lines))))

(defun bqn-book-discard ()
  "Close this change without saving."
  (interactive)
  (kill-buffer))

;;;; The Record form

(defun bqn-book--accounts (file)
  "The accounts offered for new entries in FILE: (\"name (id)\" . id)."
  (delq nil (mapcar (lambda (row)
                      (pcase-let ((`(,id ,label ,_help ,hidden ,_role) row))
                        (unless (equal hidden "HIDDEN")
                          (cons (format "%s (%s)" (bqn-book--shown label) id) id))))
                    (bqn-book--rows file "loci"))))

(defun bqn-book--read-account (file prompt)
  "Ask for an account of FILE by its name; nil when left empty."
  (let* ((accounts (bqn-book--accounts file))
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
       (special-mode))
     (display-buffer "*book preview*")
     (when (y-or-n-p "Save this? ")
       (pcase (bqn-book--call file '("save") (concat (string-join change "\n") "\n"))
         (`(0 . ,_)
          (when (buffer-live-p list) (with-current-buffer list (revert-buffer)))
          (message "Saved.") t)
         (`(,_ . ,lines) (bqn-book--refusal lines) nil))))
    (`(,_ . ,lines) (bqn-book--refusal lines) nil)))

(defun bqn-book--fill (file mode target lines)
  "The change FILE's form MODE (NEW, EDIT, PAY) with TARGET makes of LINES, or nil."
  (pcase (bqn-book--call file (list "form" mode target) (concat (string-join lines "\n") "\n"))
    (`(0 . ,change) change)
    (`(,_ . ,out) (bqn-book--refusal out) nil)))

(defvar-local bqn-book--form nil "The form's (MODE TARGET).")

(defvar-keymap bqn-book-form-mode-map
  "C-c C-c" #'bqn-book-form-submit
  "C-c C-a" #'bqn-book-form-insert-account
  "C-c C-k" #'bqn-book-discard
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
    (message "C-c C-c preview and save, C-c C-a account, C-c C-k discard")
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
         (memo (read-string "Memo: "))
         (measures (mapcar #'car (bqn-book--rows file "measures")))
         (measure (if (cdr measures) (completing-read "Measure: " measures nil t nil nil (car measures))
                    (car measures)))
         (rows '()))
    (while (let ((account (bqn-book--read-account
                           file (format "Account %d (empty to finish): " (1+ (length rows))))))
             (when account
               (push (format "ROW\t-\t%s\t%s" account
                             (read-string (format "Amount for %s (-1200, +500+300): " account)))
                     rows))))
    (let* ((lines (append (list (concat "DAY\t" day) (concat "MEMO\t" memo) (concat "MEASURE\t" measure))
                          (nreverse rows)))
           (change (bqn-book--fill file "NEW" "-" lines)))
      (if change
          (bqn-book--save-change file change list)
        ;; refused: keep what was typed in a form, to fix and try again
        (bqn-book--form-buffer file list "NEW" "-" lines)))))

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
  (let ((id (tabulated-list-get-id)))
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
  "The accounts today's guide counts as money to spend, like (\"bank\" \"wallet\")."
  :type '(repeat string))

(defvar-local bqn-book--today nil "The day the home counts from; nil for today.")
(defvar-local bqn-book--pool nil "The guide's accounts in this home; nil for `bqn-book-pace-pool'.")

(defun bqn-book--day-today ()
  (or bqn-book--today (format-time-string "%Y-%m-%d")))

(defun bqn-book--next-month (day)
  "The first day of the month after DAY (YYYY-MM-DD)."
  (let* ((y (string-to-number (substring day 0 4)))
         (m (string-to-number (substring day 5 7))))
    (if (= m 12) (format "%04d-01-01" (1+ y)) (format "%04d-%02d-01" y (1+ m)))))

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

(defvar-keymap bqn-book-home-mode-map
  :parent special-mode-map
  "+" #'bqn-book-new-entry
  "l" #'bqn-book-home-entries
  "g" #'revert-buffer)

(define-derived-mode bqn-book-home-mode special-mode "Book home"
  "A book at a glance: today's guide, balances, open plans and recent entries."
  (setq-local revert-buffer-function (lambda (&rest _) (bqn-book--draw-home))))

(defun bqn-book--draw-home ()
  (let* ((inhibit-read-only t)
         (file bqn-book--file)
         (today (bqn-book--day-today))
         (end (bqn-book--next-month today))
         (scales (mapcar (lambda (r) (cons (car r) (string-to-number (cadr r))))
                         (bqn-book--rows file "measures")))
         (measure (caar scales))
         (Money (lambda (q m) (bqn-book--money q (or (cdr (assoc m scales)) 0))))
         (names (mapcar (lambda (r) (cons (car r) (bqn-book--shown (nth 1 r))))
                        (bqn-book--rows file "loci")))
         (pool (or bqn-book--pool bqn-book-pace-pool))
         (point (point)))
    (erase-buffer)
    (insert (propertize (abbreviate-file-name file) 'face 'bold) "    " today "\n\n")
    ;; today's guide
    (insert (propertize "Today's guide" 'face 'bold))
    (if (null pool)
        (insert "\n  Set `bqn-book-pace-pool' to the accounts you spend from.\n\n")
      (let ((answer (cdr (bqn-book--call
                          file '("ask")
                          (concat (string-join (list "PACE" measure today end) "\t") "\n"
                                  (mapconcat (lambda (p) (concat "POOL\t" p "\n")) pool ""))))))
        (insert (format "  %s, until %s\n" measure end))
        (dolist (line answer)
          (pcase (split-string line "\t")
            (`("BALANCE" ,locus ,q) (insert (format "  %-14s %12s  %s\n" "Spendable" (funcall Money q measure)
                                                    (or (cdr (assoc locus names)) locus))))
            (`("DEDUCTION" ,plan ,q) (insert (format "  %-14s %12s  %s\n" "Set aside" (funcall Money (concat "-" q) measure) plan)))
            (`("AVAILABLE" ,q) (insert (format "  %-14s %12s\n" "Left" (funcall Money q measure))))
            (`("DAYS" ,n) (insert (format "  %-14s %12s\n" "Days" n)))
            (`("DAILY" ,q) (insert (propertize (format "  %-14s %12s\n" "Per day" (funcall Money q measure)) 'face 'success)))
            (`("REFUSED" ,why) (insert (format "  Not known: %s\n" why)))))
        (insert "\n")))
    ;; balances
    (insert (propertize "Balances" 'face 'bold) "\n")
    (let ((unknown 0))
      (dolist (row (bqn-book--rows file "balances"))
        (pcase-let ((`(,locus ,m ,q) row))
          (if (equal q "?") (setq unknown (1+ unknown))
            (insert (format "  %-14s %-4s %12s\n" (or (cdr (assoc locus names)) locus) m (funcall Money q m))))))
      (when (> unknown 0) (insert (format "  (%d with no known balance)\n" unknown))))
    ;; open plans
    (insert "\n" (propertize "Open plans" 'face 'bold) "\n")
    (dolist (row (sort (seq-filter (lambda (r) (equal (nth 3 r) "open")) (bqn-book--rows file "plans"))
                       (lambda (a b) (string< (nth 1 a) (nth 1 b)))))
      (pcase-let ((`(,id ,day ,m ,_ ,_ ,q) row))
        (insert (format "  %s  %-18s %-4s %12s%s\n" day id m (funcall Money q m)
                        (if (string< day today) "  overdue" "")))))
    ;; recent entries
    (insert "\n" (propertize "Recent entries" 'face 'bold) "\n")
    (dolist (row (last (bqn-book--rows file "entries") 5))
      (insert (format "  %s  %s\n" (nth 1 row)
                      (if (string-empty-p (nth 2 row)) (propertize "(no memo)" 'face 'shadow)
                        (bqn-book--shown (nth 2 row))))))
    (insert "\n" (propertize "+ new entry   l entries   g reread" 'face 'shadow) "\n")
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

(defun bqn-book-home-entries ()
  "The entries of this home's book."
  (interactive)
  (bqn-book-entries bqn-book--file))

(provide 'bqn-book)
;;; bqn-book.el ends here
