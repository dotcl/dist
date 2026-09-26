;;;; Tests for the source ledger checks. No network: repository identities come
;;;; from a stub, and history comes from a throwaway git repository.
;;;;
;;;;   sbcl --script scripts/test-source-ledger.lisp   ; or: dotcl scripts/test-source-ledger.lisp
;;;;
;;;; Exits non-zero when a check fails.

(require "asdf")

(load (merge-pathnames "common.lisp" (or *load-truename* *default-pathname-defaults*)))
(load (merge-pathnames "source-ledger.lisp" (or *load-truename* *default-pathname-defaults*)))

(in-package #:dotcl-dist)

(defvar *failures* 0)
(defvar *count* 0)

(defun check (name ok)
  (incf *count*)
  (unless ok (incf *failures*))
  (format t "~:[FAIL~;ok  ~] ~a~%" ok name))

;;; ------------------------------------------------------------------
;;; a repository with a line of history and an unrelated commit
;;;
;;;   a -- b        main
;;;   c             unrelated (no common history)

(defun git (dir &rest args)
  (trimmed (apply #'run "git" "-C" (native dir)
                  "-c" "user.name=test" "-c" "user.email=test@example.invalid"
                  "-c" "commit.gpgsign=false"
                  args)))

(defun make-repo ()
  (let ((dir (merge-pathnames
              (format nil "source-ledger-test-~36r/" (random (expt 36 8) (make-random-state t)))
              (uiop:temporary-directory))))
    (ensure-directories-exist dir)
    (git dir "init" "--quiet")
    (git dir "commit" "--quiet" "--allow-empty" "-m" "a")
    (let ((a (git dir "rev-parse" "HEAD")))
      (git dir "commit" "--quiet" "--allow-empty" "-m" "b")
      (let ((b (git dir "rev-parse" "HEAD")))
        (git dir "checkout" "--quiet" "--orphan" "unrelated")
        (git dir "commit" "--quiet" "--allow-empty" "-m" "c")
        (let ((c (git dir "rev-parse" "HEAD")))
          (values dir a b c))))))

;;; ------------------------------------------------------------------
;;; stubbed host

(defvar *identities* '()
  "(source . identity) pairs the stub answers from.")

(defun stub-identity (host repo)
  (declare (ignore host))
  (let ((found (assoc repo *identities* :test #'string-equal)))
    (if found
        (cdr found)
        (list :error (format nil "~a: Not Found (HTTP 404)" repo)))))

(defun ident (repo-id owner-id name)
  (list :repo-id repo-id :owner-id owner-id :name name))

(defun run-tests ()
  (multiple-value-bind (dir a b c) (make-repo)
    (let* ((*repo-identity-function* 'stub-identity)
           (*identities* (list (cons "someone/lib" (ident 100 10 "someone/lib"))))
           (recorded (make-ledger-entry "lib" :github "someone/lib"
                                        (ident 100 10 "someone/lib") a)))
      (flet ((try (commit &optional (ledger (list recorded)) (source "someone/lib"))
               (check-sources (list (list :lib "lib" :host :github :source source
                                          :commit commit :dir dir))
                              ledger)))

        ;; bootstrap
        (multiple-value-bind (new refusals) (try b '())
          (check "no entry: recorded and continued"
                 (and (null refusals)
                      (equal (getf (first new) :commit) b)
                      (eql (getf (first new) :repo-id) 100)
                      (eql (getf (first new) :owner-id) 10))))

        ;; normal update
        (multiple-value-bind (new refusals) (try b)
          (check "descendant commit, same ids: updated"
                 (and (null refusals) (equal (getf (first new) :commit) b))))
        (multiple-value-bind (new refusals) (try a)
          (check "same commit: unchanged"
                 (and (null refusals) (equal (getf (first new) :commit) a))))

        ;; history that does not continue the recorded commit
        (multiple-value-bind (new refusals) (try c)
          (check "unrelated HEAD: stopped"
                 (and (null new) refusals
                      (search "does not descend" (cdr (first refusals))))))
        (multiple-value-bind (new refusals)
            (try b (list (make-ledger-entry "lib" :github "someone/lib"
                                            (ident 100 10 "someone/lib") c)))
          (check "recorded commit not in the new history: stopped"
                 (and (null new) refusals)))
        (multiple-value-bind (new refusals)
            (try b (list (make-ledger-entry "lib" :github "someone/lib"
                                            (ident 100 10 "someone/lib")
                                            "0123456789abcdef0123456789abcdef01234567")))
          (check "recorded commit unknown to the clone: stopped"
                 (and (null new) refusals)))

        ;; a different repository behind the same name
        (let ((*identities* (list (cons "someone/lib" (ident 999 10 "someone/lib")))))
          (multiple-value-bind (new refusals) (try b)
            (check "different repository id: stopped"
                   (and (null new) refusals
                        (search "repository id 999" (cdr (first refusals)))))))
        (let ((*identities* (list (cons "someone/lib" (ident 100 77 "someone/lib")))))
          (multiple-value-bind (new refusals) (try b)
            (check "different owner id: stopped"
                   (and (null new) refusals
                        (search "owner id 77" (cdr (first refusals)))))))
        (let ((*identities* '()))
          (multiple-value-bind (new refusals) (try b)
            (check "repository not found: stopped"
                   (and (null new) refusals))))
        ;; ids are checked even when the commit has not moved
        (let ((*identities* (list (cons "someone/lib" (ident 999 10 "someone/lib")))))
          (multiple-value-bind (new refusals) (try a)
            (check "same commit, different repository id: stopped"
                   (and (null new) refusals))))

        ;; rename: same ids, new name
        (let ((*identities* (list (cons "someone/lib" (ident 100 10 "someone/lib-renamed")))))
          (multiple-value-bind (new refusals notes) (try b)
            (check "rename: name updated, continued"
                   (and (null refusals)
                        (equal (getf (first new) :name) "someone/lib-renamed")
                        (equal (getf (first new) :source) "someone/lib")
                        (search "renamed" (cdr (first notes)))))))
        ;; the manifest then follows the rename
        (let ((*identities* (list (cons "someone/lib-renamed"
                                        (ident 100 10 "someone/lib-renamed")))))
          (multiple-value-bind (new refusals) (try c (list recorded) "someone/lib-renamed")
            (check "manifest follows the rename: history still checked"
                   (and (null new) refusals))))

        ;; the manifest names a different source on purpose
        (let ((*identities* (list (cons "upstream/lib" (ident 500 50 "upstream/lib")))))
          (multiple-value-bind (new refusals notes) (try c (list recorded) "upstream/lib")
            (check "source changed in the manifest: recorded afresh"
                   (and (null refusals)
                        (eql (getf (first new) :repo-id) 500)
                        (equal (getf (first new) :commit) c)
                        (search "source changed" (cdr (first notes)))))))

        ;; a host with no identity API: only history
        (let ((*repo-identity-function* (constantly :none))
              (plain (make-ledger-entry "lib" :gitlab "someone/lib" '() a)))
          (multiple-value-bind (new refusals) (try b (list plain))
            (check "no identity API: descendant accepted"
                   (and (null refusals) (equal (getf (first new) :commit) b))))
          (multiple-value-bind (new refusals) (try c (list plain))
            (check "no identity API: unrelated HEAD stopped"
                   (and (null new) refusals))))

        ;; one project stopping does not hide the others
        (let ((*identities* (list (cons "someone/lib" (ident 100 10 "someone/lib"))
                                  (cons "other/lib" (ident 999 20 "other/lib")))))
          (multiple-value-bind (new refusals)
              (check-sources
               (list (list :lib "lib" :host :github :source "someone/lib" :commit b :dir dir)
                     (list :lib "other" :host :github :source "other/lib" :commit b :dir dir))
               (list recorded
                     (make-ledger-entry "other" :github "other/lib"
                                        (ident 200 20 "other/lib") a)))
            (declare (ignore new))
            (check "refusals are reported per project"
                   (equal (mapcar #'car refusals) '("other")))))

        ;; the file round-trips, one entry per line
        (let ((path (merge-pathnames "ledger.lisp" dir))
              (entries (list recorded
                             (make-ledger-entry "other" :codeberg "x/y"
                                                (ident 1 2 "x/y") b))))
          (write-ledger entries path)
          (check "ledger file round-trips"
                 (equal (read-ledger path) entries))
          (check "one entry per line"
                 (= 2 (count-if (lambda (l) (search "(:lib " l))
                                (uiop:read-file-lines path)))))

        (check "JSON: nested owner id and top-level name"
               (equal (identity-from-json
                       (parse-json "{\"id\": 5, \"owner\": {\"id\": 6, \"full_name\": \"A B\"},
                                     \"full_name\": \"o\\/r\", \"fork\": false, \"x\": [1, null]}"))
                      (ident 5 6 "o/r")))))
    (ignore-errors
     (uiop:delete-directory-tree dir :validate t :if-does-not-exist :ignore)))
  (format t "~&~d/~d passed~%" (- *count* *failures*) *count*)
  (uiop:quit (if (zerop *failures*) 0 1)))

(run-tests)
