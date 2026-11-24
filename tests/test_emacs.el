;;; test_emacs.el --- the Emacs screen on a copy of a synthetic book  -*- lexical-binding: t; -*-
;; emacs --batch -l tests/test_emacs.el -f ert-run-tests-batch-and-exit

(require 'ert)
(load (expand-file-name "../emacs/bqn-book.el" (file-name-directory load-file-name)) nil t)

(defun test-bqn-book--copy ()
  "A copy of the scheduled sample book in a fresh directory."
  (let ((copy (expand-file-name "book.txt" (make-temp-file "bqn-book-test" t))))
    (copy-file (expand-file-name "../tests/fixtures/scheduled/base.txt"
                                 (file-name-directory bqn-book-command))
               copy)
    copy))

(ert-deftest bqn-book-lists-entries-in-recorded-order ()
  (let ((bqn-book-file nil) (copy (test-bqn-book--copy)))
    (with-current-buffer (save-window-excursion (bqn-book-entries copy) (current-buffer))
      (should (equal (mapcar #'car tabulated-list-entries) '("tx-0001" "tx-0002" "tx-0003" "tx-0004")))
      (should (equal (aref (cadr (assoc "tx-0001" tabulated-list-entries)) 3) "January pay")))))

(ert-deftest bqn-book-edits-an-entry-and-saves-it ()
  (let* ((copy (test-bqn-book--copy))
         (list (save-window-excursion (bqn-book-entries copy) (current-buffer))))
    (with-current-buffer list
      (goto-char (point-min))
      (search-forward "tx-0002")
      (save-window-excursion (bqn-book-edit-entry)))
    (let ((change (get-buffer "*book change tx-0002*")))
      (with-current-buffer change
        (should (string-prefix-p "PUT-ENTRY\tREPLACE\t-\nTX\ttx-0002" (buffer-string)))
        (goto-char (point-min))
        (while (search-forward "20000" nil t) (replace-match "21000"))
        (bqn-book-save))
      (should-not (buffer-live-p change)))
    (with-temp-buffer
      (insert-file-contents copy)
      (should (search-forward "EFFECT\tbank\tjpy\t-21000" nil t)))))

(ert-deftest bqn-book-refuses-and-keeps-the-change ()
  (let* ((copy (test-bqn-book--copy))
         (before (with-temp-buffer (insert-file-contents copy) (buffer-string)))
         (list (save-window-excursion (bqn-book-entries copy) (current-buffer))))
    (with-current-buffer list (save-window-excursion (bqn-book-new-entry)))
    (let ((change (car (seq-filter (lambda (b) (string-prefix-p "*book change new" (buffer-name b)))
                                   (buffer-list)))))
      (with-current-buffer change
        (should (string-prefix-p "PUT-ENTRY\tNEW\t-\nTX\tentry-" (buffer-string)))
        (bqn-book-save)                 ; the template has no amounts yet
        (should (buffer-live-p change))
        (kill-buffer change)))
    (should (equal before (with-temp-buffer (insert-file-contents copy) (buffer-string))))))

;;; test_emacs.el ends here
