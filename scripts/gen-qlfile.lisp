;;;; Emit a qlot qlfile for the libraries that still need a non-stock source.
;;;;
;;;;   sbcl --script scripts/gen-qlfile.lisp > qlfile
;;;;   dotcl scripts/gen-qlfile.lisp > qlfile
;;;;
;;;; Libraries whose support code is already merged upstream, or that ship
;;;; inside a dotcl release, emit nothing: for those you want stock.

(load (merge-pathnames "common.lisp" (or *load-truename* *default-pathname-defaults*)))

(in-package #:dotcl-dist)

(let ((manifest (load-manifest)))
  (format t ";;;; Generated from the dotcl dist manifest (audited ~a).~%"
          (getf (cdr manifest) :audited))
  (format t ";;;; Regenerate with scripts/gen-qlfile.lisp — do not edit by hand.~%")
  (dolist (entry (entries manifest))
    (let* ((lib (entry-value entry :lib))
           (disposition (entry-value entry :disposition))
           (ref (entry-value entry :ref))
           (repo (ref-repo ref))
           (branch (ref-branch ref)))
      (case disposition
        (:upstream-merged
         (format t "~&;; ~a: merged upstream — use stock~%" lib))
        (:bundled-in-release
         (format t "~&;; ~a: ships inside the dotcl release — do not fetch~%" lib))
        (t
         (when (and repo branch)
           (format t "~&github ~a ~a :branch ~a~%" lib repo branch)))))))
