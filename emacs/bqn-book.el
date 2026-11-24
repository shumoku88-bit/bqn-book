;;; bqn-book.el --- bakhlo's book.txt in Emacs, through bqn-book's bin/book  -*- lexical-binding: t; -*-

;; A screen for bqn-book. It never reads or writes book.txt itself: every list and
;; every change goes through bin/book, in tab-separated lines (README.md).
;;
;;   M-x bqn-book-entries   the entries of `bqn-book-file', in recorded order
;;     RET   open the entry as a change: edit it, C-c C-p to preview, C-c C-c to save
;;     +     a new entry, from a template
;;     g     read the book again
;;   M-x bqn-book-demo      the same on a copy of a synthetic sample book
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
  "RET" #'bqn-book-edit-entry
  "+" #'bqn-book-new-entry
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
    (pop-to-buffer-same-window buffer)))

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
    (bqn-book-entries copy)))

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

(defun bqn-book--new-id ()
  "A fresh entry ID, as bakhlo makes them: entry- and 24 hex digits."
  (concat "entry-" (substring (secure-hash 'sha256 (format "%s%s" (random) (current-time))) 0 24)))

(defun bqn-book-new-entry ()
  "Open a template for a new entry."
  (interactive)
  (let ((measure (caar (bqn-book--rows bqn-book--file "measures"))))
    (bqn-book--change
     (list "PUT-ENTRY\tNEW\t-"
           (format "TX\t%s\t%s\tDESC\t" (bqn-book--new-id) (format-time-string "%Y-%m-%d"))
           (format "EFFECT\t\t%s\t" measure)
           (format "EFFECT\t\t%s\t" measure)
           "ENDTX")
     "new")))

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

(provide 'bqn-book)
;;; bqn-book.el ends here
