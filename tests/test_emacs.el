;;; test_emacs.el --- the Emacs screen on a copy of a synthetic book  -*- lexical-binding: t; -*-
;; emacs --batch -l tests/test_emacs.el -f ert-run-tests-batch-and-exit

(require 'ert)
(require 'cl-lib)
(load (expand-file-name "../emacs/bqn-book.el" (file-name-directory load-file-name)) nil t)

(defun test-bqn-book--copy ()
  "A copy of the scheduled sample book in a fresh directory."
  (let ((copy (expand-file-name "book.txt" (make-temp-file "bqn-book-test" t))))
    (copy-file (expand-file-name "../tests/fixtures/scheduled/base.txt"
                                 (file-name-directory bqn-book-command))
               copy)
    copy))

(defun test-bqn-book--text (file)
  (with-temp-buffer (insert-file-contents file) (buffer-string)))

(defmacro test-bqn-book--answering (answers &rest body)
  "Run BODY with the minibuffer answering ANSWERS in turn, and saying yes."
  `(let ((answers ,answers))
     (cl-letf (((symbol-function 'read-string) (lambda (&rest _) (pop answers)))
               ((symbol-function 'completing-read) (lambda (&rest _) (pop answers)))
               ((symbol-function 'y-or-n-p) (lambda (&rest _) t)))
       ,@body)))

(defun test-bqn-book--list (copy)
  (save-window-excursion (bqn-book-entries copy) (current-buffer)))

(ert-deftest bqn-book-lists-entries-in-recorded-order ()
  (with-current-buffer (test-bqn-book--list (test-bqn-book--copy))
    (should (equal (mapcar #'car tabulated-list-entries) '("tx-0001" "tx-0002" "tx-0003" "tx-0004")))
    (should (equal (aref (cadr (assoc "tx-0001" tabulated-list-entries)) 3) "January pay"))))

(ert-deftest bqn-book-records-a-new-entry-asked-field-by-field ()
  (let* ((copy (test-bqn-book--copy)) (list (test-bqn-book--list copy)))
    (with-current-buffer list
      (test-bqn-book--answering
       '("2027/2/3" "lunch" "bank  Bank" "-(500+300)/2" "wallet  Wallet" "+400" "")
       (save-window-excursion (bqn-book-new-entry))))
    (should (string-match-p "\tDESC\tlunch\nEFFECT\tbank\tjpy\t-400\nEFFECT\twallet\tjpy\t400\nENDTX"
                            (test-bqn-book--text copy)))
    (with-current-buffer list (should (= 5 (length tabulated-list-entries))))))

(ert-deftest bqn-book-corrects-an-entry-in-a-form ()
  (let* ((copy (test-bqn-book--copy)) (list (test-bqn-book--list copy)))
    (with-current-buffer list
      (goto-char (point-min))
      (search-forward "tx-0002")
      (save-window-excursion (bqn-book-correct-entry)))
    (let ((form (get-buffer "*book form tx-0002*")))
      (with-current-buffer form
        (should (equal (buffer-string)
                       "DAY\t2027-01-05\nMEMO\t\nMEASURE\tjpy\nROW\t-\tbank\t-20000\nROW\t-\twallet\t20000\n"))
        (goto-char (point-min))
        (while (search-forward "20000" nil t) (replace-match "21000"))
        (test-bqn-book--answering '() (bqn-book-form-submit)))
      (should-not (buffer-live-p form)))
    (should (string-match-p "TX\ttx-0002\t2027-01-05\nEFFECT\tbank\tjpy\t-21000" (test-bqn-book--text copy)))))

(ert-deftest bqn-book-keeps-a-refused-form-to-fix ()
  (let* ((copy (test-bqn-book--copy))
         (before (test-bqn-book--text copy))
         (list (test-bqn-book--list copy)))
    (with-current-buffer list
      (test-bqn-book--answering '("2027-02-03" "" "bank  Bank" "-5" "wallet  Wallet" "4" "")
                                (save-window-excursion (bqn-book-new-entry))))
    (let ((form (get-buffer "*book form new*")))
      (should (buffer-live-p form))
      (should (string-match-p "ROW\t-\twallet\t4" (with-current-buffer form (buffer-string))))
      (kill-buffer form))
    (should (equal before (test-bqn-book--text copy)))))

(ert-deftest bqn-book-refunds-an-entry ()
  (let* ((copy (test-bqn-book--copy)) (list (test-bqn-book--list copy)))
    (with-current-buffer list
      (goto-char (point-min))
      (search-forward "tx-0002")
      (test-bqn-book--answering '("2027-02-04") (save-window-excursion (bqn-book-refund-entry))))
    (should (string-match-p "DESC\tRefund\nEFFECT\tbank\tjpy\t20000\nEFFECT\twallet\tjpy\t-20000\nREVERSAL-OF\ttx-0002"
                            (test-bqn-book--text copy)))))

(ert-deftest bqn-book-shows-money-with-its-decimals ()
  (should (equal (bqn-book--money "1234567" 0) "1,234,567"))
  (should (equal (bqn-book--money "-123450" 2) "-1,234.50"))
  (should (equal (bqn-book--money "5" 2) "0.05"))
  (should (equal (bqn-book--money "999" 0) "999")))

(ert-deftest bqn-book-home-shows-the-guide-and-takes-a-new-entry ()
  (let* ((copy (test-bqn-book--copy))
         (home (save-window-excursion (bqn-book-home copy))))
    (with-current-buffer home
      (setq bqn-book--today "2027-02-01" bqn-book--pool '("bank"))
      (revert-buffer)
      (should (string-match-p "Per day +3,285" (buffer-string)))
      (should (string-match-p "2027-01-25  Bank → Phone +jpy +3,000  overdue" (buffer-string)))
      (should (string-match-p "every account with a known balance" (buffer-string)))
      (test-bqn-book--answering '("2027-02-01" "coffee" "bank  Bank" "-500" "wallet  Wallet" "+500" "")
                                (save-window-excursion (bqn-book-new-entry)))
      (should (string-match-p "Spendable +194,500" (buffer-string)))
      (should (string-match-p "2027-02-01  coffee" (buffer-string))))))

(ert-deftest bqn-book-home-pays-a-plan ()
  (let* ((copy (test-bqn-book--copy))
         (home (save-window-excursion (bqn-book-home copy))))
    (with-current-buffer home
      (setq bqn-book--today "2027-02-01" bqn-book--pool '("bank"))
      (revert-buffer)
      (goto-char (point-min))
      (search-forward "Bank → Savings")
      (save-window-excursion (bqn-book-pay-plan)))
    (let ((form (get-buffer "*book form save-2027-02*")))
      (with-current-buffer form
        (should (equal (buffer-string)
                       "DAY\t2027-02-01\nMEMO\t\nMEASURE\tjpy\nROW\t-\tbank\t-20000\nROW\t-\tsavings\t20000\n"))
        (test-bqn-book--answering '() (bqn-book-form-submit)))
      (should-not (buffer-live-p form)))
    (let ((text (test-bqn-book--text copy)))
      (should (string-match-p "PLAN\tsave-2027-02\t2027-02-10\tjpy\nCHANGE\tbank\t-20000\nCHANGE\tsavings\t20000\nPAID-BY\tentry-" text))
      (should (string-match-p "EFFECT\tsavings\tjpy\t20000\nENDTX\nPLAN" text)))
    (with-current-buffer home
      (should-not (string-match-p "Bank → Savings" (buffer-string)))
      (should (string-match-p "Savings +jpy +20,000" (buffer-string))))))

(ert-deftest bqn-book-backs-up-after-a-save ()
  (let* ((dir (make-temp-file "bqn-book-house" t))
         (remote (expand-file-name "remote.git" dir))
         (house (expand-file-name "house" dir))
         (copy (expand-file-name "book.txt" house))
         (bqn-book-backup t))
    (call-process "git" nil nil nil "init" "-q" "--bare" remote)
    (call-process "git" nil nil nil "init" "-q" house)
    (copy-file (expand-file-name "../tests/fixtures/scheduled/base.txt" (file-name-directory bqn-book-command)) copy)
    (let ((default-directory (file-name-as-directory house)))
      (call-process "git" nil nil nil "add" "-A")
      (call-process "git" nil nil nil "-c" "user.name=t" "-c" "user.email=t@t" "commit" "-qm" "first")
      (call-process "git" nil nil nil "remote" "add" "origin" remote)
      (call-process "git" nil nil nil "push" "-qu" "origin" "HEAD"))
    (with-current-buffer (test-bqn-book--list copy)
      (test-bqn-book--answering '("2027-02-03" "tea" "bank  Bank" "-300" "wallet  Wallet" "+300" "")
                                (save-window-excursion (bqn-book-new-entry))))
    (let ((process (get-process "bqn-book-backup")))
      (while (and process (process-live-p process)) (accept-process-output process 0.1)))
    (let ((default-directory (file-name-as-directory remote)))
      (should (string-match-p "記帳 .*（Emacs）"
                              (with-output-to-string
                                (call-process "git" nil standard-output nil "log" "--oneline" "-1")))))))

(ert-deftest bqn-book-cells-count-columns ()
  ;; a Japanese character takes two columns, so names line up
  (should (equal (bqn-book--cell "現金" 6) "現金  "))
  (should (equal (bqn-book--cell "cash" 6) "cash  "))
  (should (equal (bqn-book--cell "1,000" 7 t) "  1,000"))
  (should (= (string-width (bqn-book--cell "とても長い科目の名前" 8)) 8)))

(ert-deftest bqn-book-accounts-complete-by-id-or-name ()
  (let ((completion-styles '(basic substring)))
    (should (equal (try-completion "sa" '("salary  Salary" "savings  Savings" "bank  Bank")) "sa"))
    (should (equal (try-completion "ban" '("salary  Salary" "bank  Bank")) "bank  Bank"))
    (should (equal (completion-all-completions "ーヒ" '("coffee  コーヒー" "bank  Bank") nil 2)
                   '("coffee  コーヒー" . 0)))))

(ert-deftest bqn-book-home-names-plans-by-accounts ()
  (with-current-buffer (bqn-book-home (test-bqn-book--copy))
    (setq bqn-book--today "2027-01-20" bqn-book--pool '("bank"))
    (revert-buffer)
    (should (string-match-p "Bank → Phone +jpy +3,000" (buffer-string)))
    (should (string-match-p "Set aside +-3,000  Bank → Phone" (buffer-string)))
    (should-not (string-match-p "phone-2027-01" (buffer-string)))))

(ert-deftest bqn-book-home-shows-bk-balance-view ()
  ;; bk's chosen balances, in its order; one with no known balance shows ?
  (let ((copy (test-bqn-book--copy)))
    (make-directory (expand-file-name "config" (file-name-directory copy)))
    (with-temp-file (expand-file-name "config/balance-view.tsv" (file-name-directory copy))
      (insert "wallet\tjpy\nbank\tjpy\nnowhere\tjpy\n"))
    (with-current-buffer (bqn-book-home copy)
      (should (string-match-p "Balances\n  Wallet +jpy +20,000\n  Bank +jpy +195,000\n  nowhere +jpy +\\?\n\n" (buffer-string))))))

(ert-deftest bqn-book-series-lists-and-pays ()
  ;; plans in series, as bk plans lists them; a series' plans; paying one there
  (let* ((copy (test-bqn-book--copy))
         (home (save-window-excursion (bqn-book-home copy))))
    (with-current-buffer home (setq bqn-book--today "2027-02-01"))
    (let ((series (with-current-buffer home (save-window-excursion (bqn-book-home-series)))))
      (with-current-buffer series
        (should (string-match-p "Bank +Rent +80,000 +jpy +2027-02-27 +2027-03-27 +2"
                                (buffer-substring-no-properties (point-min) (point-max))))
        (goto-char (point-min))
        (search-forward "Phone")
        (should (string-match-p "overdue" (buffer-substring-no-properties (line-beginning-position) (line-end-position))))
        (goto-char (point-min))
        (search-forward "Rent")
        (let ((plans (save-window-excursion (bqn-book-series-plans))))
          (with-current-buffer plans
            (should (equal (mapcar #'car tabulated-list-entries) '("rent-2027-02" "rent-2027-03")))
            (goto-char (point-min))
            (search-forward "2027-02-27")
            (save-window-excursion (bqn-book-pay-plan))
            (with-current-buffer "*book form rent-2027-02*"
              (test-bqn-book--answering '() (bqn-book-form-submit)))
            (should (equal (mapcar #'car tabulated-list-entries) '("rent-2027-03")))))))))

(ert-deftest bqn-book-plans-move-and-cancel ()
  ;; a plan's due day moves (same ID, same rows); a cancelled plan is kept, marked
  (let* ((copy (test-bqn-book--copy))
         (home (save-window-excursion (bqn-book-home copy))))
    (with-current-buffer home
      (setq bqn-book--today "2027-02-01")
      (revert-buffer)
      (goto-char (point-min))
      (search-forward "2027-02-27")
      (test-bqn-book--answering '("2027-02-28") (bqn-book-move-plan))
      (should (string-match-p "PLAN\trent-2027-02\t2027-02-28\tjpy\nCHANGE\tbank\t-80000\nCHANGE\trent\t80000\nENDPLAN"
                              (test-bqn-book--text copy)))
      (should (string-match-p "2027-02-28  Bank → Rent" (buffer-string)))
      (goto-char (point-min))
      (search-forward "2027-03-27")
      (test-bqn-book--answering '() (bqn-book-cancel-plan))
      (should (string-match-p "PLAN\trent-2027-03\t2027-03-27\tjpy\nCHANGE\tbank\t-80000\nCHANGE\trent\t80000\nCANCELLED\t2027-02-01\nENDPLAN"
                              (test-bqn-book--text copy)))
      (should-not (string-match-p "2027-03-27" (buffer-string))))))

(ert-deftest bqn-book-home-corrects-a-recent-entry ()
  (let* ((copy (test-bqn-book--copy))
         (home (save-window-excursion (bqn-book-home copy))))
    (with-current-buffer home
      (goto-char (point-min))
      (search-forward "last gym month")
      (save-window-excursion (bqn-book-home-open))
      (should (get-buffer "*book form tx-0003*")))))

(ert-deftest bqn-book-days-typed-as-the-form-takes-them ()
  (should (equal (bqn-book--typed-day "2027/2/8") "2027-02-08"))
  (should (equal (bqn-book--typed-day "２０２７．０２．２８") "2027-02-28"))
  (should (equal (bqn-book--typed-day "2027-02-28") "2027-02-28"))
  (should (equal (bqn-book--typed-day "2027/02-28") "2027/02-28")))

(ert-deftest bqn-book-keys-say-what-is-bound ()
  ;; every key ? shows is bound to a command on its screen
  (dolist (screen bqn-book--keys)
    (let ((map (symbol-value (intern (format "%s-map" (car screen))))))
      (dolist (key (cdr screen))
        (should (commandp (keymap-lookup map (car key))))))
    (should (eq (keymap-lookup (symbol-value (intern (format "%s-map" (car screen))))
                               (if (memq (car screen) '(bqn-book-form-mode bqn-book-change-mode)) "C-c ?" "?"))
                'bqn-book-keys)))
  (with-current-buffer (get-buffer-create "*keys test*")
    (bqn-book-series-mode)
    (save-window-excursion (bqn-book-keys))
    (should (string-match-p "先の月を埋める" (with-current-buffer "*book keys*" (buffer-string))))))

(ert-deftest bqn-book-makes-and-changes-plans ()
  (let* ((copy (test-bqn-book--copy))
         (home (save-window-excursion (bqn-book-home copy))))
    (with-current-buffer home
      (setq bqn-book--today "2027-02-01")
      ;; a new plan, asked as an entry is
      (test-bqn-book--answering '("2027/3/5" "bank  Bank" "-1,200" "phone  Phone" "+1200" "") (bqn-book-new-plan))
      (should (string-match-p "PLAN\tentry-[0-9a-f]+\t2027-03-05\tjpy\nCHANGE\tbank\t-1200\nCHANGE\tphone\t1200\nENDPLAN"
                              (test-bqn-book--text copy)))
      ;; a plan changed in a form keeps its ID
      (goto-char (point-min))
      (search-forward "2027-02-27")
      (save-window-excursion (bqn-book-edit-plan))
      (with-current-buffer "*book form rent-2027-02*"
        (should (equal (buffer-string) "DAY\t2027-02-27\nMEASURE\tjpy\nROW\t-\tbank\t-80000\nROW\t-\trent\t80000\n"))
        (goto-char (point-min))
        (while (search-forward "80000" nil t) (replace-match "82000"))
        (test-bqn-book--answering '() (bqn-book-form-submit)))
      (should (string-match-p "PLAN\trent-2027-02\t2027-02-27\tjpy\nCHANGE\tbank\t-82000\nCHANGE\trent\t82000\nENDPLAN"
                              (test-bqn-book--text copy))))))

(ert-deftest bqn-book-fills-the-coming-months ()
  (let* ((copy (test-bqn-book--copy))
         (home (save-window-excursion (bqn-book-home copy))))
    (with-current-buffer home (setq bqn-book--today "2027-02-01"))
    (let ((series (with-current-buffer home (save-window-excursion (bqn-book-home-series)))))
      (with-current-buffer series
        (goto-char (point-min))
        (search-forward "Rent")
        ;; monthly, two more: after the last rent (2027-03-27)
        (test-bqn-book--answering '("1" "2") (bqn-book-fill-months))
        (should (string-match-p "Bank +Rent +80,000 +jpy +2027-02-27 +2027-05-27 +4"
                                (buffer-substring-no-properties (point-min) (point-max))))))
    (should (string-match-p "PLAN\tentry-[0-9a-f]+\t2027-04-27\tjpy\nCHANGE\tbank\t-80000\nCHANGE\trent\t80000\nENDPLAN"
                            (test-bqn-book--text copy)))))

(ert-deftest bqn-book-asks-for-a-missing-day ()
  ;; a month without the day: a real date after the last plan, or nothing to skip
  (cl-letf (((symbol-function 'sit-for) #'ignore))
    (test-bqn-book--answering '("2027-02-30" "2027-01-15" "2027/2/28")
                              (should (equal (bqn-book--ask-missing "2027-02" "31" "2027-01-31") "2027-02-28")))
    (test-bqn-book--answering '("") (should-not (bqn-book--ask-missing "2027-02" "31" "2027-01-31")))))

(ert-deftest bqn-book-adds-and-names-accounts ()
  (let* ((copy (test-bqn-book--copy))
         (home (save-window-excursion (bqn-book-home copy)))
         (accounts (with-current-buffer home (save-window-excursion (bqn-book-home-accounts)))))
    (with-current-buffer accounts
      (should (string-match-p "Gym +gym +hidden" (buffer-substring-no-properties (point-min) (point-max))))
      (test-bqn-book--answering '("cafe" "Café\\Bar" "expense") (bqn-book-add-account))
      (should (string-match-p "LOCUS\tcafe\tCafé\\\\\\\\Bar\tCafé\\\\\\\\Bar\n" (test-bqn-book--text copy)))
      (should (string-match-p "ROLE\tcafe\tEXPENSE\n" (test-bqn-book--text copy)))
      (should (string-match-p "Café\\\\Bar +cafe +expense" (buffer-substring-no-properties (point-min) (point-max))))
      (goto-char (point-min))
      (search-forward "Wallet")
      (test-bqn-book--answering '("Purse") (bqn-book-name-account))
      (should (string-match-p "LOCUS\twallet\tPurse\tPurse\n" (test-bqn-book--text copy)))
      (goto-char (point-min))
      (search-forward "Purse")
      (test-bqn-book--answering '("asset") (bqn-book-set-role))
      (should (string-match-p "ROLE\tcafe\tEXPENSE\nROLE\twallet\tASSET\n" (test-bqn-book--text copy))))))

;;; test_emacs.el ends here
