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

  (:lib "babel"
   :upstream "cl-babel/babel"
   :disposition :upstream-pr-open
   :ref ("snmsts/babel" :branch "utf-16-host-surrogate-support")
   :pr "cl-babel/babel#67"
   :retire-when "PR 67 merges and a quicklisp dist ships the merged version"
   :notes "Encodes astral-plane characters as surrogate pairs on UTF-16 hosts. Not
           dotcl-specific: the same bug is visible on any UTF-16 host.")

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

           Two more commits for dotcl. Memory access, size and alignment of :long
           and :unsigned-long now use the same per-OS width the call path already
           used (4 bytes on Windows, 8 elsewhere); before, they were 4 bytes on
           every OS, so on Linux and macOS a struct with a long or size_t field
           was allocated too small (cl-yaml crashed inside libyaml). And a libffi
           call whose argument slot would hold a value instead of its address
           (a :bool passed by value) now signals LIBFFI-ERROR instead of ending
           the process. With dotcl 0.1.32 the cffi test suite now runs to the
           end on macOS and on Windows ARM64 and x64; no test fails that passed
           before.

           Two more commits. MAKE-SHAREABLE-BYTE-VECTOR returns a pinned vector
           and WITH-POINTER-TO-VECTOR-DATA hands out its own address, so foreign
           writes show in the vector inside the body and the address stays valid
           after it; other vectors are still copied in and written back. Pinned
           vectors are told apart with DOTCL:PINNED-VECTOR-P, which needs dotcl
           0.1.33 or later. With dotcl 0.1.33 on macOS a foreign memset through
           WITH-POINTER-TO-VECTOR-DATA fills both a shareable and a plain vector.

           One more commit. LOAD-FOREIGN-LIBRARY closes a library before it loads
           it again and the new mapping can land at another address, but the
           cache of function addresses kept the old one, so the next
           FOREIGN-FUNCALL jumped into unmapped memory (a SIGSEGV seen with iolib).
           The cache is now forgotten when a library is loaded or closed.

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
           a lock with a :timeout goes through DOTCL:ACQUIRE-LOCK, which takes
           the timeout in seconds as its third argument; as on SBCL the timeout
           applies only when waiting, and WITH-LOCK-HELD skips its body and
           returns NIL when it expires. Both upstream test suites pass.
           Upstream PR not filed yet.")

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
   :disposition :upstream-pr-open
   :ref ("dotcl/cl-plus-ssl" :branch "dotcl")
   :pr "cl-plus-ssl/cl-plus-ssl#199"
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
           HttpClient does TLS and content decoding itself, which is why the
           backend is one file rather than a socket stack, and why it is selected
           on every OS rather than only on Windows the way winhttp is.

           Redirects are not left to HttpClient: REQUEST follows them, as it does
           for the usocket backend. :max-redirects counts hops, 301/302/303 turn a
           non-GET/HEAD request into a GET without a body, and a redirect to another
           server drops the Authorization, Proxy-Authorization and Cookie headers.
           :proxy is honoured: an http proxy for http URLs and, through CONNECT,
           https URLs, with user:password in the proxy URI sent as Basic proxy
           credentials, and socks5 without authentication. Checked against a real
           forward proxy (tinyproxy) and an ssh -D SOCKS5 listener, redirect hops
           included; not checked: https:// proxy URLs, socks5 with a user name and
           password, environment proxy variables. Set-Cookie lines stay separate
           for the cookie jar, :want-stream returns a decoding stream, and the
           retry and ignore restarts are established around each exchange, errors
           raised by .NET included. Multipart content works.

           :use-connection-pool and :keep-alive map onto a cached HttpClient keyed by
           insecure and max-redirects, so .NET's own per-origin pool reuses TCP and
           TLS across requests. A per-request timeout needs a CancellationTokenSource
           because HttpClient.Timeout is per client, not per request.

           With dotcl 0.1.35 the library's own tests run 126 passed, 0 failed
           (SBCL 173 of 173; the 47 that do not run on dotcl call the usocket
           backend directly). Checked against the winhttp backend on SBCL: status,
           content type and body, a 404 signalling with its status, redirect
           following, and pooling on and off all agree.")

  (:lib "trivial-arguments"
   :upstream "shinmera/trivial-arguments"
   :upstream-host :codeberg
   :disposition :upstream-merged
   :ref :upstream-default
   :pr "shinmera/trivial-arguments#14"
   :retire-when "a quicklisp dist ships a trivial-arguments that includes pull request 14 and dotcl pulls stock"
   :notes "Merged upstream as fee967a (pull request 14). Reader conditionals only,
           in arguments.lisp: a #+dotcl arm that asks DOTCL:FUNCTION-LAMBDA-LIST, and
           dotcl added to the two feature lists, so the library stops falling back to
           FUNCTION-LAMBDA-EXPRESSION with a notice. The stock library loads on dotcl
           but cannot answer for a compiled function.")

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
   :notes "A dotcl backend that does what the SBCL backend does with
           sb-bsd-sockets: it calls dotcl's dotcl-bsd-sockets module and maps
           that module's conditions onto usocket's. Name resolution, address
           families, the error table, connect timeouts, UDP and select all live
           in the module, which also takes IP literals such as \"0.0.0.0\" and
           \"::\" without asking the resolver. option.lisp gets the
           reuse-address, broadcast, tcp-nodelay and tcp-keepalive options for
           dotcl through the module's sockopt accessors. Needs dotcl 0.1.34 or
           later, which is the first release that ships dotcl-bsd-sockets.
           Stock usocket loads on dotcl and does nothing, since the portable
           layer is all it has and every socket-*-internal is left undefined,
           so the failure is a run-time UNDEFINED-FUNCTION rather than a load
           error.

           PR 144 filed 2026-08-19 and brought up to date with the branch on
           2026-10-24: one new file, four #+dotcl clauses in option.lisp and one
           .asd entry, with no existing backend touched. Upstream has been quiet
           since 2026-05.")

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
           PR 717 filed 2026-09-01.")

  (:lib "trivial-package-local-nicknames"
   :upstream "phoe/trivial-package-local-nicknames"
   :disposition :fork-only
   :ref ("dotcl/trivial-package-local-nicknames" :branch "dotcl")
   :pr nil
   :retire-when "an upstream pull request merges and a quicklisp dist ships the merged version"
   :notes "dotcl exports the package-local nickname API from the DOTCL package;
           the patch imports it from there, as the other implementations do from
           theirs, and adds dotcl test data. One commit on the commit the stock
           dist ships (8a4d09c). The library, lichat-protocol and
           lichat-serverlib go from failing to loading. Its own tests run 17 and
           pass 17 on dotcl 0.1.32 (an earlier dotcl failed 10, gaps in its
           nickname handling that are since fixed). SBCL 2.6.8 still loads the
           branch and passes 18 of 18.")

  (:lib "fset"
   :upstream "slburson/fset"
   :disposition :fork-only
   :ref ("dotcl/fset" :branch "dotcl")
   :pr nil
   :retire-when "an upstream pull request merges and a quicklisp dist ships the merged version"
   :notes "A #+dotcl block in Code/port.lisp, in the shape of the other SMP
           implementations: MAKE-LOCK and WITH-LOCK on dotcl's native locks, and
           the memory barriers built from a lock. Without it WITH-LOCK is
           undefined and (with-lock (+Tuple-Key-Lock+) ...) compiles as a call.
           One commit on cead3fc, the commit the stock fset-v2.2.0 release was
           cut from. The FSet test suite passes on dotcl; SBCL 2.6.8 still loads
           the branch and passes. coalton gets past fset and stops next in its
           own code (hashing is #-(or sbcl allegro ccl)).")

  (:lib "moptilities"
   :upstream "hraban/moptilities"
   :disposition :fork-only
   :ref ("dotcl/moptilities" :branch "dotcl")
   :pr nil
   :retire-when "an upstream pull request merges and a quicklisp dist ships the merged version"
   :notes "SLOT-NAMES on a structure name takes the FIND-CLASS path on dotcl as it
           does on SBCL, instead of calling the unimplemented GET-STRUCTURE, and
           FUNCTION-ARGLIST uses DOTCL:FUNCTION-LAMBDA-LIST. One commit on
           upstream master (a436f16). The test suite runs 37 with 3 failures on
           dotcl, all FUNCTION-ARGLIST; SBCL 2.6.8 runs 37 with 7 failures
           before and after the patch. reblocks gets past moptilities and stops
           next on a dotcl readtable bug.")

  (:lib "series"
   :upstream "series"
   :upstream-host :sourceforge
   :disposition :fork-only
   :ref ("dotcl/series" :branch "dotcl")
   :pr nil
   :retire-when "the patch merges upstream and a quicklisp dist ships the merged version"
   :notes "Upstream is git://git.code.sf.net/p/series/series, which has no pull
           requests; the change would go to the maintainers as a patch. dotcl
           joins the features that push :SERIES-ANSI, imports COMPILER-LET from
           DOTCL-CLTL2 and gets the GENERATOR deftype, the same three lines SBCL
           has. One commit on upstream master (da9061b). series goes from
           failing to loading. Its tests pass 567 of 567 on dotcl 0.1.32
           (the test file prompts for a scratch file name unless TEST-FILE is
           set first). SBCL 2.6.8 passes 566 of 567 with the patch, the other
           one being a package lock in the test file.")

  (:lib "cl-environments"
   :upstream "alex-gutev/cl-environments"
   :disposition :fork-only
   :ref ("dotcl/cl-environments" :branch "dotcl")
   :pr nil
   :retire-when "an upstream pull request merges and a quicklisp dist ships the merged version"
   :notes "SPECIALP asks dotcl's compiler whether a variable is globally special
           instead of compiling a small lambda per variable. The answer is the
           one the compiler uses when it compiles a binding of the variable,
           including variables declared special earlier in the file being
           compiled. Walking generic-cl calls SPECIALP some 60,000 times, and
           each COMPILE costs about half a millisecond on dotcl. One commit on
           upstream master (f9ef641), the commit the stock dist ships.")

  (:lib "metatilities"
   :upstream "hraban/metatilities"
   :disposition :fork-only
   :ref ("dotcl/metatilities" :branch "dotcl")
   :pr nil
   :retire-when "an upstream pull request merges and a quicklisp dist ships the merged version"
   :notes "Adds a dotcl port, dev/dotcl/, and selects it in the .asd the way the
           other implementations' ports are selected. Without it dotcl gets
           dev/unsupported/, whose generic-lisp warns at compile time, and with
           ASDF's compile-file failure behaviour set to :error (as SBCL has it)
           metatilities and everything that loads it stop. The port defines what
           the OpenMCL port defines: quit, bytes allocated, GC time (the .NET GC's
           total pause duration), collecting garbage (DOTCL:GC), the terminal
           beep, and the terminal questions for choosing a file, a new file, a
           directory and an item. With dotcl 0.1.32, metatilities, reblocks and
           reblocks-parenscript load with failures as errors, and metatilities'
           tests pass (lift, 6 tests). The upstream repository last changed in
           2017; Quicklisp names it gwkkwg/metatilities, which GitHub forwards to
           hraban/metatilities.")

  (:lib "static-vectors"
   :upstream "sionescu/static-vectors"
   :disposition :fork-only
   :ref ("dotcl/static-vectors" :branch "dotcl")
   :pr nil
   :retire-when "an upstream pull request merges and a quicklisp dist ships the merged version"
   :notes "Adds src/impl-dotcl.lisp and one :if-feature line in the .asd, the way
           every other backend is wired; no existing backend is touched. A static
           vector on dotcl is an ordinary specialized vector whose .NET backing
           array is pinned (DOTCL:MAKE-PINNED-VECTOR), so AREF works on the Lisp
           side and DOTCL:PINNED-VECTOR-ADDRESS is a pointer that stays valid until
           FREE-STATIC-VECTOR (DOTCL:UNPIN-VECTOR). Elements are stored at the width
           C expects, (unsigned-byte 32) and (signed-byte 8/16) included; element
           types without a fixed-width layout are refused. :ALIGNMENT is refused,
           as on every implementation other than SBCL on Unix.

           Needs a dotcl that exports MAKE-PINNED-VECTOR; on an older dotcl the
           reader stops at load on the unexported symbol, before anything runs. The
           static-vectors test suite passes 30 of 30 checks on dotcl 0.1.32.")

  (:lib "millet"
   :upstream "hyotang666/millet"
   :disposition :fork-only
   :ref ("dotcl/millet" :branch "dotcl")
   :pr nil
   :retire-when "an upstream pull request merges and a quicklisp dist ships the merged version"
   :notes "Adds src/dotcl.lisp and one :if-feature line in millet.asd, the way
           every other implementation is wired: GLOBAL-SYMBOL-P on
           DOTCL-CLTL2:VARIABLE-INFORMATION, LAMBDA-LIST on
           DOTCL:FUNCTION-LAMBDA-LIST and TYPE-EXPAND on DOTCL:TYPEXPAND; the rest
           keeps the defaults in default.lisp. One commit on upstream master
           (b20a41c), the commit the stock dist ships. jingoh goes from failing
           (TYPE-EXPAND not implemented) to loading. millet's own spec runs to the
           end on dotcl 0.1.32: 65 checks, 3 fail, all in LAMBDA-LIST, where
           DOTCL:FUNCTION-LAMBDA-LIST returns NIL for an anonymous lambda. That is
           fixed in dotcl itself, so the spec passes 65 of 65 from the next dotcl
           release.")

  (:lib "cl-store"
   :upstream "skypher/cl-store"
   :disposition :fork-only
   :ref ("dotcl/cl-store" :branch "dotcl")
   :pr nil
   :retire-when "an upstream pull request merges and a quicklisp dist ships the merged version"
   :notes "A dotcl backend: dotcl is added to the implementation lists in
           cl-store.asd, package.lisp (the MOP symbols come from DOTCL-MOP, the
           same fifteen SBCL imports) and utils.lisp (structure slots), and
           dotcl/custom.lisp stores special floats and structures. One commit on
           upstream master (adb52a1), the tree the 2023-02-14 quicklisp release
           was cut from. Without it the system refuses to load. The test suite
           passes 115 of 115 on dotcl 0.1.32.")

  (:lib "ironclad"
   :upstream "sharplispers/ironclad"
   :disposition :fork-only
   :ref ("dotcl/ironclad" :branch "dotcl")
   :pr nil
   :retire-when "an upstream pull request merges and a quicklisp dist ships the merged version"
   :notes "Not needed to load: stock ironclad runs on dotcl. The patch turns on
           :ironclad-fast-mod32-arithmetic and :ironclad-fast-mod64-arithmetic
           for dotcl in IRONCLAD-IMPLEMENTATION-FEATURES, which selects the
           modular-arithmetic macros that fold the mask into the operation.
           Four lines on the commit the stock v0.61 release was cut from
           (d4fe172); it also applies to upstream master. The test suite passes
           468 of 468 on dotcl either way, and the whole run is about a third
           shorter with the patch (106 s to 72 s measured once on one machine;
           SCRYPTKDF3 is the test that moves).")

  (:lib "external-program"
   :upstream "sellout/external-program"
   :disposition :fork-only
   :ref ("dotcl/external-program" :branch "dotcl")
   :pr nil
   :retire-when "an upstream pull request merges and a quicklisp dist ships the merged version"
   :notes "src/dotcl.lisp implements START, RUN, the PROCESS-* accessors and
           SIGNAL-PROCESS on dotcl's own process functions (DOTCL:LAUNCH-PROCESS and
           friends), going through /usr/bin/env on Unix as the SBCL backend does,
           with a structure wrapped around the process because dotcl process
           objects have no Lisp type. Not supported: signals other than 9 and 15,
           :ERROR :OUTPUT, a Lisp stream other than a file for :INPUT/:OUTPUT,
           status hooks. The .asd and the two default methods list dotcl. One
           commit on upstream master (8a10db2), the commit the stock dist ships.
           The fiveam suite passes 31 of 31 on dotcl 0.1.32 on macOS. On Windows
           ARM64 three checks fail, the same three that fail on SBCL there: passing
           an environment and changing the directory.")

  (:lib "hunchentoot"
   :upstream "edicl/hunchentoot"
   :disposition :fork-only
   :ref ("dotcl/hunchentoot" :branch "dotcl")
   :pr nil
   :retire-when "an upstream pull request merges and a quicklisp dist ships the merged version"
   :notes "SET-TIMEOUTS gets a dotcl arm that sets ReceiveTimeout and SendTimeout
           on the Socket under usocket's TcpClient. Without it the listener thread
           dies on the first connection with OPERATION-NOT-IMPLEMENTED. The catch-all
           arm is unchanged apart from listing dotcl, so every other
           implementation behaves as before. One commit on upstream master (65a3a3c,
           newer than the v1.3.1 release the stock dist ships); set-timeouts.lisp is
           the same file in v1.3.1. An easy-acceptor serves a GET (200) and a missing
           page (404) on dotcl 0.1.32; the library's own test directory was not run.
           File uploads need the rfc2388 entry of this dist to keep binary bytes.

           The dotcl arm now sets the timeouts through dotcl-bsd-sockets' sockopt
           accessors, as the ECL arm does with sb-bsd-sockets, because the usocket
           entry of this dist hands out dotcl-bsd-sockets socket objects (dotcl
           0.1.34 or later). The two entries go together.")

  (:lib "clsql"
   :upstream "clsql"
   :upstream-host :kpe-git
   :disposition :fork-only
   :ref ("dotcl/clsql" :branch "dotcl")
   :pr nil
   :retire-when "the patch merges upstream and a quicklisp dist ships the merged version"
   :notes "Upstream is http://git.kpe.io/clsql.git, which has no pull requests; the
           change would go to the maintainers as a patch, and the dotcl repository is
           an ordinary repository, not a GitHub fork. dotcl joins the implementations
           that use the MOP from DOTCL-MOP, SBCL's finalize-inheritance key-slot
           method, WITHOUT-INTERRUPTS as a plain progn and weak hash tables by
           :WEAKNESS :VALUE. Like ECL and ABCL it has no LOOP-based path for
           RECORD/TUPLE iteration. One commit on upstream master (2c2a20b). Loading
           needs the cffi entry of this dist (its uffi-compat GETENV), since
           clsql.asd asks for UFFI. sqlite3 needs :CLSQL-CFFI on *FEATURES*; with it
           clsql-uffi and clsql-sqlite3 load and an in-memory sqlite3 database
           creates, inserts and selects on dotcl 0.1.32. The clsql-tests suite needs
           database servers and was not run.")

  (:lib "rfc2388"
   :upstream "jdz/rfc2388"
   :disposition :fork-only
   :ref ("dotcl/rfc2388" :branch "dotcl")
   :pr nil
   :retire-when "an upstream pull request merges and a quicklisp dist ships the merged version"
   :notes "Lists dotcl among the implementations that open the file an uploaded
           part is saved to with an explicit external format, and gives it
           '(:latin-1 :newline :lf). Without it the file is opened in dotcl's
           default text format and an uploaded binary does not come back byte
           for byte through hunchentoot: bytes above 127 are encoded as UTF-8 and
           line endings follow the platform. Two commits on upstream master
           (591bcf7). With dotcl 0.1.33 on macOS a 1284-byte upload holding every
           byte value comes back identical through hunchentoot; with the stock
           rfc2388 it comes back as 1924 bytes.")

  (:lib "chipz"
   :upstream "sharplispers/chipz"
   :disposition :upstream-pr-open
   :ref ("dotcl/chipz" :branch "dotcl")
   :pr "sharplispers/chipz#14"
   :retire-when "PR 14 merges and a quicklisp dist ships the merged version"
   :notes "Builds the streaming decompressor on dotcl's Gray streams (DOTCL-GRAY)
           instead of stream-fallback.lisp: the .asd pushes the gray-streams
           feature on dotcl, stream.lisp has dotcl arms for the three class and
           generic function variables and joins the SBCL and CMUCL form of
           STREAM-READ-SEQUENCE, and the tests run external programs through
           uiop:run-program. One commit on upstream master (4ce0bc5).")

  (:lib "trivial-octet-streams"
   :upstream "sharplispers/trivial-octet-streams"
   :disposition :upstream-merged
   :ref :upstream-default
   :pr "sharplispers/trivial-octet-streams#3"
   :retire-when "a quicklisp dist ships a trivial-octet-streams that includes PR 3"
   :notes "dotcl arms for the Gray stream classes and generic functions, from
           DOTCL-GRAY. Without them the library signals \"octet streams not
           supported in this implementation\" while loading. PR 3 merged
           2026-10-12 as one commit.")

  (:lib "yason"
   :upstream "phmarek/yason"
   :disposition :upstream-merged
   :ref :upstream-default
   :pr "phmarek/yason#89"
   :retire-when "a quicklisp dist ships a yason that includes PR 89"
   :notes "dotcl strings hold UTF-16 code units, as CMUCL's do, so dotcl takes
           CMUCL's side: a \\u escape outside the BMP is parsed into its two
           surrogate characters, and one ESCAPE-STRING-TO-STREAM, shared by CMUCL
           and dotcl, pairs the surrogates up again on output. That function
           consults the replacement table first, as the other implementations
           do, so on CMUCL a newline is now written as \\n rather than \\u000A.
           PR 89 merged 2026-10-17 as one commit.")

  (:lib "xmls"
   :upstream "rpgoldman/xmls"
   :disposition :upstream-merged
   :ref :upstream-default
   :pr "rpgoldman/xmls#20"
   :retire-when "a quicklisp dist ships an xmls that includes PR 20"
   :notes "The library itself loads on dotcl unchanged; only the test op is
           gated by implementation. dotcl is added to that list, and the test
           reads its command-line arguments with dotcl:command-line-arguments.
           PR 20 merged 2026-10-15 into master, two commits.")

  (:lib "graph"
   :upstream "eschulte/graph"
   :disposition :fork-only
   :ref ("dotcl/graph" :branch "dotcl")
   :pr nil
   :retire-when "the change reaches upstream and a quicklisp dist ships it"
   :notes "dotcl's MAKE-HASH-TABLE takes :HASH-FUNCTION with any two-argument
           test, so the edge hash tables and COPY-HASH take the CCL and LispWorks
           branch. Without it they signal \"unsupport lisp distribution\". One
           commit on upstream master (451d0a2). No pull request: the open PR 12
           touches the same lines for Allegro and would conflict, and nothing has
           been merged upstream since 2022.")

  (:lib "introspect-environment"
   :upstream "Bike/introspect-environment"
   :disposition :fork-only
   :ref ("dotcl/introspect-environment" :branch "dotcl")
   :pr nil
   :retire-when "the change reaches upstream and a quicklisp dist ships it"
   :notes "Imports DOTCL:TYPEXPAND and DOTCL:TYPEXPAND-1, which have SB-EXT's
           contract, as SBCL and Clasp import theirs, and keeps the unsupported
           stubs in default.lisp from replacing them. One commit on upstream
           master (69a50ac). No pull request: the open PRs 9 and 10 (ECL,
           CL-Amiga) change the same line of default.lisp and would conflict.")

  (:lib "plexippus-xpath"
   :upstream "sharplispers/xpath"
   :disposition :fork-only
   :ref ("dotcl/xpath" :branch "dotcl")
   :pr nil
   :retire-when "an upstream pull request merges and a quicklisp dist ships the merged version"
   :notes "dotcl's double floats do not trap, so dotcl takes xnum-ieee.lisp as
           SBCL does, with dotcl arms for what it needs from the implementation:
           no traps to mask, NaN and infinity tests from System.Double, plain
           division, LONG-TO-DOUBLE from the dotcl-float module, and FMOD
           computed exactly on rationals. The IEEE tests read their infinities
           from two variables set per implementation. One commit on upstream
           master (d364da6). Pull request not filed yet: the patch is larger than
           the others and leans on dotcl's own modules.")

  (:lib "exit-hooks"
   :upstream "ailisp/exit-hooks"
   :disposition :fork-only
   :ref ("dotcl/exit-hooks" :branch "dotcl")
   :pr nil
   :retire-when "the change reaches upstream and a quicklisp dist ships it"
   :notes "Without a dotcl arm the library signals an error while loading. The
           hooks are kept in a list that a System.AppDomain ProcessExit handler
           runs. One commit on upstream master (78050f4). No pull request:
           upstream has had no activity since 2017 and an open PR from 2021 has
           no answer.")

  (:lib "clack-handler-kestrel"
   :upstream "dotcl/clack-handler-kestrel"
   :disposition :fork-only
   :ref ("dotcl/clack-handler-kestrel" :branch "main")
   :pr nil
   :retire-when "quicklisp carries clack-handler-kestrel"
   :notes "Not a fork: a Clack handler written for dotcl, serving on ASP.NET
           Core's Kestrel, that is not in quicklisp. It is carried here so that
           (ql:quickload '(\"clack\" \"clack-handler-kestrel\")) works. It runs
           only on dotcl and needs the ASP.NET Core shared framework. With dotcl
           0.1.33 on macOS, clackup with :server :kestrel answers a GET, echoes a
           binary POST byte for byte, and stops.")

  (:lib "shasht"
   :upstream "yitzchak/shasht"
   :disposition :fork-only
   :ref ("dotcl/shasht" :branch "dotcl")
   :pr nil
   :retire-when "an upstream pull request merges and a quicklisp dist ships the merged version"
   :notes "On a host whose characters are 16-bit code units, a \\u escaped
           surrogate pair has to stay two characters. Upstream does that for
           CMUCL only, with a #+cmucl arm; everywhere else it combines the pair
           into one code point, which dotcl and ABCL cannot hold as a character.
           The branch decides from CHAR-CODE-LIMIT instead and keeps the CMUCL
           arm. With dotcl 0.1.35 the library's test suite passes 391 of 391 tests
           (stock: 385 passed, 6 failed, all of them reading a surrogate pair).
           One commit on upstream master (fb9706e).")

  (:lib "zacl"
   :upstream "genworks/zacl"
   :disposition :upstream-merged
   :ref :upstream-default
   :pr "genworks/zacl#1"
   :retire-when "a quicklisp dist ships a zacl that includes PR 1"
   :notes "PR 1 merged 2026-10-25 on the home repository (gitlab.common-lisp.net
           dcooper/zacl) and mirrored to GitHub. Adds dotcl-specific.lisp, the
           compatibility layer's dotcl arm, in the same shape as the EGCL port;
           the other files are untouched. This entry follows the mirror's
           default branch because the merge is there and the stock distribution
           does not have it yet. Pair with the aserve entry. With dotcl 0.1.35
           zacl-tests runs 21 checks and 19 pass; the two that do not are
           PREPEND-STREAM and a call to (SETF URI-SCHEME), which is undefined.")

  (:lib "aserve"
   :upstream "genworks/zaserve"
   :disposition :upstream-merged
   :ref :upstream-default
   :pr "genworks/zaserve#1"
   :retire-when "a quicklisp dist ships an aserve that includes PR 1"
   :notes "The Quicklisp project is called aserve and its system is zaserve. PR 1
           merged 2026-10-25 on the home repository (gitlab.common-lisp.net
           dcooper/zaserve) and mirrored to GitHub: the platform check accepts
           dotcl and the hash tables it makes are synchronized. Runs on the zacl
           entry of this dist. With dotcl 0.1.35 a server publishing a page, an
           echo of GET and POST data, a missing path (404), a plain file, a
           43 KB file that comes back byte for byte, a directory, an HTTP/1.0
           client and twenty repeated requests answers correctly under curl.
           The system zacl-aserve is a shim for the older portableaserve and
           still does not load, as before. This entry follows the mirror's default branch
           because the merge is there and the stock distribution does not have
           it yet.")))
