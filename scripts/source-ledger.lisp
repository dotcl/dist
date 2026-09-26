;;;; The source ledger: which repository each release is imported from, by
;;;; identity rather than by name, and which commit was imported last.
;;;;
;;;; A repository name can change hands: it can be renamed, transferred, or
;;;; deleted and created again. The numeric ids a host assigns to a repository
;;;; and to its owner do not follow the name, so they are what is recorded.
;;;; The imported commit is recorded too, so that the next import can check the
;;;; new commit extends the old history instead of replacing it.
;;;;
;;;; gen-dist consults the ledger before it builds anything and stops when a
;;;; source no longer matches it:
;;;;
;;;;   - the repository id or the owner id differs from the recorded one;
;;;;   - the commit to import does not descend from the recorded commit.
;;;;
;;;; A rename keeps both ids, so it only updates the recorded name. A first run
;;;; with no entry records one. A person who has looked at a change and accepts
;;;; it deletes that project's line from source-ledger.lisp (or edits the value
;;;; that changed); the next run records the source afresh.
;;;;
;;;; Portable Common Lisp plus UIOP: loaded by gen-dist under dotcl, and by the
;;;; seed and test scripts under any implementation.

(in-package #:dotcl-dist)

;;; ------------------------------------------------------------------
;;; shelling out

(defun trimmed (string)
  (string-trim '(#\Space #\Tab #\Newline #\Return) string))

(defun native (pathname) (uiop:native-namestring pathname))

(defun run-status (program &rest args)
  "Run PROGRAM and return (values output exit-code error-output). Never signals
on a non-zero exit; a program that cannot be started counts as exit code -1."
  (handler-case
      (let* ((process (uiop:launch-program (cons program args)
                                           :output :stream
                                           :error-output :stream))
             (output (uiop:slurp-input-stream
                      'string (uiop:process-info-output process)))
             (errors (uiop:slurp-input-stream
                      'string (uiop:process-info-error-output process)))
             (code (uiop:wait-process process)))
        (values output code errors))
    (error (condition)
      (values "" -1 (princ-to-string condition)))))

(defun run (program &rest args)
  "Run PROGRAM, return its standard output as a string. Errors are fatal:
a dist generated from a half-failed command would be worse than none."
  (multiple-value-bind (out code err) (apply #'run-status program args)
    (unless (eql code 0)
      (error "~a ~{~a~^ ~} exited ~a~%~a" program args code err))
    out))

;;; ------------------------------------------------------------------
;;; the ledger file

(defun ledger-path () (rooted "source-ledger.lisp"))

(defun read-ledger (&optional (path (ledger-path)))
  "Ledger entries as a list of plists. A missing file is an empty ledger."
  (if (probe-file path)
      (with-open-file (s path)
        (let ((*read-eval* nil))
          (getf (cdr (read s)) :entries)))
      '()))

(defun ledger-entry (ledger lib)
  (find lib ledger :key (lambda (e) (getf e :lib)) :test #'string=))

(defun write-ledger (entries &optional (path (ledger-path)))
  "One entry per line, so accepting a change is a one-line edit or deletion."
  (with-open-file (s path :direction :output :if-exists :supersede
                          :if-does-not-exist :create)
    (with-standard-io-syntax
      (let ((*print-case* :downcase)
            (*print-readably* nil))
        (format s ";;;; Source ledger, written by scripts/gen-dist.lisp and~%")
        (format s ";;;; scripts/seed-ledger.lisp. See README.md, \"Source ledger\".~%")
        (format s ";;;;~%")
        (format s ";;;; One line per project: the repository a release is imported from,~%")
        (format s ";;;; the ids the host gave that repository and its owner, and the commit~%")
        (format s ";;;; imported last. Delete a line to have the next run record it afresh.~%~%")
        (format s "(:source-ledger~% :format-version 1~% :entries~% (")
        (loop for (entry . more) on entries
              do (format s "~s~:[~;~%  ~]" entry more))
        (format s "))~%")))))

(defun make-ledger-entry (lib host source identity commit)
  (list :lib lib
        :host host
        :source source
        :name (or (getf identity :name) source)
        :repo-id (getf identity :repo-id)
        :owner-id (getf identity :owner-id)
        :commit commit))

;;; ------------------------------------------------------------------
;;; repository identity

(defun parse-json (string)
  "A small JSON reader: objects become alists with string keys, arrays lists,
true/false/null become T/:FALSE/NIL. Enough for a repository description."
  (let ((i 0) (n (length string)))
    (labels ((peek () (and (< i n) (char string i)))
             (skip ()
               (loop while (and (< i n)
                                (member (char string i)
                                        '(#\Space #\Tab #\Newline #\Return)))
                     do (incf i)))
             (expect (c)
               (skip)
               (unless (eql (peek) c)
                 (error "JSON: expected ~s at ~d" c i))
               (incf i))
             (value ()
               (skip)
               (let ((c (peek)))
                 (cond ((eql c #\{) (object))
                       ((eql c #\[) (array))
                       ((eql c #\") (str))
                       ((and c (or (digit-char-p c) (char= c #\-))) (num))
                       (t (word)))))
             (object ()
               (expect #\{)
               (skip)
               (if (eql (peek) #\})
                   (progn (incf i) '())
                   (loop collect (let ((key (progn (skip) (str))))
                                   (expect #\:)
                                   (cons key (value)))
                         do (skip)
                         until (eql (peek) #\})
                         do (expect #\,)
                         finally (incf i))))
             (array ()
               (expect #\[)
               (skip)
               (if (eql (peek) #\])
                   (progn (incf i) '())
                   (loop collect (value)
                         do (skip)
                         until (eql (peek) #\])
                         do (expect #\,)
                         finally (incf i))))
             (str ()
               (expect #\")
               (with-output-to-string (out)
                 (loop for c = (char string i)
                       do (incf i)
                       until (char= c #\")
                       do (if (char= c #\\)
                              (let ((e (char string i)))
                                (incf i)
                                (case e
                                  (#\n (write-char #\Newline out))
                                  (#\t (write-char #\Tab out))
                                  (#\r (write-char #\Return out))
                                  (#\b (write-char #\Backspace out))
                                  (#\f (write-char #\Page out))
                                  (#\u (write-char
                                        (code-char (parse-integer string :start i
                                                                         :end (+ i 4)
                                                                         :radix 16))
                                        out)
                                   (incf i 4))
                                  (t (write-char e out))))
                              (write-char c out)))))
             (num ()
               (let ((start i))
                 (loop while (and (< i n)
                                  (find (char string i) "-+0123456789.eE"))
                       do (incf i))
                 (let ((text (subseq string start i)))
                   (or (parse-integer text :junk-allowed t) text))))
             (word ()
               (flet ((try (w v)
                        (when (and (<= (+ i (length w)) n)
                                   (string= w string :start2 i :end2 (+ i (length w))))
                          (incf i (length w))
                          (return-from word v))))
                 (try "true" t)
                 (try "false" :false)
                 (try "null" nil)
                 (error "JSON: unexpected text at ~d" i))))
      (value))))

(defun json-get (json &rest keys)
  (dolist (key keys json)
    (setf json (cdr (assoc key json :test #'string=)))))

(defun identity-from-json (json)
  (list :repo-id (json-get json "id")
        :owner-id (json-get json "owner" "id")
        :name (json-get json "full_name")))

(defun github-identity (repo)
  (multiple-value-bind (out code err)
      (run-status "gh" "api" (format nil "repos/~a" repo))
    (if (eql code 0)
        (identity-from-json (parse-json out))
        (list :error (trimmed (format nil "gh api repos/~a: ~a" repo err))))))

(defun codeberg-identity (repo)
  (multiple-value-bind (out code err)
      (run-status "curl" "-sSf" (format nil "https://codeberg.org/api/v1/repos/~a" repo))
    (if (eql code 0)
        (identity-from-json (parse-json out))
        (list :error (trimmed (format nil "codeberg repos/~a: ~a" repo err))))))

(defun default-repo-identity (host repo)
  "(:repo-id N :owner-id N :name \"owner/repo\") as the host reports it now; the
name is the current one, which differs from REPO after a rename. (:error text)
when the host cannot be asked or does not know the repository. :NONE for a host
this script has no API for; only the commit is checked there."
  (case host
    (:github (github-identity repo))
    (:codeberg (codeberg-identity repo))
    (t :none)))

(defvar *repo-identity-function* 'default-repo-identity
  "Called with (host repo). Rebound by the tests, which run without network.")

;;; ------------------------------------------------------------------
;;; history

(defun commit-present-p (dir commit)
  (eql 0 (nth-value 1 (run-status "git" "-C" (native dir) "cat-file" "-e"
                                  (format nil "~a^{commit}" commit)))))

(defun descends-from-p (dir old new)
  "True when NEW is OLD or has OLD in its history, judged from the clone in DIR,
which already holds NEW with its full history. An OLD the clone does not have
is not in NEW's history."
  (or (string= old new)
      (and (commit-present-p dir old)
           (eql 0 (nth-value 1 (run-status "git" "-C" (native dir) "merge-base"
                                           "--is-ancestor" old new))))))

;;; ------------------------------------------------------------------
;;; the check

(defun check-source (lib host source commit dir recorded)
  "Compare one source with its RECORDED ledger entry (NIL when there is none).

Returns (values new-entry refusal note). NEW-ENTRY is what the ledger should
say after this import; REFUSAL is a string when the import must not go ahead,
in which case NEW-ENTRY is NIL. NOTE is a string worth reporting on success."
  (let ((identity (funcall *repo-identity-function* host source)))
    (when (and (consp identity) (getf identity :error))
      (return-from check-source
        (values nil (format nil "cannot read the repository identity: ~a"
                            (getf identity :error)))))
    (when (eq identity :none) (setf identity '()))
    (let ((entry (make-ledger-entry lib host source identity commit)))
      (cond
        ((null recorded)
         (values entry nil (format nil "recorded ~a @ ~a" source (subseq commit 0 7))))
        ;; A different repository on purpose: the manifest now names another
        ;; source (a fork retiring to upstream, say). The manifest is the
        ;; reviewed record of that decision, so the new source is recorded.
        ((and (not (string-equal source (getf recorded :source)))
              (not (same-ids-p identity recorded)))
         (values entry nil
                 (format nil "source changed in the manifest from ~a to ~a; recorded afresh"
                         (getf recorded :source) source)))
        ((not (same-ids-p identity recorded))
         (values nil
                 (format nil "~a is no longer the recorded repository: ~
                              repository id ~a (recorded ~a), owner id ~a (recorded ~a)"
                         source (getf identity :repo-id) (getf recorded :repo-id)
                         (getf identity :owner-id) (getf recorded :owner-id))))
        ((not (descends-from-p dir (getf recorded :commit) commit))
         (values nil
                 (format nil "~a does not descend from the recorded commit ~a"
                         commit (getf recorded :commit))))
        ((and (getf identity :name)
              (not (string-equal (getf identity :name) (getf recorded :name))))
         (values entry nil
                 (format nil "renamed from ~a to ~a (same ids); name updated"
                         (getf recorded :name) (getf identity :name))))
        (t (values entry nil nil))))))

(defun same-ids-p (identity recorded)
  "Ids agree. Where neither side has ids (a host with no API), there is
nothing to compare and only the history check applies."
  (and (eql (getf identity :repo-id) (getf recorded :repo-id))
       (eql (getf identity :owner-id) (getf recorded :owner-id))))

(defun check-sources (items ledger)
  "ITEMS is a list of (:lib :host :source :commit :dir) plists, in manifest
order. Returns (values new-ledger refusals notes), where REFUSALS and NOTES are
lists of (lib . text). NEW-LEDGER covers exactly ITEMS, so an entry retired
from the manifest leaves the ledger with it; it is meaningful only when
REFUSALS is empty."
  (let ((new '()) (refusals '()) (notes '()))
    (dolist (item items)
      (let ((lib (getf item :lib)))
        (multiple-value-bind (entry refusal note)
            (check-source lib (getf item :host) (getf item :source)
                          (getf item :commit) (getf item :dir)
                          (ledger-entry ledger lib))
          (cond (refusal (push (cons lib refusal) refusals))
                (t (push entry new)
                   (when note (push (cons lib note) notes)))))))
    (values (nreverse new) (nreverse refusals) (nreverse notes))))

(defun report-ledger (refusals notes &optional (stream *error-output*))
  (dolist (n notes)
    (format stream "~&;; ledger: ~a: ~a~%" (car n) (cdr n)))
  (when refusals
    (format stream "~&;; ~d project(s) not updated, the source no longer matches source-ledger.lisp:~%"
            (length refusals))
    (dolist (r refusals)
      (format stream ";;   ~a: ~a~%" (car r) (cdr r)))
    (format stream ";; Look at the change first. To accept it, delete that project's line~%~
                    ;; from source-ledger.lisp and the next run records the source afresh.~%~
                    ;; When only the history changed, pinning its :ref in manifest.lisp to~%~
                    ;; the recorded commit keeps the previous version meanwhile.~%")))
