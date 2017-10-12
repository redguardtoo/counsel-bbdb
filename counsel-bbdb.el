;; Copyright (C) 2016 Chen Bin
;;
;; Version: 0.0.1
;; Author: Chen Bin <chenbin.sh AT gmail>
;; URL: https://github.com/redguard/counsel-bbdb
;; Package-Requires: ((ivy "0.8.0") (emacs "24.3"))
;; Keywords: bbdb, email, completion

;; This file is NOT part of GNU Emacs.

;;; License:

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 3, or (at your option)
;; any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs; see the file COPYING.  If not, write to the
;; Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
;; Boston, MA 02110-1301, USA.

;;; Commentary:

;; Use `ivy-mode' to input email address from BBDB efficiently.
;; Smart to know some ethic groups display family name before given name
;; Since It's not using any API from `bbdb', it's always fast and stable.
;;
;; `M-x counsel-bbdb-complete-mail' to input email address.
;; `M-x counsel-bbdb-reload' to reload contacts from BBDB database.
;;
;; Since counsel-bbdb is based ivy-mode. All ivy key bindings are supported.
;; For example, after `C-u M-x counsel-bbdb-complete-mail', you can press
;; `C-M-n' to input multiple mail address.
;;
;; You can also customize `counsel-bbdb-customized-insert' to insert
;; email in your own way:
;;   (setq counsel-bbdb-customized-insert
;;         (lambda (r append-comma)
;;           (let* ((family-name (nth 1 r))
;;                  (given-name (nth 2 r))
;;                  (display-name (nth 3 r))
;;                  (mail (nth 4 r))))
;;           (insert (format "%s:%s:%s:%s%s"
;;                           given-name
;;                           family-name
;;                           display-name
;;                           mail
;;                           (if append-comma ", " " ")))))
;;
;; BTW, `ivy-resume' is fully supported.

;;; Code:

(require 'ivy)

(defvar counsel-bbdb-customized-insert nil
  "User defined function to insert the email.
Two parameters are passed to this function.
The first parameter is '(KEYWORD FAMILY-NAME GIVEN-NAME FULL-NAME EMAIL).
The second parameter is APPEND-COMMA.
If it's nil, the default insertion is executed.")

(defvar counsel-bbdb-contacts nil
  "The contacts list read from `bbdb-file'.")

(defvar counsel-bbdb-mail-alias-list nil
  "The mail alias list.")

(defun counsel-bbdb-family-name (r)
  "Get family name from R."
  (aref r 1))

(defun counsel-bbdb-given-name (r)
  "Get given name from R."
  (aref r 0))

(defun counsel-bbdb-full-name (r)
  "Get full name from R."
  (car (aref r 3)))

(defun counsel-bbdb-emails (r)
  "Get emails from R."
  (aref r 7))

(defun counsel-bbdb-mail-alias (r)
  "Get emails from R."
  (let* ((item (aref r 8)))
    (if item (cdr (assoc 'mail-alias item)))))

;;;###autoload
(defun counsel-bbdb-insert-string (str)
  "Insert STR into current buffer."
  ;; paste after the cursor in evil normal state
  (when (and (functionp 'evil-normal-state-p)
             (functionp 'evil-move-cursor-back)
             (evil-normal-state-p)
             (not (eolp))
             (not (eobp)))
    (forward-char))
  (insert str))



;;;###autoload
(defun counsel-bbdb-reload ()
  "Load contacts from `bbdb-file'."
  (interactive)
  (let* (raw-records)
    (with-temp-buffer
      (insert-file-contents bbdb-file)
      (goto-char (point-min)) (insert "(\n")
      (goto-char (point-max)) (insert "\n)")
      (goto-char (point-min))
      (setq raw-records (read (current-buffer))))
    ;; convert to ivy friendly list with readable keyword:
    ;;   - full-name:mail
    ;;   - given-name family-name:mail
    ;;   - :mail
    (setq counsel-bbdb-contacts nil)
    (setq counsel-bbdb-mail-alias-list nil)
    (dolist (r raw-records)
      (let* ((full-name (counsel-bbdb-full-name r))
             (family-name (counsel-bbdb-family-name r))
             (given-name (counsel-bbdb-given-name r))
             (mails (counsel-bbdb-emails r))
             (mail-alias (counsel-bbdb-mail-alias r))
             (prefix full-name))

        (message "mail-alias=%s" mail-alias)
        (when mail-alias
          (let* ((strs (split-string mail-alias ", ")))
            (dolist (s strs)
              (add-to-list 'counsel-bbdb-mail-alias-list s))))

        (when (= (length prefix) 0)
          (setq prefix (concat family-name
                               " "
                               given-name)))
        (if (= (length prefix) 1) (setq prefix ""))

        (dolist (m mails)
          (message "mail-alist======%s" mail-alias)
          (add-to-list 'counsel-bbdb-contacts
                       (cons (concat prefix
                                     ":"
                                     m
                                     (if mail-alias (format " => %s" mail-alias)))
                             (list family-name
                                   given-name
                                   full-name
                                   m
                                   mail-alias))))))))

;;;###autoload
(defun counsel-bbdb-complete-mail (&optional append-comma)
  "In a mail buffer, complete email before point.
Extra argument APPEND-COMMA will append comma after email."
  (interactive "P")
  (unless counsel-bbdb-contacts
    (counsel-bbdb-reload))
  (ivy-read "Contacts: "
            counsel-bbdb-contacts
            :action `(lambda (r)
                       (let* (rlt
                              (family-name (nth 1 r))
                              (given-name (nth 2 r))
                              (display-name (nth 3 r))
                              (mail (nth 4 r)))
                         (if counsel-bbdb-customized-insert
                             ;; users know how to insert email
                             (funcall counsel-bbdb-customized-insert r append-comma)
                           ;; our way
                           (cond
                            ((> (length display-name) 0)
                             ;; insert "full-name <email"
                             (setq rlt (format "%s <%s>" display-name mail)))
                            ((> (length (setq display-name
                                              (concat given-name " " family-name))
                                        1)
                                ;; insert "given-name family-name <email>"
                                (setq rlt (format "%s <%s>" display-name mail))))
                            (t
                             ;; insert "email"
                             (setq rlt mail)))
                           (if append-comma (setq rlt (concat rlt ", "))))
                         (counsel-bbdb-insert-string rlt)))))

(defun counsel-bbdb-expand-mail-alias ()
  "Insert multiple mail address in alias/group."
  (interactive)
  (unless counsel-bbdb-contacts
    (counsel-bbdb-reload))
  (message "counsel-bbdb-mail-alias-list=%s" counsel-bbdb-mail-alias-list)
  ;; we just need filter the cousnel-bbdb-contacts by selected alias
  (ivy-read "Alias: "
            counsel-bbdb-mail-alias-list))

(provide 'counsel-bbdb)
;;; counsel-bbdb.el ends here
