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
 :inventory-ignore ("dotcl" "playa" "paalam" "playground" "dist")
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
   :retire-when "a quicklisp dist ships a tgs that includes the file-position bridge (PR 18) and dotcl pulls stock"
   :notes "Two upstream changes, both merged. PR 17 adds :dotcl to the gray-streams backend selection (2026-07-13). PR 18 bridges dotcl-gray:stream-file-position to tgs's own generic function (2026-07-24); :pr names it because it is the binding one — dotcl no longer special-cases the tgs package in FILE-POSITION, so a tgs without PR 18 reports NIL there.")

  (:lib "flexi-streams"
   :upstream "edicl/flexi-streams"
   :disposition :fork-only
   :ref ("dotcl/flexi-streams" :branch "dotcl")
   :pr nil
   :retire-when "an upstream pull request merges and a quicklisp dist ships the merged version"
   :notes "Reads an astral code point as a surrogate pair and writes a pair back as
           the code point, on a host whose CHAR-CODE-LIMIT is #x10000. Not
           dotcl-specific: measured on ABCL 1.9.3, where CODE-CHAR truncates and
           U+242EE was read as U+42EE. cl-unicode cannot build its tables without
           it - the generator reads NormalizationTest.txt through flexi and the
           line carrying U+242EE broke. Quicklisp takes flexi-streams from
           edicl/flexi-streams git HEAD (quicklisp-projects calls that source
           ediware-http, which despite the name is a git-source templated on
           https://github.com/edicl/~A.git), so a merge reaches the next dist
           directly.")

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
   :submission (:url "https://gitlab.common-lisp.net/asdf/asdf/-/merge_requests/252"
                :state :open
                :verifiable nil
                :checked "2026-08-20")
   :retire-when "the upstream merge request lands and dotcl stops vendoring asdf"
   :notes "Shipped inside dotcl releases as a precompiled fasl, so the branch here is
           what a source build clones. dotcl-0.1.21 is the current compatibility
           generation, updated in place; a new dotcl-X.Y.Z branch is cut only on the
           next hard incompatibility, and older branches stay frozen for older
           releases. The upstream project lives on GitLab behind a bot challenge this
           checker cannot read, so the merge request is recorded in :submission
           rather than :pr. It carries the uiop OS-abstraction subset --
           getenv/quit/argv, run-program, raw-command-line-arguments,
           package-local-nicknames, getcwd, *unspecific-pathname-type* -- and the
           branch shipped here has grown past it since, so that merge landing would
           not on its own retire this entry.")

  (:lib "cffi"
   :upstream "cffi/cffi"
   :disposition :fork-only
   :ref ("dotcl/cffi" :branch "dotcl")
   :pr nil
   :retire-when "an upstream PR merges and reaches the stock distribution"
   :notes "CFFI-SYS backend for dotcl. OS-independent: the platform and the C long
           size are resolved at run time rather than at read time, so one source
           works on Windows (LLP64) and Unix (LP64).

           %LOAD-FOREIGN-LIBRARY signals a SIMPLE-ERROR when a library fails to
           load. That is a contract of libraries.lisp rather than of any backend:
           LOAD-FOREIGN-LIBRARY-PATH retries against *FOREIGN-LIBRARY-DIRECTORIES*
           only for that condition, and dotcl surfaces a missing DLL as a CLR
           PROGRAM-ERROR, so the search never ran and a library named without a
           directory loaded only when the OS happened to find it. The upstream
           source carries a FIXME saying it never checked that every host signals
           the right condition. With the clause the test suite goes from 136
           failures of 308 to 9; the nine that remain are pointer representation
           and :void questions, not loading. Measured on dotcl 0.1.27, ARM64
           Windows, with the fsbv, grovel and test-asdf files left out.

           Upstream PR not filed yet.")

  (:lib "trivial-cltl2"
   :upstream "Zulu-Inuoe/trivial-cltl2"
   :disposition :fork-only
   :ref ("dotcl/trivial-cltl2" :branch "dotcl")
   :pr nil
   :retire-when "an upstream PR merges and reaches the stock distribution"
   :notes "One line: DOTCL-CLTL2 joins the :use list of the trivial-cltl2 package,
           next to the other implementations' CLtL2 packages. Without it the
           eight names are exported but undefined on dotcl, so DEFINE-DECLARATION
           compiles as a plain call and trivia fails to load with an unbound
           variable. dotcl's backend answers every introspection call with
           \"no information\"; callers that ask for optimization hints get NIL
           and emit correct, unoptimized code. Measured 2026-09-15: trivia and
           the 21 systems that load it through serapeum go from failing to
           loading with this entry alone.")

  (:lib "trivial-features"
   :upstream "trivial-features/trivial-features"
   :disposition :upstream-merged
   :ref :upstream-default
   :pr "trivial-features/trivial-features#25"
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
   :disposition :upstream-merged
   :ref :upstream-default
   :pr "trivial-garbage/trivial-garbage#26"
   :retire-when "a quicklisp dist ships a trivial-garbage that includes PR 26"
   :notes "Weak pointers, weak hash-tables and finalizers on dotcl's own
           facilities: System.WeakReference, MAKE-HASH-TABLE :weakness for all
           four weakness kinds, and real GC finalizers. Without this the stock
           .asd refuses to load at all, because its supported-implementation
           guard signals an error on an unknown host. Upstream test suite
           passes, 11 of 11.

           PR 26 merged 2026-08-22: reader conditionals only, no new file, in
           the shape of the Mezzano and Genera additions. The patch went in as
           filed but rebased -- CL-Amiga support merged a day earlier and both
           add a keyword to the same (or ...) lists -- so the fork branch was
           rebuilt on upstream, 2bb976d to baf04e7, and the source the dist ships
           now carries CL-Amiga as well. The merge commit 2f293dd is upstream's
           master head and its tree is identical to that fork branch.")

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

  (:lib "atomics"
   :upstream "shinmera/atomics"
   :upstream-host :codeberg
   :disposition :patched
   :ref (:upstream :commit "1caed1aced6c552923e87e37e6e9cfdc185c06b0")
   :patches ("patches/atomics/0001-Add-dotcl-atomic-op-backend.patch")
   :pr nil
   :retire-when "an upstream PR merges and reaches the stock distribution"
   :notes "Reader conditionals only, in one file, in the shape of the CL-Amiga
           addition that landed just before it: #+dotcl arms on CAS, ATOMIC-INCF
           and ATOMIC-DECF, and dotcl added to the six CAS-place features it
           supports. ATOMIC-PUSH and ATOMIC-POP already have a generic CAS-based
           fallback and need nothing.

           CAS compares with EQL rather than the EQ the other arms use, because
           dotcl boxes its numbers: an EQ test would make a CAS on a counter stop
           swapping once its value left the small-integer cache. The underlying
           DOTCL:COMPARE-AND-SWAP is lock-based (one global monitor) and so
           correct but not lock-free; a single 64-bit counter is better served by
           dotcl's own atomic-long.

           Without this atomics signals IMPLEMENTATION-NOT-SUPPORTED at load and
           sento cannot load at all. Upstream moved from GitHub to Codeberg in
           August 2025 and says patches go there, which is what
           :upstream-host :codeberg is for; the patch is made against Codeberg
           master at the pinned commit. Upstream PR not filed yet.")

  (:lib "metatilities-base"
   :upstream "hraban/metatilities-base"
   :disposition :fork-only
   :ref ("dotcl/metatilities-base" :branch "dotcl")
   :pr nil
   :retire-when "an upstream PR merges and reaches the stock distribution"
   :notes "Two reader-conditional keys, no new file. The WITHOUT-INTERRUPTS
           :IMPORT-FROM picks its package specifier by feature, and an
           implementation matching none of them is left importing nothing from a
           package named WITHOUT-INTERRUPTS: DEFPACKAGE fails before any of the
           library runs. dotcl joins CLISP on the side that defines the macro
           locally, which expands to PROGN.

           That trades atomicity for loading, exactly as it already does on
           CLISP. The use in this library is the priority queue's critical
           section. dotcl has no WITHOUT-INTERRUPTS to offer instead: its
           interrupts are delivered at safepoints, and a real one is a design
           question of its own rather than a line in a manifest.

           This entry is why five other systems load. cl-containers, cl-markdown
           and the rest reach the broken DEFPACKAGE through this dependency, not
           through any code of their own.")

  (:lib "cl+ssl"
   :upstream "cl-plus-ssl/cl-plus-ssl"
   :disposition :fork-only
   :ref ("dotcl/cl-plus-ssl" :branch "dotcl")
   :pr nil
   :retire-when "an upstream PR merges and reaches the stock distribution"
   :notes "One form in reload.lisp, and nothing in it is dotcl-specific. The
           Windows library-name list knew the OpenSSL 3 and 1.1 DLLs only under
           the -x64 suffix, guarded by #+x86-64, and the x86 names under #+x86,
           so on a 64-bit ARM host every modern name read away and only
           libeay32.dll (OpenSSL 1.0) was left. The suffix is a convention of one
           Windows distribution, not of OpenSSL: MSYS2 clangarm64, vcpkg and
           conda ship libcrypto-3.dll and libssl-3.dll unsuffixed. The patch
           replaces the x86-only arms with unconditional trailing candidates, so
           x86-64 keeps its order and x86 ends up with the list it had; a
           candidate of the wrong machine type costs nothing because :or wraps
           each attempt in ignore-errors.

           Measured 2026-09-18 on ARM64 Windows with the MSYS2 clangarm64
           OpenSSL: stock cl+ssl fails to load, this branch loads.")


  (:lib "mmap"
   :upstream "shinmera/mmap"
   :upstream-host :codeberg
   :disposition :patched
   :ref (:upstream :commit "d8d4fad5db120eb99559340a3a2cc74c53b9f09a")
   :patches ("patches/mmap/0001-Size-size_t-by-word-size-not-by-x86.patch")
   :pr nil
   :retire-when "an upstream PR merges and reaches the stock distribution"
   :notes "One form in windows.lisp, and nothing in it is dotcl-specific. The
           Windows size_t was sized by #+x86-64 / #+x86, so on a 64-bit ARM host
           both arms read away and CFFI is handed a type with no base type; the
           file does not compile on any Windows ARM64 implementation. posix.lisp
           in the same library already asks #+64-bit / #+32-bit, which is the
           question that was meant, so the patch is windows.lisp catching up to
           its sibling.

           On x64 Windows the stock library loads unchanged; this entry only
           matters on ARM64. Upstream moved from GitHub to Codeberg in August
           2025 and the line is unfixed there too, so the patch is made against
           Codeberg master at the pinned commit.")


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
                   Upstream has been quiet since 2026-05.")

  (:lib "slime"
   :upstream "slime/slime"
   :disposition :upstream-merged
   :ref :upstream-default
   :pr "slime/slime#941"
   :retire-when "a quicklisp dist ships a slime that includes PR 941"
   :notes "SLIME's swank on dotcl. swank/dotcl.lisp implements the backend
           interfaces on the contrib modules a dotcl release ships: dotcl-socket
           for sockets, dotcl-thread for threads and locks, dotcl-gray for Gray
           streams. The file requires those itself rather than declaring them in
           the system definition, because swank-loader compiles it directly, and
           swank/gray needs the Gray package to exist by the time it is compiled.

           Sixty interfaces, which is what SLIME needs to attach, evaluate,
           complete, inspect and report conditions. The rest fall back on the
           portable defaults, so an interface that is not here fails as an
           unsupported operation rather than as an error at load time. ARGLIST
           reads dotcl:FUNCTION-LAMBDA-LIST in the ECL backend's two-value
           shape, so a name whose lambda list was never recorded reports
           :not-available rather than being shown as taking no arguments; that
           symbol is external since dotcl 0.1.26. Built-ins, (setf foo) names
           and anonymous lambdas still fall back.

           One commit, touching no existing backend: the wiring is *sysdep-files*,
           *implementation-features* and lisp-version-string.

           PR 941 merged 2026-09-01, unchanged. Upstream master head 4a5b4fb is that
           commit and its tree is identical to the fork branch dist 2026-09-01 shipped,
           so the source does not change; only the tarball prefix does. The fork owns
           nothing now and retires with the merge; the entry stays until a stock
           distribution ships it.")

  (:lib "sly"
   :upstream "joaotavora/sly"
   :disposition :upstream-pr-open
   :ref ("dotcl/sly" :branch "dotcl")
   :pr "joaotavora/sly#717"
   :retire-when "PR 717 merges and a quicklisp dist ships the merged version"
   :notes "The same backend as the slime entry, against SLY's slynk:
           slynk/backend/dotcl.lisp on dotcl-socket, dotcl-thread and dotcl-gray,
           with slynk-loader's *sysdep-files* loading it ahead of slynk-gray. The
           two files are near identical because slynk is a fork of swank; they
           are separate entries because the two distributions ship separately and
           either upstream can move without the other.

           Sixty interfaces, ARGLIST included, on the same terms as the slime
           entry. One commit on upstream master, no existing backend touched.
           PR 717 filed 2026-09-01.")))
