;;;; Validate manifest.lisp.
;;;;
;;;;   sbcl --script scripts/validate.lisp          ; schema only
;;;;   LEDGER_CHECK_NETWORK=1 sbcl --script ...     ; + gh checks
;;;;
;;;; Exits non-zero if anything fails, so CI can gate on it.

(load (merge-pathnames "common.lisp" (or *load-truename* *default-pathname-defaults*)))

(in-package #:dotcl-dist)

(defparameter *dispositions*
  '(:upstream-merged :upstream-pr-open :bundled-in-release :fork-only))

(defparameter *required-keys* '(:lib :upstream :disposition :ref :retire-when))

(defvar *problems* '())

(defun fail (fmt &rest args)
  (push (apply #'format nil fmt args) *problems*))

(defun getenv (name)
  #+sbcl (sb-ext:posix-getenv name)
  #-sbcl (uiop:getenv name))

(defun run-command (program args)
  "Run PROGRAM, returning (values output success-p). Never signals."
  (handler-case
      #+sbcl
      (let* ((out (make-string-output-stream))
             (p (sb-ext:run-program program args :search t :output out
                                                 :error nil :wait t)))
        (values (get-output-stream-string out)
                (eql 0 (sb-ext:process-exit-code p))))
      #-sbcl
      (multiple-value-bind (out err code)
          (uiop:run-program (cons program args) :output :string
                                                :ignore-error-status t)
        (declare (ignore err))
        (values out (eql 0 code)))
    (error () (values "" nil))))

;;; ---------------------------------------------------------------- schema

(defun check-schema (entry)
  (let ((lib (entry-value entry :lib)))
    (dolist (key *required-keys*)
      (unless (entry-value entry key)
        (fail "~a: missing ~s" (or lib "<unnamed entry>") key)))
    (let ((disposition (entry-value entry :disposition))
          (ref (entry-value entry :ref))
          (pr (entry-value entry :pr)))
      (unless (member disposition *dispositions*)
        (fail "~a: unknown :disposition ~s" lib disposition))
      (unless (assoc (entry-host entry) *hosts*)
        (fail "~a: unknown :upstream-host ~s" lib (entry-host entry)))
      ;; :ref shape must match what the disposition claims.
      (case disposition
        (:upstream-merged
         (unless (eq ref :upstream-default)
           (fail "~a: :upstream-merged should point at :upstream-default, got ~s" lib ref)))
        ((:upstream-pr-open :bundled-in-release :fork-only)
         (unless (and (ref-repo ref) (ref-branch ref))
           (fail "~a: :ref must be (\"owner/repo\" :branch \"name\"), got ~s" lib ref))))
      ;; A pending or merged PR must actually be recorded.
      (when (and (member disposition '(:upstream-merged :upstream-pr-open))
                 (not pr))
        (fail "~a: ~s requires :pr" lib disposition))
      (when (and (eq disposition :fork-only) pr)
        (fail "~a: :fork-only must not carry a :pr (promote it instead)" lib))
      (when pr
        (multiple-value-bind (repo number) (parse-pr pr)
          (unless (and repo number)
            (fail "~a: :pr ~s is not \"owner/repo#number\"" lib pr)))))))

;;; --------------------------------------------------------------- network

(defun gh-json (endpoint field)
  (multiple-value-bind (out ok) (run-command "gh" (list "api" endpoint "-q" field))
    (when ok (string-trim '(#\Space #\Newline #\Return) out))))

(defun codeberg-json (endpoint)
  "Raw JSON from Codeberg's Gitea API, or NIL when the request failed.

No token and no gh equivalent: Codeberg answers these reads anonymously, and
curl -sf exits non-zero on a 404, which is exactly the signal RUN-COMMAND
reports."
  (multiple-value-bind (out ok)
      (run-command "curl" (list "-sf" (format nil "https://codeberg.org/api/v1/~a" endpoint)))
    (when ok out)))

(defun pr-state (host repo number)
  "(values \"open\"|\"closed\" MERGED-P) for a pull request, NIL if unreadable.

Merged is returned separately rather than folded into the string. An earlier
version reported \"closed/unmerged\" and tested it with (SEARCH \"merged\" ...),
which is true of \"unmerged\" as well, so an unmerged pull request satisfied
:upstream-merged and the check passed."
  (case host
    (:github
     (let ((out (gh-json (format nil "repos/~a/pulls/~d" repo number)
                         ".state + \"/\" + (.merged|tostring)")))
       (when out
         (values (subseq out 0 (position #\/ out))
                 (and (search "/true" out) t)))))
    (:codeberg
     ;; Gitea's pull payload carries "state" and "merged" exactly once each:
     ;; merged_at and merged_by are distinct keys, and no nested object repeats
     ;; either. So a substring test is enough, and this needs neither jq nor a
     ;; JSON parser.
     (let ((json (codeberg-json (format nil "repos/~a/pulls/~d" repo number))))
       (when json
         (values (if (search "\"state\":\"open\"" json) "open" "closed")
                 (and (search "\"merged\":true" json) t)))))))

(defun check-pr (entry)
  (let ((lib (entry-value entry :lib))
        (pr (entry-value entry :pr))
        (host (entry-host entry))
        (disposition (entry-value entry :disposition)))
    (when pr
      (multiple-value-bind (repo number) (parse-pr pr)
        (when (and repo number)
          (multiple-value-bind (state merged) (pr-state host repo number)
            (cond
              ((not (member host '(:github :codeberg)))
               (fail "~a: :pr ~a is on ~s, which this check cannot read" lib pr host))
              ((null state)
               (fail "~a: cannot read PR ~a (gone, private, or the client is unavailable)"
                     lib pr))
              ((and (eq disposition :upstream-merged) (not merged))
               (fail "~a: :upstream-merged but PR ~a is ~a and unmerged" lib pr state))
              ((and (eq disposition :upstream-pr-open)
                    (not (string= state "open")))
               (fail "~a: :upstream-pr-open but PR ~a is ~a — promote or retire the entry"
                     lib pr state)))))))))

(defun check-ref (entry)
  "Check the fork a :ref names. GitHub only, and deliberately so: a :ref fork is
one of ours and lives in the dotcl organization, whatever host upstream is on."
  (let* ((lib (entry-value entry :lib))
         (ref (entry-value entry :ref))
         (repo (ref-repo ref))
         (branch (ref-branch ref)))
    (when repo
      (let ((private (gh-json (format nil "repos/~a" repo) ".private")))
        (cond ((null private)
               (fail "~a: :ref repository ~a is unreachable" lib repo))
              ((string= private "true")
               (fail "~a: :ref repository ~a is private — a public manifest cannot point at it"
                     lib repo))))
      (unless (gh-json (format nil "repos/~a/branches/~a" repo branch) ".name")
        (fail "~a: branch ~a of ~a does not exist" lib branch repo)))))

(defun check-inventory (entries ignore)
  "Report dotcl-org repositories that no entry mentions, so forks cannot drift.
Public repositories only: a private one is not something a public manifest
could point at, and naming it here would publish its existence."
  (multiple-value-bind (out ok)
      (run-command "gh" (list "repo" "list" "dotcl" "--limit" "200"
                              "--visibility" "public"
                              "--json" "name" "-q" ".[].name"))
    (when ok
      (let ((mentioned (mapcar (lambda (name) (format nil "dotcl/~a" name)) ignore)))
        (dolist (entry entries)
          (let ((repo (ref-repo (entry-value entry :ref)))
                (fork-status (entry-value entry :fork-status)))
            (when repo (push repo mentioned))
            ;; :fork-status names a fork in prose; match on the library name.
            (when fork-status
              (push (format nil "dotcl/~a" (entry-value entry :lib)) mentioned))))
        (with-input-from-string (s out)
          (loop for name = (read-line s nil)
                while name
                for trimmed = (string-trim '(#\Space #\Return) name)
                unless (or (string= trimmed "")
                           (member (format nil "dotcl/~a" trimmed) mentioned
                                   :test #'string=))
                  do (format t "~&note: dotcl/~a is not mentioned in the manifest~%" trimmed)))))))

;;; ------------------------------------------------------------------ main

(let* ((manifest (load-manifest))
       (entries (entries manifest))
       (network (getenv "LEDGER_CHECK_NETWORK")))
  (unless (eq (first manifest) :dist)
    (fail "manifest does not start with :dist"))
  (unless (eql 2 (getf (cdr manifest) :format-version))
    (fail "unsupported :format-version ~s" (getf (cdr manifest) :format-version)))
  (dolist (entry entries) (check-schema entry))
  (when network
    (dolist (entry entries)
      (check-pr entry)
      (check-ref entry))
    (check-inventory entries (getf (cdr manifest) :inventory-ignore)))
  (format t "~&checked ~d entr~:@p~@[ (with network checks)~]~%"
          (length entries) network)
  (if *problems*
      (progn
        (format t "~&~d problem~:p:~%" (length *problems*))
        (dolist (p (reverse *problems*)) (format t "  - ~a~%" p))
        #+sbcl (sb-ext:exit :code 1)
        #-sbcl (uiop:quit 1))
      (format t "~&manifest OK~%")))
