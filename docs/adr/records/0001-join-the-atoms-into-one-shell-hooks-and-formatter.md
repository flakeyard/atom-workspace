---
id: ADR-0001
title: Join the atoms into one shell, git hooks and formatter
status: accepted
date: 2026-11-13
supersedes: []
superseded_by: []
related: []
affects: ["flake.nix", "nix/**", "dev/**", "README.md"]
review_by:
---

## Context

atom-workspace is the second atom of step 8 of [FY-0022][fy-0022]
([FY-0038][fy-0038]): the glue a project has once ([FY-0017][fy-0017]). It
builds `devShells.default` from the `devShells.flakeyard-*` fragments of the
other atoms, installs the git hooks, enables the hook `treefmt`, makes
`checks.treefmt` substitutable, switches off `checks.pre-commit` and excludes
generated files. It has no inputs, and other atoms do not know about it.
Decisions of flakeyard require of it:

- [FY-0017][fy-0017]: the public flake holds only `flakeModules.default`;
  `nix/default.nix` sets `key` and `_file` and declares no options; upstream
  options are set with `lib.mkOverride 900`; only atom-workspace or the consumer
  sets `devShells.default`, the hook `treefmt`, `treefmt.projectRootFile`, the
  global excludes of treefmt, `pre-commit.check.*` and
  `pre-commit.settings.excludes`; a fragment brings a compiler through its
  `stdenv` and variables through `passthru.flakeyard.env`, and the workspace
  accepts at most one compiler and fails on conflicting variables; checks are
  substitutable; every file an atom reads is listed in its README.
- [FY-0015][fy-0015]: files that tools generate, such as `CHANGELOG.md` and
  `.release-please-manifest.json`, are not formatted or linted.
- [FY-0012][fy-0012]: repositories are developed in the dev container, and
  `direnv` loads the shell of `.envrc`.
- [FY-0038][fy-0038]: the warning of the next major version lives in
  `nix/next-major.nix`; scheduled tests run through workflow-check.
- [FY-0039][fy-0039]: a file reaches files outside its directory only from one
  root.

Experiments with git-hooks.nix at `204b6977`, treefmt-nix at `0d6d739a`,
flake-parts at `ea2630b7` and nixpkgs `nixos-26.05` showed:

- `lib.mkIf (options ? treefmt)` around a definition of `treefmt.*` fails when
  treefmt-nix is not imported: the module system checks that the option exists
  before it looks at the condition. `lib.optionalAttrs` leaves the definition
  out. A module whose whole value depends on `options` recurses infinitely; the
  condition has to sit below `config`.
- git-hooks.nix sets the package of the hook `treefmt` to the wrapper of
  treefmt-nix with `lib.mkOverride 900` when treefmt-nix is imported; a second
  definition at the same priority conflicts. treefmt-nix sets `formatter` to the
  same wrapper.
- `treefmt.projectRootFile = null` (treefmt-nix since `1c2f8921`) makes the
  wrapper leave the root to treefmt, which takes the top of the git working
  tree, so the wrapper run from `dev/` formats the whole project.
  `treefmt.settings.excludes` replaced `treefmt.settings.global.excludes` in
  treefmt-nix `72121d09`.
- treefmt matches an exclude as a glob against the whole path from the root, and
  its `*` also matches `/`: `**/flake.lock` does not match `flake.lock` at the
  root, and `LICENSES/*` matches every file below `LICENSES/`. pre-commit
  matches `exclude` with Python's `re.search`.
- A default of an option of type list is replaced by any definition; a list
  given as a definition at normal priority is concatenated with the project's
  definitions and replaced by `lib.mkForce`.
- `mkShell` with `inputsFrom` takes the inputs and the `shellHook` of every
  shell it is given, but not their `env`.
- The installation script of git-hooks.nix links `.pre-commit-config.yaml` at
  the top of the working tree, registered as a garbage collector root unless
  `addGcRoot` is false, removes the hooks of every stage, installs those of the
  configured stages and sets `core.hooksPath` to the `hooks` directory of the
  common git directory, which every worktree shares. It refuses to install over
  a `.pre-commit-config.yaml` that is a file, and only warns.
- The installed hooks run tools by `/nix/store` paths of the store that built
  the shell.

## Decision

### Inputs and form

The public flake has no inputs and holds only
`flakeModules.default = import ./nix inputs`. `nix/default.nix` sets `key` and
`_file`, declares no options and imports the atom's modules; it names the unused
inputs `_atomInputs`. No file reaches a file outside its own directory, so the
atom needs no root of [FY-0039][fy-0039].

The atom wires git-hooks.nix only when the option `pre-commit` exists, and
treefmt-nix only when `treefmt` exists, with `lib.optionalAttrs` below `config`.
It works alone, with either and with both.

### Development shell

The read-only option `perSystem.workspace.shell` is the shell the atom builds,
and `devShells.default` is set to it with `lib.mkOverride 900`, so a project's
plain definition replaces it. A project that defines its own takes the
workspace's as its base, for example with
`config.workspace.shell.overrideAttrs`.

The shell joins every `devShells.flakeyard-*`, through `inputsFrom`, and no
other shell. `devShells.flakeyard-project` is reserved for the project's own
tools and joined like the fragments of atoms.

- **Variables.** `env` is the union of the `passthru.flakeyard.env` of every
  fragment. The same variable with different values, compared as strings, fails
  evaluation with the variable, the fragments and their values.
- **Compiler.** A fragment brings a compiler when `stdenv.cc` is not null.
  Fragments whose stdenvs are equal derivations bring the same compiler. With
  one compiler the shell is `mkShell` over that stdenv; with none it is
  `mkShellNoCC`; with more, evaluation fails with each compiler and the
  fragments that bring it.
- **Bash.** The shell has `bashInteractive`: `mkShell` puts the bash of stdenv
  first on `PATH`, which lacks the interactive builtins such as `compgen` that
  scripts and people expect.
- **Hooks.** With git-hooks.nix, the shell has the tool of the hooks,
  `pre-commit.settings.package`, and runs `pre-commit.installationScript` as its
  `shellHook`, which installs the hooks as described in the context each time
  the shell starts. Without git-hooks.nix it installs nothing.
- **Committed configuration.** With git-hooks.nix, evaluation of the shell fails
  when the project's source has `.pre-commit-config.yaml`, which the
  installation would refuse to replace.

The README tells projects to ignore `.direnv/` and `.pre-commit-config.yaml` in
git, to commit inside the container, whose store has the tools of the hooks, to
run `direnv allow` in every worktree, which links its own configuration, and to
run `direnv block` before switching to a branch they do not trust, since
entering the directory runs that branch's shell hook.

### Generated files

The top-level option `workspace.generated` lists the files that tools write. It
is a top-level option, not one of `perSystem`: the files of a project are the
same on every system, and a project writes them once. The atom gives it, as a
definition at normal priority rather than a default, `CHANGELOG.md`,
`.release-please-manifest.json`, `**/flake.lock` and `LICENSES/`, so that a
project's plain definition adds to them and `lib.mkForce` replaces them.

An entry is a path from the root of the project without `*`, `?`, `[`, `]`, `{`,
`}` or `\`, which the type of the option checks. A trailing `/` makes the entry
a directory with everything below it; a leading `**/` matches it at any depth,
the root included. Each entry becomes:

- a regular expression in `pre-commit.settings.excludes`: `^`, `(.*/)?` for
  `**/`, the path escaped with `lib.escapeRegex`, `.*` for a directory, and `$`.
  It is read the same by `builtins.match` and by Python's `re.search`;
- globs in `treefmt.settings.excludes`: the path, with `*` appended for a
  directory, and the same glob behind `**/` for an entry with `**/`.

Both lists are set at normal priority, so they are concatenated with the
project's own excludes.

### Values and priorities

With `lib.mkOverride 900`, so that a plain definition of the project replaces
them:

- `devShells.default`: `workspace.shell`;
- `pre-commit.check.enable`: `false`;
- `treefmt.projectRootFile`: `null`;
- `pre-commit.settings.hooks.treefmt.enable`: `true`, with both upstreams.

At normal priority, so that the project's definitions add to them:

- `pre-commit.settings.excludes`: the regular expressions of the entries;
- `treefmt.settings.excludes`: the globs of the entries.

`checks.treefmt` exists while `treefmt.flakeCheck` is true. It is the check of
treefmt-nix over `treefmt.projectRoot` with `allowSubstitutes = true` and
`preferLocalBuild = false`, at priority 99 so that it replaces the definition of
treefmt-nix; a project replaces it with `lib.mkForce`. The atom sets neither the
package of the hook `treefmt` nor `formatter`: git-hooks.nix and treefmt-nix set
both to the wrapper of treefmt-nix.

### Next major version

While `nix/next-major.nix` exists, `workspace.shell`, and so
`devShells.default`, warns with `lib.warn` of the consumer's nixpkgs: the
version, the end of support 6 months after it, and the link to the migration
guide the file names ([FY-0016][fy-0016], [FY-0038][fy-0038]). `nix flake check`
evaluates the shell and shows the warning.

### Supported upstream revisions

The oldest supported revisions are those the tests run with: git-hooks.nix
`204b6977e00caac19e2313015a598543ca7be150`, treefmt-nix
`0d6d739a833ba9a9c93034862e4a7b061a062a1c`, flake-parts
`ea2630b7470978622c7689a1ff75d2b389175399` and nixpkgs `nixos-26.05` at
`ac588ef1c914865dad517b337ea0eb9694a4021c`. treefmt-nix before `1c2f8921` does
not accept a null `projectRootFile`.

### Tests

`dev/flake.nix` imports git-hooks.nix, treefmt-nix and the atom from its flake's
own outputs, and its checks evaluate on x86_64-linux and aarch64-linux:

- evaluation alone, with git-hooks.nix, with treefmt-nix and with both, and the
  values of the table;
- the shell: packages and variables of every fragment and of no other shell,
  conflicting variables, one compiler, two compilers, the hooks, the committed
  configuration, and a project's `devShells.default`;
- `workspace.generated`: its entries, extended and replaced, and entries outside
  the grammar;
- the conversions, with `builtins.match` and Python's `re.search`;
- in a git repository in the sandbox: the wrapper run from a subdirectory and
  pre-commit leave the generated files untouched and format the others, and the
  installation script links the configuration, installs the hooks and sets
  `core.hooksPath`;
- the warning of the next major version.

## Constraints

- The public flake MUST have no inputs and MUST hold only
  `flakeModules.default = import ./nix inputs`.
- The atom MUST NOT import an upstream module and MUST set options of
  git-hooks.nix and treefmt-nix only when they exist, with `lib.optionalAttrs`,
  never `lib.mkIf`.
- `devShells.default` MUST be set only with `lib.mkOverride 900`, from
  `workspace.shell`, which MUST join every `devShells.flakeyard-*` and no other
  shell.
- Evaluation MUST fail on a variable with different values in two fragments, and
  on more than one compiler, naming the fragments.
- The atom MUST NOT set the package of the hook `treefmt` or `formatter`.
- `checks.treefmt` MUST be substitutable whenever it exists.
- Entries of `workspace.generated` MUST follow the grammar of this record, and
  the atom's entries MUST be a definition at normal priority, not a default.
- The excludes of pre-commit and treefmt MUST be set at normal priority.
- With git-hooks.nix, evaluation of the shell MUST fail when
  `.pre-commit-config.yaml` is committed.
- Everything listed in the "Public API" of the README is the public API
  ([FY-0017][fy-0017], [FY-0024][fy-0024]).

## Consequences

- (+) One shell, one set of hooks and one formatter, whichever atoms a project
  takes, without the atoms knowing about each other.
- (+) A project replaces or extends every value with a plain definition, except
  `checks.treefmt`, which needs `lib.mkForce`.
- (+) Generated files are excluded once, in one grammar, for every hook and
  formatter.
- (+) An unchanged tree is not formatted again in CI.
- (−) The hooks are installed each time the shell starts in a new worktree, and
  only there; a clone without `direnv allow` has no hooks.
- (−) A commit made outside the container fails when the host's store lacks the
  tools of the hooks.
- (−) The atom depends on option names of git-hooks.nix and treefmt-nix that it
  does not pin; the scheduled tests notice renames.
- (±) A project that defines its own `devShells.default` loses the shell of the
  workspace unless it builds on `workspace.shell`.

## Alternatives considered

- **`lib.mkIf (options ? …)`.** Fails when the upstream is not imported.
- **git-hooks.nix and treefmt-nix as inputs.** Every project would have to
  import both, and FY-0017 gives the atom no inputs.
- **The `shellHook` of git-hooks.nix.** It prepends pre-commit to `PATH` by
  hand; the package in `packages` does the same through `mkShell`.
- **`workspace.generated` with a `default`.** Any definition of the project
  would drop the atom's entries.
- **Globs or regular expressions as entries.** Each engine reads them
  differently; a fixed grammar converts to both.
- **`workspace.generated` in `perSystem`.** The files do not depend on the
  system.
- **The aggregated `checks.pre-commit`.** It depends on the whole source; every
  atom has its own check ([FY-0017][fy-0017]).
- **Setting the package of the hook `treefmt`.** Conflicts with the definition
  of git-hooks.nix.

[fy-0012]:
  https://github.com/flakeyard/decisions/blob/main/docs/adr/records/0012-develop-in-container.md
[fy-0015]:
  https://github.com/flakeyard/decisions/blob/main/docs/adr/records/0015-documentation-rules.md
[fy-0016]:
  https://github.com/flakeyard/decisions/blob/main/docs/adr/records/0016-pin-form.md
[fy-0017]:
  https://github.com/flakeyard/decisions/blob/main/docs/adr/records/0017-atom-contract.md
[fy-0022]:
  https://github.com/flakeyard/decisions/blob/main/docs/adr/records/0022-bootstrap.md
[fy-0024]:
  https://github.com/flakeyard/decisions/blob/main/docs/adr/records/0024-versioning-and-support.md
[fy-0038]:
  https://github.com/flakeyard/decisions/blob/main/docs/adr/records/0038-roll-out-the-atoms.md
[fy-0039]:
  https://github.com/flakeyard/decisions/blob/main/docs/adr/records/0039-reach-repository-files-in-nix-from-one-root.md
