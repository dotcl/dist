;;;; Load the systems a newly built tarball defines, on this dotcl.
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
;;;; The checkouts under build/src/ are what the tarball was made from, byte for
;;;; byte, so the systems are loaded from there rather than by unpacking again.
;;;; Every library in the dist is on the source registry, because they refer to
;;;; each other.

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

(defun register-checkouts ()
  "Put every build/ checkout on the source registry, newest wins."
  (let ((dirs (directory (rooted "build/src/*/"))))
    (dolist (d dirs)
      (pushnew d asdf:*central-registry* :test #'equal))
    (length dirs)))

(defun check (version)
  (let ((new (new-releases version))
        (failed '()))
    (format t "~&;; dist ~a: ~a new tarball(s)~%" version (length new))
    (when (null new)
      (format t ";; nothing to check~%")
      (return-from check t))
    (format t ";; ~a checkout(s) on the source registry~%" (register-checkouts))
    (dolist (entry new)
      (destructuring-bind (lib prefix) entry
        (declare (ignore prefix))
        (dolist (system (systems-of version lib))
          (format t ";; loading ~a~%" system)
          (finish-output)
          (handler-case
              (handler-bind ((warning #'muffle-warning))
                (asdf:load-system system))
            (error (condition)
              (push (list system (princ-to-string condition)) failed))))))
    (cond (failed
           (format t "~&;; FAILED~%")
           (dolist (f (reverse failed))
             (format t ";;   ~a: ~a~%" (first f) (second f)))
           nil)
          (t
           (format t "~&;; all new systems load on ~a~%" (lisp-implementation-version))
           t))))

(let* ((args (uiop:command-line-arguments))
       (version (or (first args) (newest-version))))
  (uiop:quit (if (check version) 0 1)))
