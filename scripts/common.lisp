;;;; Shared manifest loading for the scripts in this directory.
;;;; Portable Common Lisp: runs under sbcl --script and under dotcl.

(defpackage #:dotcl-dist
  (:use #:cl)
  (:export #:load-manifest #:entries #:entry-value #:ref-repo #:ref-branch
           #:ref-tag #:ref-commit #:bundled-p #:dist-entries
           #:manifest-path #:parse-pr
           #:*hosts* #:entry-host #:repo-url #:entry-repo-url))

(in-package #:dotcl-dist)

(defun manifest-path ()
  "Path of manifest.lisp, resolved relative to this script's directory."
  (merge-pathnames "../manifest.lisp"
                   (or *load-truename* *default-pathname-defaults*)))

(defun load-manifest (&optional (path (manifest-path)))
  "Read the manifest as data. *READ-EVAL* is off: this file is never code."
  (with-open-file (s path :direction :input)
    (let ((*read-eval* nil))
      (read s))))

(defun entries (manifest)
  (getf (cdr manifest) :entries))

(defun entry-value (entry key &optional default)
  "Entries are plain plists — (:lib \"x\" :upstream \"y\" …) — unlike the
manifest itself, which is tagged with a leading :DIST."
  (getf entry key default))

(defun ref-repo (ref)
  "owner/repo of a :ref, or NIL when the ref is upstream itself."
  (when (consp ref) (first ref)))

(defun ref-branch (ref)
  (when (consp ref) (getf (rest ref) :branch)))

(defun ref-tag (ref)
  (when (consp ref) (getf (rest ref) :tag)))

(defun ref-commit (ref)
  "A :ref pinned to an exact commit. Preferred over :branch: it makes a
regenerated dist byte-identical and keeps unrelated upstream churn out."
  (when (consp ref) (getf (rest ref) :commit)))

(defun bundled-p (entry)
  "True when dotcl ships this library itself, so nothing needs fetching.

Separate from :disposition, which records the relationship with upstream. The
two are independent: quicklisp-client has an open upstream pull request and is
bundled at the same time."
  (entry-value entry :bundled))

(defun dist-entries (manifest)
  "Entries that become releases in the generated dist.

Everything except what dotcl bundles. An entry whose fix is already merged
upstream still belongs here: the stock quicklisp dist keeps shipping the old
version until it catches up, which is exactly what :retire-when describes."
  (remove-if #'bundled-p (entries manifest)))

;;; ------------------------------------------------------------------
;;; where a repository lives

(defparameter *hosts*
  '((:github . "https://github.com/~a.git")
    (:codeberg . "https://codeberg.org/~a.git")
    (:gitlab . nil))
  "Known :upstream-host values, mapped to a clone URL template.

:gitlab has no template on purpose. The one GitLab entry, asdf, is :bundled and
so is never fetched, and GitLab is not one site the way github.com and
codeberg.org are; an entry that needs cloning from one should add its instance
here deliberately rather than inherit a guess.")

(defun entry-host (entry)
  "Where upstream lives. :github unless the entry says otherwise."
  (entry-value entry :upstream-host :github))

(defun repo-url (repo host)
  (let ((template (cdr (assoc host *hosts*))))
    (unless template
      (error "no clone URL for ~a on ~s; add the host to *HOSTS*" repo host))
    (format nil template repo)))

(defun entry-repo-url (entry)
  "Clone URL of the repository a release is built from.

A :ref fork is one of ours and lives in the dotcl organization on GitHub
whatever the upstream host is, so :upstream-host is consulted only when the ref
is upstream itself."
  (let ((fork (ref-repo (entry-value entry :ref))))
    (if fork
        (repo-url fork :github)
        (repo-url (entry-value entry :upstream) (entry-host entry)))))

(defun parse-pr (pr)
  "Split \"owner/repo#123\" into (values \"owner/repo\" 123), or NIL."
  (when (stringp pr)
    (let ((hash (position #\# pr)))
      (when hash
        (values (subseq pr 0 hash)
                (parse-integer (subseq pr (1+ hash)) :junk-allowed t))))))
