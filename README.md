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

Entries whose support code is already merged upstream produce no `qlfile`
line — you want stock for those.

### As a quicklisp dist

The same manifest generates a real quicklisp dist, so a dotcl user gets the
patched versions from an ordinary `quickload` instead of arranging sources by
hand:

```sh
dotcl scripts/gen-dist.lisp        # version defaults to today's date
```

Reading the `.asd` files needs their `:defsystem-depends-on` targets visible to
asdf. Today that is only alexandria (cffi-libffi, cffi-tests and
trivial-features-tests ask for it), and the generator does not load quicklisp
because the quicklisp searcher shadows dist checkouts (sly's own systems
disappeared when it was loaded). Point `CL_SOURCE_REGISTRY` at an alexandria
checkout instead:

```sh
CL_SOURCE_REGISTRY=/path/to/alexandria/ dotcl scripts/gen-dist.lisp
```

The run is right when `systems.txt` differs from the previous version only by
the entries you changed; `diff <(sort docs/dotcl/<prev>/systems.txt) <(sort docs/dotcl/<new>/systems.txt)`
is the check.

It writes the dist index under `docs/` — served by GitHub Pages, so the
subscription URL is `https://dotcl.github.io/dist/dotcl.txt` — and the release
tarballs under `build/`, which belong in the GitHub Release named
`dist-<version>`. Tarballs are never committed.

**Only upload the tarballs this version introduced.** A tarball is named after
the commit it came from and its bytes are reproducible, so a file that has been
uploaded once never needs a second home. Generation reads the `releases.txt` of
every version already under `docs/` and reuses the URL found there, so a version
that changes one library leaves the other entries pointing at the releases that
already hold them. Generation ends by naming the files to attach:

```
;; 1 new tarball(s) to attach to release dist-2026-09-19
;; UPLOAD: build/flexi-streams-20260919-561a40d.tar.gz
```

Take that list, not `git status`: `build/` is gitignored, so status shows
nothing there. Reading it from status is how two tarballs went unattached in
2026-09-15, leaving two URLs in `releases.txt` answering 404.

Before uploading, check that the new tarballs load:

```sh
dotcl scripts/check-loadable.lisp
```

It loads the systems those tarballs define, on the dotcl running it, and exits
non-zero if any of them fails - the libraries are carried for dotcl, so one that
does not load on it is not ready to be published. Only the new ones are checked;
a tarball published earlier has been through this already.

The consequence is that a release can never be deleted, because later dist
versions point into it.

Tarballs are built with `git archive … | gzip -n` at a resolved commit, so the
same input always produces the same tar stream. The compressed bytes are not
the same everywhere: gzip implementations differ (Apple's and GNU's do), so a
rebuild on another machine can differ in size and digest from the uploaded
file. A tarball an earlier version published is therefore described by its
published asset, which generation downloads into `build/published/`, never by
the local rebuild. The client checks the size, and a wrong one stops
`update-dist` with `BADLY-SIZED-LOCAL-ARCHIVE` (2026-09-29 was first published
that way). GitHub's own `/archive/` tarballs are not stable over time and are
deliberately not used.

After uploading, run the network checks (see [Checks](#checks)): they download
every asset every `releases.txt` names and fail if one is missing or its size
or md5 differs from the line.

Give the dist a higher preference than the stock one and its releases shadow
the stock versions system by system. When an entry retires, the release simply
stops appearing and the stock version becomes visible again.

### Source ledger

[`source-ledger.lisp`](source-ledger.lisp) records, for every project in the
dist, the repository its release is imported from (the `:ref` fork, or upstream
itself), the numeric ids the host gave that repository and its owner, and the
commit imported last:

```lisp
(:lib "cl-fad" :host :github :source "edicl/cl-fad" :name "edicl/cl-fad" :repo-id 2293700 :owner-id 1013679 :commit "714257f064cbe326855701be1aa5ef1199f3c676")
```

A name can come to mean a different repository; the ids cannot. Before it
builds anything, `gen-dist` fetches every source and holds it against the
ledger. It stops, writes nothing, and names each project and the reason when:

- the repository id or the owner id is not the recorded one, or the host no
  longer knows the repository;
- the commit to import does not have the recorded commit in its history (a
  rewritten branch, or a pinned commit moved to unrelated history).

A rename keeps both ids, so it updates `:name` and the run continues. A project
with no ledger line is recorded on its first run, and so is one whose `:ref`
now names a different repository: that change is made in the manifest, where
it is reviewed. Ids come from `gh api` for GitHub and the anonymous Codeberg
API; a host with neither gets the history check only. A successful run rewrites
the ledger with the commits it imported, so commit it with the dist version.

To accept a change after looking at it, delete that project's line; the next
run records the source as it is now. When only the history changed, pinning
`:ref` to the recorded commit keeps the previous version in the meantime.

`scripts/seed-ledger.lisp` fills in missing lines without generating a dist,
from the commits the newest published version was built from. It only reads.

## Schema

Each entry is a plist:

| key | meaning |
|---|---|
| `:lib` | library name, as the distribution knows it |
| `:upstream` | `owner/repo` of the upstream project |
| `:upstream-host` | `:github` (default), `:codeberg`, or `:sourceforge` |
| `:disposition` | see below |
| `:ref` | where the dotcl support code lives *now* — `:upstream-default`, `("owner/repo" :branch "name" \| :tag "name" \| :commit "sha")`, or for a `:patched` entry `(:upstream :commit "sha")` |
| `:patches` | `:patched` only: patch files under `patches/<lib>/`, applied in order on top of the `:ref` commit |
| `:pr` | upstream pull request this checker can read, as `owner/repo#number`, or `nil` |
| `:fork-status` | tracks a fork that has outlived its purpose but is still there, e.g. `(:redundant "…")`. Deleting the fork removes the key |
| `:retire-when` | the condition under which this entry is deleted |
| `:notes` | prose: what the patch does, anything a reader would otherwise have to guess |

`:disposition` is one of:

- `:upstream-merged` — merged upstream; dotcl still needs a non-stock source
  only until the merge reaches the stock distribution
- `:upstream-pr-open` — pull request filed and pending
- `:fork-only` — public fork exists, no upstream pull request yet
- `:patched` — patch files kept in this repository, applied to a pinned
  upstream commit; no upstream pull request yet

`:upstream-host` says where *upstream* lives, and nothing else. A `:ref` fork is
one of ours and is on GitHub under the `dotcl` organization whichever host
upstream sits on, so it is fetched and checked as GitHub either way.

Codeberg-hosted libraries are built from the upstream commit plus patch files
kept here, under `patches/<lib>/`, instead of from a fork. A `:patched` entry
pins the upstream commit in `(:upstream :commit "sha")` and lists its patches
in `:patches`; the patches are `git format-patch` output. `gen-dist` fetches
that commit from the upstream host, applies the patches with `git am` using a
fixed committer and the patch dates, and archives the resulting commit, so the
tarball is as reproducible as any other and its name changes whenever a patch
does. The commit is pinned rather than followed because a patch only applies to
the tree it was made against. `gen-qlfile` emits nothing for these entries:
qlot cannot apply patches, so use the dist. To move to a newer upstream commit,
rebase the patches onto it, regenerate them with `git format-patch`, and update
`:ref`.

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

**A fork retires at the merge, the entry at the dist.** Those are two clocks and
they run at different speeds. When the upstream pull request merges, the support
code has a new home and our fork owns nothing: `:ref` becomes
`:upstream-default`, so the dist is already built from upstream. The fork is
deleted at that point and its `:fork-status` goes with it. The entry stays until
a stock distribution ships the merged version, because until then a dotcl user
pulling stock still gets a source without the support code.

**Public identifiers only.** Everything in this repository — manifest, commit
messages, issues — refers to public pull requests, public repositories, and
public facts.

## Checks

`scripts/validate.lisp` verifies the manifest:

- schema: required keys present, `:disposition` from the known vocabulary,
  `:ref` shape consistent with the disposition
- patch files: every `:patches` file exists, and every file under `patches/`
  is listed by an entry
- with `gh` available: every `:pr` exists and its state agrees with
  `:disposition`; every `:ref` fork and branch exists and is public. A `:pr` on
  a `:codeberg` upstream is read the same way through Codeberg's Gitea API with
  `curl`, which answers anonymously, with no token, and no weaker a check
- inventory drift: repositories under the `dotcl` organization that no entry
  mentions are reported, so a fork cannot quietly diverge from the manifest
- release assets: every URL in every published `releases.txt` is downloaded,
  and its size and md5 must match the line

```sh
sbcl --script scripts/validate.lisp          # schema only
LEDGER_CHECK_NETWORK=1 sbcl --script scripts/validate.lisp   # + gh and release-asset checks
```

`scripts/test-source-ledger.lisp` exercises the source ledger checks against a
throwaway git repository and a stubbed host, with no network: a repository
with different ids, a new HEAD that does not continue the recorded commit, a
rename, and the first-run and manifest-change cases.

```sh
sbcl --script scripts/test-source-ledger.lisp   # or: dotcl scripts/test-source-ledger.lisp
```

The workflow runs on every push and pull request, and weekly — the scheduled run
is what notices drift nobody triggered.
