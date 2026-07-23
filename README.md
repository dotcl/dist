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

## Schema

Each entry is a plist:

| key | meaning |
|---|---|
| `:lib` | library name, as the distribution knows it |
| `:upstream` | `owner/repo` of the upstream project |
| `:upstream-host` | `:github` (default) or `:gitlab` |
| `:disposition` | see below |
| `:ref` | where the dotcl support code lives *now* — `:upstream-default`, or `("owner/repo" :branch "name")` |
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

While this repository is private the workflow is manual (`gh workflow run`);
it switches to running on every push and weekly once the repository is public.
