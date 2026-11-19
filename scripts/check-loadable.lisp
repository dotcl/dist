;;;; Load the systems a newly built tarball defines, the way a user gets them: on
;;;; this dotcl, through its bundled quicklisp with the new dist installed over
;;;; the published one.
;;;;
;;;;   dotcl scripts/check-loadable.lisp                 ; the newest dist version
;;;;   dotcl scripts/check-loadable.lisp 2026-09-19      ; a named one
;;;;
;;;; Exits non-zero if any of them fails, so the upload step can gate on it.
;;;;
;;;; Only the NEW tarballs are checked - the ones whose releases.txt URL points
;;;; at this version's own release rather than an earlier one, which is the same
;;;; set gen-dist prints as UPLOAD.  A tarball that was published before has been
;;;; through this already, and re-checking every library every time would make
;;;; the gate slow enough to skip.
;;;;
;;;; The new dist is not published yet, so it is served from build/stage/ on
;;;; 127.0.0.1 (the quicklisp client speaks http only) with the new tarballs'
;;;; URLs pointed there; the older tarballs keep their published URLs.  Each
;;;; system is then loaded with ql:quickload from what install-dist unpacked, so
;;;; the tarball itself, its size and md5 in releases.txt, and the dependencies
;;;; outside the dist (Quicklisp's own systems) are all part of the check.
;;;; The systems come from systems.txt, never from a hand-kept list.
;;;;
;;;; Needs python3 and curl (the stage server) and, for cffi-libffi, a C
;;;; toolchain with pkg-config and libffi headers.
(load (merge-pathnames "common.lisp" (or *load-truename* *default-pathname-defaults*)))

(in-package #:dotcl-dist)

(require "asdf")

(defun newest-version ()
  (let ((dirs (sort (remove-if-not
                     (lambda (p) (probe-file (merge-pathnames "releases.txt" p)))
                     (directory (rooted (format nil "docs/~a/*/" *dist-name*))))
                    #'string< :key #'namestring)))
    (unless dirs
      (error "no dist version under docs/~a/" *dist-name*))
    (car (last (pathname-directory (car (last dirs)))))))

(defun release-lines (version)
  (remove-if (lambda (l) (or (zerop (length l)) (char= (char l 0) #\#)))
             (uiop:read-file-lines
              (merge-pathnames "releases.txt" (version-dir version)))))

(defun split-spaces (line)
  (let ((out '()) (start 0))
    (loop for i = (position #\Space line :start start)
          do (push (subseq line start i) out)
             (if i (setf start (1+ i)) (return)))
    (remove "" (nreverse out) :test #'string=)))

(defun new-releases (version)
  "The releases whose tarball this version has to upload, as (lib prefix)."
  (loop for line in (release-lines version)
        for fields = (split-spaces line)
        for url = (second fields)
        when (search (format nil "dist-~a/" version) url)
          collect (list (first fields) (sixth fields))))

(defun systems-of (version lib)
  "The system names systems.txt records for LIB, minus the test systems -- a
test system pulls in a test framework the dist does not carry."
  (loop for line in (remove-if (lambda (l) (or (zerop (length l))
                                               (char= (char l 0) #\#)))
                               (uiop:read-file-lines
                                (merge-pathnames "systems.txt" (version-dir version))))
        for fields = (split-spaces line)
        when (and (string= (first fields) lib)
                  (not (search "test" (third fields))))
          collect (third fields)))

;;; ------------------------------------------------------------------
;;; staging and serving the new dist

(defparameter *port* 8765)

(defun base-url () (format nil "http://127.0.0.1:~d/" *port*))

(defun stage-dir () (rooted "build/stage/"))

(defun write-lines (path lines)
  (ensure-directories-exist path)
  (with-open-file (out path :direction :output :if-exists :supersede)
    (dolist (l lines) (write-line l out))))

(defun replace-all (string old new)
  (with-output-to-string (out)
    (loop with start = 0
          for pos = (search old string :start2 start)
          do (write-string string out :start start :end (or pos (length string)))
             (if pos
                 (progn (write-string new out) (setf start (+ pos (length old))))
                 (return)))))

(defun stage (version)
  "Lay the new dist out under build/stage/: distinfo / systems / releases with
the new tarballs' URLs on the local server, and the tarballs in t/."
  (let* ((dir (stage-dir))
         (vdir (version-dir version))
         (release-prefix (format nil "https://github.com/dotcl/dist/releases/download/dist-~a/" version))
         (pages-prefix (format nil "https://dotcl.github.io/dist/~a/~a/" *dist-name* version)))
    (ensure-directories-exist (merge-pathnames "t/" dir))
    (write-lines (merge-pathnames "distinfo.txt" dir)
                 (mapcar (lambda (l) (replace-all l pages-prefix (base-url)))
                         (uiop:read-file-lines (merge-pathnames "distinfo.txt" vdir))))
    (write-lines (merge-pathnames "systems.txt" dir)
                 (uiop:read-file-lines (merge-pathnames "systems.txt" vdir)))
    (write-lines (merge-pathnames "releases.txt" dir)
                 (mapcar (lambda (l) (replace-all l release-prefix (format nil "~at/" (base-url))))
                         (uiop:read-file-lines (merge-pathnames "releases.txt" vdir))))
    (dolist (line (release-lines version))
      (let ((url (second (split-spaces line))))
        (when (search release-prefix url)
          (let ((file (subseq url (length release-prefix))))
            (uiop:copy-file (rooted (format nil "build/~a" file))
                            (merge-pathnames (format nil "t/~a" file) dir))))))
    dir))

(defun server-up-p ()
  (zerop (nth-value 2 (uiop:run-program
                       (list "curl" "-sf" "-o" "/dev/null" (format nil "~adistinfo.txt" (base-url)))
                       :ignore-error-status t))))

(defun start-server (dir)
  (let ((process (uiop:launch-program
                  (list "python3" "-m" "http.server" (princ-to-string *port*)
                        "--bind" "127.0.0.1" "--directory" (namestring dir))
                  :output nil :error-output nil)))
    (loop repeat 40
          until (server-up-p)
          do (sleep 0.25)
          finally (unless (server-up-p)
                    (uiop:terminate-process process)
                    (error "the stage server did not come up on port ~d" *port*)))
    process))

;;; ------------------------------------------------------------------
;;; the check

(defun ql-call (package name &rest args)
  "The quicklisp client does not exist until (require :quicklisp), after this
file is read."
  (apply (or (find-symbol name package) (error "~a:~a is missing" package name)) args))

(defun seconds-since (start)
  (/ (- (get-internal-real-time) start) (float internal-time-units-per-second)))

(defun install-new-dist ()
  "Bundled quicklisp, with the new dist installed over the published one that
ql:setup puts in on first use."
  (require :quicklisp)
  (ql-call "QL" "SETUP")
  (ql-call "QL-DIST" "INSTALL-DIST" (format nil "~adistinfo.txt" (base-url))
           :replace t :prompt nil))

(defun check (version)
  (let ((new (new-releases version))
        (failed '()))
    (format t "~&;; dist ~a: ~a new tarball(s)~%" version (length new))
    (when (null new)
      (format t ";; nothing to check~%")
      (return-from check t))
    (let ((server (start-server (stage version)))
          (start (get-internal-real-time)))
      (unwind-protect
           (progn
             (install-new-dist)
             (format t "~&;; install-dist: ~,1f s~%" (seconds-since start))
             (let ((load-start (get-internal-real-time)))
               (dolist (entry new)
                 (destructuring-bind (lib prefix) entry
                   (declare (ignore prefix))
                   (dolist (system (systems-of version lib))
                     (format t ";; loading ~a~%" system)
                     (finish-output)
                     (handler-case
                         (handler-bind ((warning #'muffle-warning))
                           (ql-call "QL" "QUICKLOAD" system :silent t))
                       (error (condition)
                         (push (list system (princ-to-string condition)) failed))))))
               (format t "~&;; quickload: ~,1f s~%" (seconds-since load-start))))
        (uiop:terminate-process server)))
    (cond (failed
           (format t "~&;; FAILED~%")
           (dolist (f (reverse failed))
             (format t ";;   ~a: ~a~%" (first f) (second f)))
           nil)
          (t
           (format t "~&;; all new systems quickload on ~a~%" (lisp-implementation-version))
           t))))

(let* ((args (uiop:command-line-arguments))
       (version (or (first args) (newest-version))))
  (uiop:quit (if (check version) 0 1)))
