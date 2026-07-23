;;;; dotcl dist manifest — where to get the sources of libraries that need
;;;; dotcl-specific support code.
;;;;
;;;; This file is data, not code: a single s-expression, read with *read-eval*
;;;; bound to NIL. Tools read it to decide which fork/branch of a library to
;;;; fetch on dotcl; humans read it to see what is still carried out of tree.
;;;;
;;;; An entry exists only while dotcl needs a non-stock source. When the
;;;; support code is merged upstream and reaches the stock distribution, the
;;;; entry is deleted — the empty manifest is the goal state. Git history is
;;;; the record of what used to be here; nothing is kept as a tombstone.
;;;;
;;;; See README.md for the schema and the promotion/retirement rules.

(:dist
 :format-version 1
 :audited "2026-07-24"
 ;; First-party public projects under the same organization. They are not
 ;; libraries carried for dotcl, so the inventory check does not expect them
 ;; here. Only public repositories belong in this list — the check itself
 ;; looks at public repositories only.
 :inventory-ignore ("dotcl" "playa" "paalam")
 :criteria
 "An entry is listed once the dotcl support code has a public home: a pull
  request filed upstream (open or merged), a source shipped inside a dotcl
  release, or at minimum a public fork. Work that exists only on someone's
  disk is not listed here."
 :entries
 ((:lib "trivial-gray-streams"
   :upstream "trivial-gray-streams/trivial-gray-streams"
   :disposition :upstream-merged
   :ref :upstream-default
   :pr "trivial-gray-streams/trivial-gray-streams#17"
   :fork-status (:redundant "dotcl/trivial-gray-streams:dotcl — merged upstream, kept only until the entry retires")
   :retire-when "a quicklisp dist ships the merged version and dotcl pulls stock"
   :notes "Adds :dotcl to the gray-streams backend selection. Merged 2026-07-13.")

  (:lib "micros"
   :upstream "lem-project/micros"
   :disposition :upstream-pr-open
   :ref ("dotcl/micros" :branch "dotcl")
   :pr "lem-project/micros#22"
   :retire-when "PR 22 merges and the merged version reaches the stock distribution"
   :notes "Adds a dotcl (.NET) backend, so Lem/SLIME-style tooling can attach to a dotcl image.")

  (:lib "quicklisp-client"
   :upstream "quicklisp/quicklisp-client"
   :disposition :upstream-pr-open
   :ref ("dotcl/quicklisp-client" :branch "dotcl-support")
   :pr "quicklisp/quicklisp-client#245"
   :retire-when "PR 245 merges and dotcl pulls the stock client"
   :notes "Adds dotcl support to the client's implementation detection and fasl paths.")

  (:lib "babel"
   :upstream "cl-babel/babel"
   :disposition :upstream-pr-open
   :ref ("snmsts/babel" :branch "utf-16-host-surrogate-support")
   :pr "cl-babel/babel#67"
   :retire-when "PR 67 merges and a quicklisp dist ships the merged version"
   :notes "Encodes astral-plane characters as surrogate pairs on UTF-16 hosts. Not
           dotcl-specific: the same bug is visible on any UTF-16 host.")

  (:lib "asdf"
   :upstream "common-lisp/asdf"
   :upstream-host :gitlab
   :disposition :bundled-in-release
   :ref ("dotcl/asdf" :branch "dotcl-0.1.11")
   :pr nil
   :retire-when "the upstream merge request lands and dotcl stops vendoring asdf"
   :notes "Shipped inside dotcl releases as a precompiled fasl, so the branch here is
           what a source build clones. dotcl-0.1.11 is the current compatibility
           generation, updated in place; a new dotcl-X.Y.Z branch is cut only on the
           next hard incompatibility, and older branches stay frozen for older
           releases. The upstream project lives on GitLab and the merge request is
           still waiting on account approval.")

  (:lib "cffi"
   :upstream "cffi/cffi"
   :disposition :fork-only
   :ref ("dotcl/cffi" :branch "dotcl")
   :pr nil
   :retire-when "an upstream PR merges and reaches the stock distribution"
   :notes "CFFI-SYS backend for dotcl. OS-independent: the platform and the C long
           size are resolved at run time rather than at read time, so one source
           works on Windows (LLP64) and Unix (LP64). Upstream PR not filed yet.")

  (:lib "trivial-features"
   :upstream "trivial-features/trivial-features"
   :disposition :fork-only
   :ref ("dotcl/trivial-features" :branch "dotcl")
   :pr nil
   :retire-when "an upstream PR merges and reaches the stock distribution"
   :notes "Adds a dotcl backend plus the .asd component guard that selects it.
           Upstream PR not filed yet.")))
