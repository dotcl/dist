;;;; Generate a quicklisp dist from the manifest.
;;;;
;;;;   dotcl scripts/gen-dist.lisp                  ; version defaults to today
;;;;   DIST_VERSION=2026-07-26-2 dotcl scripts/gen-dist.lisp
;;;;
;;;; Runs under dotcl on purpose. The system dependencies in systems.txt come
;;;; from reading each .asd, so a successful generation also proves dotcl can
;;;; read the .asd files of everything the dist ships. (Reading a .asd is not
;;;; the same as the system working, but it is the cheapest floor available.)
;;;;
;;;; Writes text files under docs/ — GitHub Pages serves that directory, so the
;;;; subscription URL is https://dotcl.github.io/dist/dotcl.txt. Tarballs are
;;;; written to build/ and belong in the Release named after the dist version;
;;;; they are deliberately not committed.

(load (merge-pathnames "common.lisp" (or *load-truename* *default-pathname-defaults*)))

(in-package #:dotcl-dist)

(defparameter *dist-name* "dotcl")

(defparameter *base-url* "https://dotcl.github.io/dist"
  "Where the generated text is served from. Baked into every generated file,
and the subscription URL is recorded inside each user's installed dist — so
changing it later forces everyone to re-install. Treat it as permanent.")

(defparameter *archive-base-url*
  "https://github.com/dotcl/dist/releases/download"
  "Release assets hold the tarballs: anonymous, stable, CDN-served, and they
keep binaries out of the git history.")

(defparameter *root*
  ;; The name and type have to be dropped first: merging "../" against a file
  ;; pathname keeps them, which silently yields .../build/src/<lib>/gen-dist.lisp.
  (merge-pathnames "../"
                   (make-pathname :name nil :type nil
                                  :defaults (or *load-truename*
                                                *default-pathname-defaults*))))

(defun rooted (relative) (merge-pathnames relative *root*))

;;; ------------------------------------------------------------------
;;; shelling out

(defun run (program &rest args)
  "Run PROGRAM, return its standard output as a string. Errors are fatal:
a dist generated from a half-failed command would be worse than none."
  (let* ((process (uiop:launch-program (cons program args)
                                       :output :stream
                                       :error-output :stream))
         (output (uiop:slurp-input-stream 'string
                                          (uiop:process-info-output process)))
         (errors (uiop:slurp-input-stream 'string
                                          (uiop:process-info-error-output process)))
         (code (uiop:wait-process process)))
    (unless (zerop code)
      (error "~a ~{~a~^ ~} exited ~a~%~a" program args code errors))
    output))

(defun trimmed (string)
  (string-trim '(#\Space #\Tab #\Newline #\Return) string))

;;; ------------------------------------------------------------------
;;; resolving a :ref to a commit

(defun repo-url (repo) (format nil "https://github.com/~a.git" repo))

(defun entry-repo (entry)
  "The repository a release is built from: the fork when there is one,
otherwise upstream itself."
  (or (ref-repo (entry-value entry :ref))
      (entry-value entry :upstream)))

(defun resolve-commit (entry)
  "Resolve this entry's :ref to a full commit SHA."
  (let* ((ref (entry-value entry :ref))
         (repo (entry-repo entry))
         (url (repo-url repo)))
    (cond
      ((ref-commit ref) (ref-commit ref))
      ((ref-tag ref)
       ;; ^{} dereferences an annotated tag to the commit it points at.
       (let ((out (run "git" "ls-remote" url
                       (format nil "refs/tags/~a^{}" (ref-tag ref)))))
         (when (zerop (length (trimmed out)))
           (setf out (run "git" "ls-remote" url
                          (format nil "refs/tags/~a" (ref-tag ref)))))
         (first-word out)))
      ((ref-branch ref)
       (first-word (run "git" "ls-remote" url
                        (format nil "refs/heads/~a" (ref-branch ref)))))
      (t ;; :upstream-default — whatever HEAD points at
       (first-word (run "git" "ls-remote" url "HEAD"))))))

(defun first-word (line)
  (let* ((line (trimmed line))
         (space (position-if (lambda (c) (member c '(#\Space #\Tab))) line)))
    (when (zerop (length line))
      (error "empty git ls-remote result — does the ref exist?"))
    (subseq line 0 (or space (length line)))))

;;; ------------------------------------------------------------------
;;; building a reproducible tarball

(defun checkout-dir (lib) (rooted (format nil "build/src/~a/" lib)))

(defun fetch-repo (lib repo commit)
  "A working tree of REPO checked out at COMMIT. Incremental: the clone is
kept between runs and only the missing commit is fetched."
  (let ((dir (checkout-dir lib))
        (url (repo-url repo)))
    (ensure-directories-exist dir)
    (unless (probe-file (merge-pathnames ".git/HEAD" dir))
      (run "git" "init" "--quiet" (native dir)))
    ;; set-url rather than add, so a re-run against an existing clone is a no-op
    ;; and a changed :ref repository is picked up instead of ignored.
    (run "git" "-C" (native dir) "remote"
         (if (search "origin" (run "git" "-C" (native dir) "remote")) "set-url" "add")
         "origin" url)
    (run "git" "-C" (native dir) "fetch" "--quiet" "--tags" "origin" commit)
    ;; A working tree is needed because the .asd files get loaded to find out
    ;; what systems they define.
    (run "git" "-C" (native dir) "checkout" "--quiet" "--detach" "--force" commit)
    dir))

(defun native (pathname) (uiop:native-namestring pathname))

(defun short-sha (commit) (subseq commit 0 7))

(defun commit-date (dir commit)
  "The commit's date as YYYYMMDD, used in the release prefix the way quicklisp
names its own releases."
  (remove #\- (trimmed (run "git" "-C" (native dir)
                            "show" "-s" "--format=%cd" "--date=short" commit))))

(defun release-prefix (lib dir commit)
  (format nil "~a-~a-~a" lib (commit-date dir commit) (short-sha commit)))

(defun build-tarball (lib dir commit prefix)
  "git archive | gzip -n, so the same commit always produces the same bytes.
gzip without -n omits the timestamp and original file name; git archive takes
file mtimes from the commit. GitHub's own /archive/ tarballs are not stable
over time, which is why the dist never points at them."
  (let ((out (rooted (format nil "build/~a.tar.gz" prefix))))
    (ensure-directories-exist out)
    (uiop:run-program
     (format nil "git -C ~a archive --format=tar --prefix=~a/ ~a | gzip -n > ~a"
             (native dir) prefix commit (native out))
     :force-shell t :output t :error-output t)
    out))

;;; ------------------------------------------------------------------
;;; digests
;;;
;;; The client stores archive-md5 and archive-content-sha1 but never checks
;;; them against a download; content-sha1 is only compared between dist
;;; versions to report that a release changed (dist-update.lisp). So both are
;;; taken over the tarball bytes here. That differs from quicklisp-controller,
;;; whose content-sha1 is computed over the unpacked contents — do not assume
;;; the two are interchangeable. What matters is that the value is
;;; content-derived and stable, which reproducible tarballs give us.

(defun file-bytes (path)
  (with-open-file (s path :element-type '(unsigned-byte 8))
    (let ((buffer (make-array (file-length s) :element-type '(unsigned-byte 8))))
      (read-sequence buffer s)
      buffer)))

(defun digest (algorithm bytes)
  "Hex digest of BYTES. ComputeHash hands back a .NET Byte[] rather than a Lisp
vector, so Convert.ToHexString turns it straight into a string instead of
marshalling the array element by element."
  (let* ((hasher (dotnet:static (format nil "System.Security.Cryptography.~a" algorithm)
                                "Create"))
         (hash (dotnet:invoke hasher "ComputeHash" bytes)))
    (string-downcase (dotnet:static "System.Convert" "ToHexString" hash))))

;;; ------------------------------------------------------------------
;;; system metadata

(defun asd-files (dir commit)
  "Every .asd in the tree at COMMIT, as paths relative to the release prefix.
Scanned rather than declared in the manifest: a declared list is one more thing
that silently goes stale."
  (let ((listing (run "git" "-C" (native dir) "ls-tree" "-r" "--name-only" commit)))
    (remove-if-not (lambda (name) (string= "asd" (pathname-type name)))
                   (uiop:split-string (trimmed listing) :separator '(#\Newline)))))

(defvar *skipped-asds* '()
  ".asd files that could not be read. Named rather than counted so a run that
loses metadata says which files it lost it for.")

(defun systems-in-asd (dir asd)
  "The systems an .asd defines, as (name . dependencies).

asdf is asked rather than the file parsed by hand: :defsystem-depends-on,
read-time conditionals and #. all mean the text is not the truth."
  (let ((path (truename (merge-pathnames asd dir)))
        (result '()))
    (handler-case
        (progn
          (asdf:load-asd path)
          ;; Select by source file rather than by diffing the registry before
          ;; and after. Loading an .asd also registers systems it did not
          ;; define (asdf/driver and friends appear on the first load), and a
          ;; file already pulled in as someone else's dependency registers
          ;; nothing new the second time — which dropped cffi and
          ;; trivial-features themselves from an earlier version of this.
          (dolist (name (asdf:registered-systems))
            (let ((system (asdf:find-system name nil)))
              (when (and system
                         (equal (namestring (or (asdf:system-source-file system) ""))
                                (namestring path)))
                (push (cons name
                            (remove nil
                                    (mapcar (lambda (dep)
                                              (typecase dep
                                                (string dep)
                                                (symbol (string-downcase dep))
                                                (t nil)))
                                            (asdf:system-depends-on system))))
                      result)))))
      (error (condition)
        (push asd *skipped-asds*)
        (format *error-output* "~&;; WARNING: cannot read ~a: ~a~%" asd condition)))
    (nreverse result)))

;;; ------------------------------------------------------------------
;;; output

(defun version ()
  (or (uiop:getenv "DIST_VERSION")
      (multiple-value-bind (sec min hour day month year) (get-decoded-time)
        (declare (ignore sec min hour))
        (format nil "~d-~2,'0d-~2,'0d" year month day))))

(defun version-dir (version)
  (rooted (format nil "docs/~a/~a/" *dist-name* version)))

(defun write-distinfo (stream version)
  (format stream "name: ~a~%" *dist-name*)
  (format stream "version: ~a~%" version)
  (format stream "system-index-url: ~a/~a/~a/systems.txt~%" *base-url* *dist-name* version)
  (format stream "release-index-url: ~a/~a/~a/releases.txt~%" *base-url* *dist-name* version)
  (format stream "archive-base-url: ~a/~%" *archive-base-url*)
  (format stream "canonical-distinfo-url: ~a/~a/~a/distinfo.txt~%" *base-url* *dist-name* version)
  (format stream "distinfo-subscription-url: ~a/~a.txt~%" *base-url* *dist-name*))

(defun archive-url (version prefix)
  (format nil "~a/dist-~a/~a.tar.gz" *archive-base-url* version prefix))

(defun generate ()
  (let* ((manifest (load-manifest))
         (entries (dist-entries manifest))
         (version (version))
         (dir (version-dir version))
         (releases '())
         (systems '()))
    (ensure-directories-exist dir)
    ;; Pass 1: fetch and package. No .asd is read yet — libraries in the same
    ;; dist refer to each other (cffi's .asd wants trivial-features), so every
    ;; checkout has to exist and be visible to asdf before any of them is read.
    (dolist (entry entries)
      (let* ((lib (entry-value entry :lib))
             (repo (entry-repo entry))
             (commit (resolve-commit entry)))
        (format *error-output* "~&;; ~a ~a @ ~a~%" lib repo (short-sha commit))
        (let* ((checkout (fetch-repo lib repo commit))
               (prefix (release-prefix lib checkout commit))
               (tarball (build-tarball lib checkout commit prefix))
               (bytes (file-bytes tarball)))
          (push (list :lib lib
                      :url (archive-url version prefix)
                      :size (length bytes)
                      :md5 (digest "MD5" bytes)
                      :sha1 (digest "SHA1" bytes)
                      :prefix prefix
                      :checkout checkout
                      :commit commit
                      :asds (asd-files checkout commit))
                releases))))
    (setf releases (nreverse releases))
    ;; Pass 2: read the .asd files with every checkout on the registry.
    (dolist (r releases)
      (pushnew (getf r :checkout) asdf:*central-registry* :test #'equal))
    ;; A few .asd files reference systems from outside this dist — cffi's test
    ;; systems want alexandria — and an unresolvable reference makes the whole
    ;; file unreadable, losing every system it defines. Those are reported as
    ;; skipped below rather than silently dropped. Resolving them needs the
    ;; surrounding library universe on the registry, which is a property of the
    ;; environment the generator runs in, not of the generator: pulling
    ;; quicklisp in from here instead picks up whatever .asd files happen to
    ;; surround the working directory, which makes the output depend on where it
    ;; was run.
    (dolist (r releases)
      (dolist (asd (getf r :asds))
        (dolist (system (systems-in-asd (getf r :checkout) asd))
          (push (list (getf r :lib) (pathname-name asd) (car system) (cdr system))
                systems))))
    (setf systems (nreverse systems))
    (with-open-file (s (merge-pathnames "distinfo.txt" dir)
                       :direction :output :if-exists :supersede)
      (write-distinfo s version))
    (with-open-file (s (merge-pathnames "releases.txt" dir)
                       :direction :output :if-exists :supersede)
      (format s "# project url size file-md5 content-sha1 prefix [system-file1..system-fileN]~%")
      (dolist (r releases)
        (format s "~a ~a ~a ~a ~a ~a~{ ~a~}~%"
                (getf r :lib) (getf r :url) (getf r :size)
                (getf r :md5) (getf r :sha1) (getf r :prefix) (getf r :asds))))
    (with-open-file (s (merge-pathnames "systems.txt" dir)
                       :direction :output :if-exists :supersede)
      (format s "# project system-file system-name [dependency1..dependencyN]~%")
      (dolist (entry systems)
        (destructuring-bind (lib file name deps) entry
          (format s "~a ~a ~a~{ ~a~}~%" lib file name deps))))
    ;; The subscription file is a copy of the newest distinfo; it is what
    ;; update-dist follows, so it is the only text that changes in place.
    (with-open-file (s (rooted (format nil "docs/~a.txt" *dist-name*))
                       :direction :output :if-exists :supersede)
      (write-distinfo s version))
    ;; One line per version, append-only. The client derives this file's URL
    ;; from the subscription URL (make-versions-url: dotcl.txt →
    ;; dotcl-versions.txt), which is what makes installing an older version —
    ;; pinning, in quicklisp's sense — work without any extra design.
    (let ((path (rooted (format nil "docs/~a-versions.txt" *dist-name*)))
          (line (format nil "~a ~a/~a/~a/distinfo.txt" version *base-url* *dist-name* version)))
      (let ((existing (when (probe-file path)
                        (uiop:read-file-lines path))))
        (unless (member line existing :test #'string=)
          (with-open-file (s path :direction :output
                               :if-exists :append :if-does-not-exist :create)
            (format s "~a~%" line)))))
    (format *error-output* "~&;; ~a releases, ~a systems → ~a~%"
            (length releases) (length systems) (native dir))
    (when *skipped-asds*
      (format *error-output*
              ";; ~a .asd file(s) skipped — the systems they define are NOT in this dist:~%~{;;   ~a~%~}"
              (length *skipped-asds*) (reverse *skipped-asds*)))))

(generate)
