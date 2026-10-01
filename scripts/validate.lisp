;;;; Validate manifest.lisp.
;;;;
;;;;   sbcl --script scripts/validate.lisp          ; schema only
;;;;   LEDGER_CHECK_NETWORK=1 sbcl --script ...     ; + gh and release-asset checks
;;;;
;;;; Exits non-zero if anything fails, so CI can gate on it.

(require "asdf")

(load (merge-pathnames "common.lisp" (or *load-truename* *default-pathname-defaults*)))

(in-package #:dotcl-dist)

(defparameter *dispositions*
  '(:upstream-merged :upstream-pr-open :fork-only :patched))

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


;;; ------------------------------------------------------- published URLs

;;; Every releases.txt ever written is kept, and later versions point into
;;; earlier releases, so a release asset that goes missing breaks dist versions
;;; nobody has touched since.  It has happened: two tarballs were not attached
;;; in 2026-09-15 and the URLs naming them answered 404 until it was noticed by
;;; hand.  So each asset is downloaded rather than the file trusted.
;;;
;;; Answering 200 is not enough either.  The client compares the size of the
;;; archive on disk with the size in releases.txt and stops with
;;; BADLY-SIZED-LOCAL-ARCHIVE when they differ; 2026-09-29 described 15 reused
;;; tarballs by a local rebuild whose gzip output differed from the uploaded
;;; bytes, and update-dist from 2026-09-19 failed.  So size and file-md5 of
;;; every line are checked against the downloaded bytes.
(defun release-lines ()
  "Every (version url size md5) recorded under docs/, newest version last."
  (loop for dir in (sort (directory (rooted (format nil "docs/~a/*/" *dist-name*)))
                         #'string< :key #'namestring)
        for file = (merge-pathnames "releases.txt" dir)
        when (probe-file file)
          append (let ((version (car (last (pathname-directory dir)))))
                   (loop for line in (uiop:read-file-lines file)
                         unless (or (zerop (length line)) (char= (char line 0) #\#))
                           collect (destructuring-bind (project url size md5 &rest rest)
                                       (uiop:split-string line :separator " ")
                                     (declare (ignore project rest))
                                     (list version url (parse-integer size) md5))))))

#+sbcl (require :sb-md5)

(defun file-md5 (path)
  "Lowercase hex md5 of the file at PATH."
  #+sbcl
  (format nil "~(~{~2,'0x~}~)" (coerce (sb-md5:md5sum-file path) 'list))
  #+dotcl
  (let ((hasher (dotnet:static "System.Security.Cryptography.MD5" "Create"))
        (bytes (with-open-file (s path :element-type '(unsigned-byte 8))
                 (let ((b (make-array (file-length s) :element-type '(unsigned-byte 8))))
                   (read-sequence b s)
                   b))))
    (string-downcase
     (dotnet:static "System.Convert" "ToHexString"
                    (dotnet:invoke hasher "ComputeHash" bytes))))
  #-(or sbcl dotcl)
  (error "no md5 on this implementation"))

(defun download (url path)
  "Fetch URL into PATH; true when curl succeeded.  -f makes a 404 a failure."
  (when (probe-file path) (delete-file path))
  (nth-value 1 (run-command "curl" (list "-sfL" "-o" (uiop:native-namestring path) url))))

(defun check-published-urls ()
  "Every URL any published releases.txt names must still be downloadable, and
its size and md5 must be the ones every line naming it records."
  (let ((assets (make-hash-table :test 'equal))
        (temp (merge-pathnames "validate-asset.tmp" (uiop:temporary-directory)))
        (checked 0))
    (dolist (line (release-lines))
      (destructuring-bind (version url size md5) line
        (multiple-value-bind (actual seen) (gethash url assets)
          (unless seen
            (incf checked)
            (setf actual (and (download url temp)
                              (cons (with-open-file (s temp :element-type '(unsigned-byte 8))
                                      (file-length s))
                                    (file-md5 temp)))
                  (gethash url assets) actual))
          (cond ((null actual)
                 (fail "dist ~a: release asset missing: ~a" version url))
                ((not (eql size (car actual)))
                 (fail "dist ~a: ~a: releases.txt says size ~a, the asset is ~a"
                       version url size (car actual)))
                ((not (string-equal md5 (cdr actual)))
                 (fail "dist ~a: ~a: releases.txt says md5 ~a, the asset is ~a"
                       version url md5 (cdr actual)))))))
    (when (probe-file temp) (delete-file temp))
    (format t "~&checked ~d release asset~:p~%" checked)))

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
        ((:upstream-pr-open :fork-only)
         (unless (and (ref-repo ref) (ref-branch ref))
           (fail "~a: :ref must be (\"owner/repo\" :branch \"name\"), got ~s" lib ref)))
        (:patched
         ;; Patch files only apply to the tree they were made against, so the
         ;; upstream commit is pinned rather than followed.
         (let ((commit (ref-commit ref)))
           (unless (and (consp ref) (eq (first ref) :upstream)
                        (stringp commit) (= (length commit) 40)
                        (every (lambda (c) (digit-char-p c 16)) commit))
             (fail "~a: :patched needs :ref (:upstream :commit \"<40-hex sha>\"), got ~s"
                   lib ref)))
         (let ((patches (entry-patches entry)))
           (unless (and patches (listp patches) (every #'stringp patches))
             (fail "~a: :patched needs a non-empty :patches list of file names" lib))
           (dolist (patch (and (listp patches) patches))
             (unless (and (stringp patch) (probe-file (rooted patch)))
               (fail "~a: patch file ~s does not exist" lib patch))))))
      (when (and (entry-patches entry) (not (eq disposition :patched)))
        (fail "~a: :patches is only read for :patched entries" lib))
      ;; A pending or merged PR must actually be recorded as :pr.
      (when (and (member disposition '(:upstream-merged :upstream-pr-open))
                 (not pr))
        (fail "~a: ~s requires :pr" lib disposition))
      (when (and (member disposition '(:fork-only :patched)) pr)
        (fail "~a: ~s must not carry a :pr (promote it instead)" lib disposition))
      (when pr
        (multiple-value-bind (repo number) (parse-pr pr)
          (unless (and repo number)
            (fail "~a: :pr ~s is not \"owner/repo#number\"" lib pr)))))))


(defun check-patch-files (entries)
  "Every file under patches/ must be named by an entry. A patch nobody lists is
never applied, and nothing else would notice it."
  (let ((listed (loop for entry in entries
                      append (loop for patch in (entry-patches entry)
                                   for path = (and (stringp patch) (probe-file (rooted patch)))
                                   when path collect (namestring path)))))
    (dolist (file (directory (rooted "patches/*/*.*")))
      (unless (member (namestring file) listed :test #'string=)
        (fail "~a is not listed in any entry's :patches"
              (enough-namestring file *root*))))))

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
  (dolist (entry entries)
    (check-schema entry))
  (check-patch-files entries)
  (when network
    (dolist (entry entries)
      (check-pr entry)
      (check-ref entry))
    (check-inventory entries (getf (cdr manifest) :inventory-ignore))
    (check-published-urls))
  (format t "~&checked ~d entr~:@p~@[ (with network checks)~]~%"
          (length entries) network)
  (if *problems*
      (progn
        (format t "~&~d problem~:p:~%" (length *problems*))
        (dolist (p (reverse *problems*)) (format t "  - ~a~%" p))
        #+sbcl (sb-ext:exit :code 1)
        #-sbcl (uiop:quit 1))
      (format t "~&manifest OK~%")))
