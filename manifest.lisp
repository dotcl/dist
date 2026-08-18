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
 :format-version 2
 :audited "2026-07-26"
 ;; First-party public projects under the same organization. They are not
 ;; libraries carried for dotcl, so the inventory check does not expect them
 ;; here. Only public repositories belong in this list — the check itself
 ;; looks at public repositories only.
 :inventory-ignore ("dotcl" "playa" "paalam" "dist")
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
   :pr "trivial-gray-streams/trivial-gray-streams#18"
   :fork-status (:redundant "dotcl/trivial-gray-streams:dotcl — merged upstream, kept only until the entry retires")
   :retire-when "a quicklisp dist ships a tgs that includes the file-position bridge (PR 18) and dotcl pulls stock"
   :notes "Two upstream changes, both merged. PR 17 adds :dotcl to the gray-streams backend selection (2026-07-13). PR 18 bridges dotcl-gray:stream-file-position to tgs's own generic function (2026-07-24); :pr names it because it is the binding one — dotcl no longer special-cases the tgs package in FILE-POSITION, so a tgs without PR 18 reports NIL there.")

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
   :bundled t
   :ref ("dotcl/quicklisp-client" :branch "dotcl-support")
   :pr "quicklisp/quicklisp-client#245"
   :retire-when "PR 245 merges and dotcl pulls the stock client"
   :notes "Adds dotcl support to the client's implementation detection and fasl paths.
           dotcl compiles this branch into the quicklisp contrib fasl it ships, so
           (require :quicklisp) needs no download — hence :bundled, even though the
           upstream pull request is still open.")

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
   :bundled t
   :ref ("dotcl/asdf" :branch "dotcl-0.1.21")
   :pr nil
   :retire-when "the upstream merge request lands and dotcl stops vendoring asdf"
   :notes "Shipped inside dotcl releases as a precompiled fasl, so the branch here is
           what a source build clones. dotcl-0.1.21 is the current compatibility
           generation, updated in place; a new dotcl-X.Y.Z branch is cut only on the
           next hard incompatibility, and older branches stay frozen for older
           releases. The upstream project lives on GitLab, where a merge request is
           filed and waiting for review:
           https://gitlab.common-lisp.net/asdf/asdf/-/merge_requests/252. It carries
           the uiop OS-abstraction subset — getenv/quit/argv, run-program,
           raw-command-line-arguments, package-local-nicknames, getcwd,
           *unspecific-pathname-type* — and the branch shipped here has grown past it
           since, so that merge landing would not on its own retire this entry.")

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
   :disposition :upstream-merged
   :ref :upstream-default
   :pr "trivial-features/trivial-features#25"
   :fork-status (:redundant "dotcl/trivial-features:dotcl - merged upstream, kept only until the entry retires")
   :retire-when "a quicklisp dist ships a trivial-features that includes dotcl in the guard"
   :notes "PR 25 merged 2026-08-11 as one line: dotcl joins the
           supported-implementations guard, and there is no backend file.
           dotcl already pushes everything SPEC.md specifies, deciding all of it
           from the CLR when the image starts rather than at read time - which
           matters here, since a dotcl FASL is portable IL and can be loaded on
           an architecture other than the one that compiled it. SPEC.md calls
           this a null implementation.

           An earlier draft did carry a backend. Measuring showed every pushnew
           in it was a no-op, and it turned up two bugs in dotcl on the way: the
           architecture feature said :x86-64 for everything that was not arm64,
           and deriving :32-bit / :64-bit from most-positive-fixnum is wrong
           here, since dotcl's fixnum is a .NET Int64 whatever the pointer is.
           Both fixed in dotcl; the draft is gone.")

  (:lib "trivial-garbage"
   :upstream "trivial-garbage/trivial-garbage"
   :disposition :fork-only
   :ref ("dotcl/trivial-garbage" :branch "dotcl")
   :pr nil
   :retire-when "an upstream PR merges and reaches the stock distribution"
   :notes "Weak pointers, weak hash-tables and finalizers on dotcl's own
           facilities: System.WeakReference, MAKE-HASH-TABLE :weakness for all
           four weakness kinds, and real GC finalizers. Without this the stock
           .asd refuses to load at all, because its supported-implementation
           guard signals an error on an unknown host. Upstream test suite
           passes, 11 of 11. Upstream PR not filed yet.")

  (:lib "bordeaux-threads"
   :upstream "sionescu/bordeaux-threads"
   :disposition :fork-only
   :ref ("dotcl/bordeaux-threads" :branch "dotcl")
   :pr nil
   :retire-when "an upstream PR merges and reaches the stock distribution"
   :notes "Backends for both APIs on System.Threading, and an ATOMIC-INTEGER
           backed by an Interlocked cell, so the counter is lock-free.
           INTERRUPT-THREAD is delivered the next time the target thread blocks
           rather than preempting a running computation, which is as much as
           .NET allows; that is enough for the portable WITH-TIMEOUT. Acquiring
           a lock with a :timeout is the one gap and signals NOT-IMPLEMENTED.
           Both upstream test suites pass. Upstream PR not filed yet.")

  (:lib "dexador"
   :upstream "fukamachi/dexador"
   :disposition :upstream-pr-open
   :ref ("dotcl/dexador" :branch "dotcl")
   :pr "fukamachi/dexador#204"
   :retire-when "PR 204 merges and a quicklisp dist ships the merged version"
   :notes "A backend on System.Net.Http.HttpClient reached through dotcl's dotnet:
           interop, so on dotcl dexador needs neither usocket nor cl+ssl nor cffi;
           the .asd gates those files and dependencies behind (:not :dotcl).
           HttpClient does TLS, redirects and content decoding itself, which is why
           the backend is one file rather than a socket stack, and why it is selected
           on every OS rather than only on Windows the way winhttp is.

           :use-connection-pool and :keep-alive map onto a cached HttpClient keyed by
           insecure and max-redirects, so .NET's own per-origin pool reuses TCP and
           TLS across requests. A per-request timeout needs a CancellationTokenSource
           because HttpClient.Timeout is per client, not per request.

           Checked against the winhttp backend on SBCL: status, content type and body,
           a 404 signalling with its status, redirect following, and pooling on and
           off all agree.")

  (:lib "cl-fad"
   :upstream "edicl/cl-fad"
   :disposition :upstream-merged
   :ref :upstream-default
   :pr "edicl/cl-fad#40"
   :fork-status (:redundant "dotcl/cl-fad:dotcl - merged upstream, kept only until the entry retires")
   :retire-when "a quicklisp dist ships a cl-fad that includes PR 40"
   :notes "PR 40 merged 2026-08-13, unchanged. Four reader conditionals, no new code. LIST-DIRECTORY joins the CMUCL and
           SCL group rather than the ECL and Clasp one: on dotcl a \"*.*\" wildcard
           already matches subdirectories as well as files and returns them in
           directory form, so the ECL union with \"*/\" reports every subdirectory
           twice. Checked against SBCL, which returns the same pathnames in the same
           order.

           The GETENV arm in temporary-files.lisp is not reachable on dotcl today.
           Setting up the TEMPORARY-FILES logical host is guarded by an error from
           LOGICAL-PATHNAME-TRANSLATIONS on an undefined host, which dotcl does not
           signal yet, so the whole branch is skipped. It is in the patch because the
           day dotcl signals there, cl-fad would stop loading without it.")

  (:lib "float-features"
   :upstream "shinmera/float-features"
   :upstream-host :codeberg
   :disposition :upstream-merged
   :ref :upstream-default
   :pr "shinmera/float-features#40"
   :retire-when "a quicklisp dist ships a float-features that includes PR 40"
   :notes "PR 40 merged 2026-08-13: reader conditionals in float-features.lisp and
           infinity.lisp, plus one .asd line, and no new source file.

           The primitives are not in the library. They are dotcl-float, a contrib
           shipped inside dotcl releases since 0.1.23, which reaches
           System.BitConverter through dotnet:static; the .asd pulls it in with
           (:feature :dotcl (:require :dotcl-float)). So nothing here needs a fork,
           and nothing dotcl-side needs carrying.

           WITH-FLOAT-TRAPS-MASKED lands in the portable no-op branch. Masking is
           the right answer on .NET, which does not trap, but the three tests that
           want an unmasked trap to be observable fail: 31 pass, 3 fail.
           WITH-ROUNDING-MODE still signals \"Implementation not supported\" -
           managed .NET exposes no rounding mode to bind.

           This is the first entry whose upstream is not on GitHub, which is what
           :upstream-host :codeberg is for. Loading it on dotcl also wants the
           trivial-features this dist carries, until that entry retires.")

  (:lib "usocket"
   :upstream "usocket/usocket"
   :disposition :upstream-pr-open
   :ref ("dotcl/usocket" :branch "dotcl")
   :pr "usocket/usocket#144"
   :retire-when "PR 144 merges and a quicklisp dist ships the merged version"
   :notes "A backend on System.Net.Sockets: TCP client and server, UDP, name
           lookup, and WAIT-FOR-INPUT over Socket.Select. Stock usocket loads on
           dotcl and does nothing, since the portable layer is all it has and
           every socket-*-internal is left undefined, so the failure is a
           run-time UNDEFINED-FUNCTION rather than a load error.

           Errors are mapped from SocketException's SocketErrorCode, whose
           numbers are the Winsock ones on every platform, and never from the
           message text, which .NET localises. A failure does not always arrive
           as a SocketException -- NetworkStream wraps it in an IOException, a
           connect that failed while its task was awaited in an
           AggregateException -- so the InnerException chain is walked.

           PR 144 filed 2026-08-19: one new file, four #+dotcl clauses in
           option.lisp and one .asd entry, with no existing backend touched.
           Upstream has been quiet since 2026-05.")))
