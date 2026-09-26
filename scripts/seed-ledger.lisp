;;;; Record every dist source in source-ledger.lisp without generating a dist.
;;;;
;;;;   sbcl --script scripts/seed-ledger.lisp      ; or: dotcl scripts/seed-ledger.lisp
;;;;
;;;; For each entry the ledger does not have yet, records the repository ids the
;;;; host reports now and the commit the newest published dist version was built
;;;; from (the pinned upstream commit, for a :patched entry). Existing entries
;;;; are left alone. Reads only: gh api for GitHub, the anonymous Codeberg API,
;;;; and the clones under build/src/ when they are there.
;;;;
;;;; gen-dist records a source it has no entry for on its own; this script is
;;;; for recording the sources as they stand without building anything.

(require "asdf")

(load (merge-pathnames "common.lisp" (or *load-truename* *default-pathname-defaults*)))
(load (merge-pathnames "source-ledger.lisp" (or *load-truename* *default-pathname-defaults*)))

(in-package #:dotcl-dist)

(defun newest-release-shas ()
  "lib -> abbreviated commit, from the prefix column of the newest releases.txt."
  (let* ((dirs (sort (remove-if-not
                      (lambda (d) (probe-file (merge-pathnames "releases.txt" d)))
                      (uiop:subdirectories (rooted (format nil "docs/~a/" *dist-name*))))
                     #'string< :key #'namestring))
         (shas (make-hash-table :test #'equal)))
    (when dirs
      (dolist (line (uiop:read-file-lines
                     (merge-pathnames "releases.txt" (car (last dirs)))))
        (unless (or (zerop (length line)) (char= (char line 0) #\#))
          (let* ((fields (uiop:split-string line :separator '(#\Space)))
                 (prefix (sixth fields)))
            (setf (gethash (first fields) shas)
                  (subseq prefix (1+ (position #\- prefix :from-end t))))))))
    shas))

(defun full-commit (lib host source short)
  "The full SHA of SHORT: from the local clone when it has it, otherwise from
the GitHub API."
  (let ((dir (rooted (format nil "build/src/~a/" lib))))
    (or (when (probe-file (merge-pathnames ".git/HEAD" dir))
          (multiple-value-bind (out code)
              (run-status "git" "-C" (native dir) "rev-parse" "--verify" "--quiet"
                          (format nil "~a^{commit}" short))
            (when (eql code 0) (trimmed out))))
        (when (eq host :github)
          (multiple-value-bind (out code)
              (run-status "gh" "api" (format nil "repos/~a/commits/~a" source short)
                          "--jq" ".sha")
            (when (eql code 0) (trimmed out)))))))

(defun seed ()
  (let* ((ledger (read-ledger))
         (shas (newest-release-shas))
         (added 0)
         (result '()))
    (dolist (entry (dist-entries (load-manifest)))
      (let* ((lib (entry-value entry :lib))
             (source (entry-repo entry))
             (host (entry-source-host entry))
             (existing (ledger-entry ledger lib)))
        (if existing
            (push existing result)
            (let* ((pinned (ref-commit (entry-value entry :ref)))
                   (short (gethash lib shas))
                   (commit (or pinned (and short (full-commit lib host source short))))
                   (identity (funcall *repo-identity-function* host source)))
              (cond
                ((null commit)
                 (format *error-output* "~&;; ~a: no published commit found, left for gen-dist~%" lib))
                ((and (consp identity) (getf identity :error))
                 (format *error-output* "~&;; ~a: ~a~%" lib (getf identity :error)))
                (t
                 (incf added)
                 (push (make-ledger-entry lib host source
                                          (if (eq identity :none) '() identity)
                                          commit)
                       result)
                 (format *error-output* "~&;; ~a: ~a @ ~a~%" lib source (subseq commit 0 7))))))))
    (setf result (nreverse result))
    (write-ledger result)
    (format *error-output* "~&;; ~d entr~:@p added, ~d in the ledger~%"
            added (length result))))

(seed)
