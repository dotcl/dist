# dotcl dist

Where to get the sources of Common Lisp libraries that need dotcl-specific
support code, and why each one is still carried out of tree.

[`manifest.lisp`](manifest.lisp) is the single source of truth. It is data, not
code — one s-expression, read with `*read-eval*` bound to `NIL`.

**The goal state is an empty manifest.** An entry exists only while dotcl needs
a non-stock source for a library. Once the support code is merged upstream and
reaches the stock distribution, the entry is deleted. Git history is the record
of what used to be here; nothing is kept as a tombstone.

## Using it

Generate a [qlot](https://github.com/fukamachi/qlot) `qlfile` for the libraries
that still need a fork:

```sh
sbcl --script scripts/gen-qlfile.lisp > qlfile   # or: dotcl scripts/gen-qlfile.lisp
```

Entries whose support code is already merged upstream, or that ship inside a
dotcl release, produce no `qlfile` line — you want stock for those.

### As a quicklisp dist

The same manifest generates a real quicklisp dist, so a dotcl user gets the
patched versions from an ordinary `quickload` instead of arranging sources by
hand:

```sh
dotcl scripts/gen-dist.lisp        # version defaults to today's date
```

It writes the dist index under `docs/` — served by GitHub Pages, so the
subscription URL is `https://dotcl.github.io/dist/dotcl.txt` — and the release
tarballs under `build/`, which belong in the GitHub Release named
`dist-<version>`. Tarballs are never committed.

**Only upload the tarballs this version introduced.** A tarball is named after
the commit it came from and its bytes are reproducible, so a file that has been
uploaded once never needs a second home. Generation reads the `releases.txt` of
every version already under `docs/` and reuses the URL found there, so a version
that changes one library leaves the other entries pointing at the releases that
already hold them. `git status` after generating shows which files in `build/`
are new; those are the ones to attach.

The consequence is that a release can never be deleted, because later dist
versions point into it.

Tarballs are built with `git archive … | gzip -n` at a resolved commit, so the
same input always produces the same bytes. GitHub's own `/archive/` tarballs
are not stable over time and are deliberately not used.

Give the dist a higher preference than the stock one and its releases shadow
the stock versions system by system. When an entry retires, the release simply
stops appearing and the stock version becomes visible again.

## Schema

Each entry is a plist:

| key | meaning |
|---|---|
| `:lib` | library name, as the distribution knows it |
| `:upstream` | `owner/repo` of the upstream project |
| `:upstream-host` | `:github` (default) or `:gitlab` |
| `:disposition` | see below |
| `:ref` | where the dotcl support code lives *now* — `:upstream-default`, or `("owner/repo" :branch "name" \| :tag "name" \| :commit "sha")` |
| `:bundled` | `t` when dotcl ships the library itself, so it needs no dist release |
| `:pr` | upstream pull request, as `owner/repo#number`, or `nil` |
| `:fork-status` | tracks a fork that has outlived its purpose, e.g. `(:redundant "…")` |
| `:retire-when` | the condition under which this entry is deleted |
| `:notes` | prose: what the patch does, anything a reader would otherwise have to guess |

`:disposition` is one of:

- `:upstream-merged` — merged upstream; dotcl still needs a non-stock source
  only until the merge reaches the stock distribution
- `:upstream-pr-open` — pull request filed and pending
- `:bundled-in-release` — shipped inside a dotcl release rather than pulled
- `:fork-only` — public fork exists, no upstream pull request yet

`:bundled` is a separate axis from `:disposition`: it says dotcl ships the
library itself, which is independent of how the upstream conversation is going.
quicklisp-client is both `:upstream-pr-open` and `:bundled` — the pull request
is still open, and dotcl compiles that branch into the fasl it ships.

Prefer `:commit` in a `:ref`. A pinned commit makes a regenerated dist
byte-identical, keeps unrelated upstream churn out of it, and means the only
thing that can change a dist is a change to this file. `:branch` still works
when following a head is the point.

## Rules this repository runs on

**Listing criterion.** An entry appears once the support code has a public
home: an upstream pull request, a source shipped in a dotcl release, or at
minimum a public fork. Work that exists only on a contributor's disk is not
listed — there is nothing a tool or a reader could do with it.

**Promotion is one-way.** A library moves into the manifest when it meets the
criterion above. It does not move back out into a private todo list; it either
stays or retires.

**Retirement is deletion.** When `:retire-when` is satisfied, the entry is
removed in a commit that says why. The manifest never grows a "formerly
needed" section.

**Public identifiers only.** Everything in this repository — manifest, commit
messages, issues — refers to public pull requests, public repositories, and
public facts.

## Checks

`scripts/validate.lisp` verifies the manifest:

- schema: required keys present, `:disposition` from the known vocabulary,
  `:ref` shape consistent with the disposition
- with `gh` available: every `:pr` exists and its state agrees with
  `:disposition`; every `:ref` fork and branch exists and is public
- inventory drift: repositories under the `dotcl` organization that no entry
  mentions are reported, so a fork cannot quietly diverge from the manifest

```sh
sbcl --script scripts/validate.lisp          # schema only
LEDGER_CHECK_NETWORK=1 sbcl --script scripts/validate.lisp   # + gh checks
```

The workflow runs on every push and pull request, and weekly — the scheduled run
is what notices drift nobody triggered.
