# atom-workspace

A flake-parts module that joins the flakeyard atoms of a project into one
development shell, one set of git hooks and one formatter ([FY-0017][fy-0017],
[ADR-0001][adr-0001]). It is the glue a project has once:

- `devShells.default` from every `devShells.flakeyard-*` fragment of the atoms
  and of the project, with their environment variables and at most one compiler;
- with git-hooks.nix, the git hooks installed by the shell, and no aggregated
  `checks.pre-commit`;
- with treefmt-nix, the root of the project found by treefmt, a substitutable
  `checks.treefmt` and, with both, the hook `treefmt`;
- generated files, such as `CHANGELOG.md`, excluded from every hook and
  formatter.

## Inputs

The atom has no inputs ([FY-0017][fy-0017]), so it needs no `follows`. It
imports neither git-hooks.nix nor treefmt-nix: it wires each one only when the
project has it, from the atoms that import it or from the project's own imports.
While the atom is `0.y.z`, only flakeyard's own repositories use it, in the form
of [FY-0016][fy-0016]:

```nix
{
  inputs = {
    nixpkgs.url = "git+https://github.com/NixOS/nixpkgs?ref=nixos-26.05&rev=<commit>&shallow=1";
    flake-parts = {
      url = "git+https://github.com/hercules-ci/flake-parts?ref=main&rev=<commit>&shallow=1";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };
    git-hooks = {
      url = "git+https://github.com/cachix/git-hooks.nix?ref=master&rev=<commit>&shallow=1";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    treefmt-nix = {
      url = "git+https://github.com/numtide/treefmt-nix?ref=main&rev=<commit>&shallow=1";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    atom-workspace.url = "git+https://github.com/flakeyard/atom-workspace?ref=v0&rev=<commit>&shallow=1";
  };

  outputs =
    inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      imports = [
        inputs.git-hooks.flakeModule
        inputs.treefmt-nix.flakeModule
        inputs.atom-workspace.flakeModules.default
      ];
    };
}
```

## Files it reads

From the project's source, which for a git flake holds only tracked files:

- `.pre-commit-config.yaml`, only whether it exists: with git-hooks.nix, a
  committed one fails evaluation of the shell with

  ```text
  atom-workspace: .pre-commit-config.yaml is committed, and git-hooks.nix
    links its own there; remove it from git and add it to .gitignore.
  ```

`checks.treefmt` formats a copy of `treefmt.projectRoot`, the whole source by
default.

## Development shell

`devShells.default` joins, through `inputsFrom`, every `devShells.flakeyard-*`
and no other shell. `devShells.flakeyard-project` is reserved for the project's
own tools:

```nix
perSystem =
  { pkgs, ... }:
  {
    devShells.flakeyard-project = pkgs.mkShellNoCC {
      packages = [ pkgs.just ];
      passthru.flakeyard.env.PROJECT_MODE = "dev";
    };
  };
```

- **Variables.** `passthru.flakeyard.env` of every fragment becomes `env` of the
  shell. A variable with different values in two fragments fails evaluation:

  ```text
  atom-workspace: the fragments set FOO to different values:
    flakeyard-a = "1"
    flakeyard-b = "2"
  ```

- **Compiler.** A fragment made with `mkShell` brings the compiler of its
  `stdenv`; one made with `mkShellNoCC` brings none. The shell takes the one
  compiler the fragments bring, or none; two different ones fail evaluation and
  name the fragments of each:

  ```text
  atom-workspace: the fragments bring more than one compiler:
    flakeyard-a: gcc-wrapper-15.3.0
    flakeyard-b: clang-wrapper-21.1.8
  ```

- **Hooks.** With git-hooks.nix, the shell has pre-commit, the tool of the
  hooks, and installs the hooks each time it starts (see below).

The shell is also the read-only option `perSystem.workspace.shell`. A project
that defines its own `devShells.default` replaces the workspace's, so it builds
on `workspace.shell` to keep the fragments, the variables and the hooks:

```nix
perSystem =
  { config, pkgs, ... }:
  {
    devShells.default = config.workspace.shell.overrideAttrs (old: {
      nativeBuildInputs = old.nativeBuildInputs ++ [ pkgs.jq ];
    });
  };
```

### Git hooks

When the shell starts in a git working tree, the installation script of
git-hooks.nix links `.pre-commit-config.yaml` at the top of the working tree to
the configuration in the Nix store, removes the hooks of every stage, installs
those of the configured stages and sets `core.hooksPath` to the `hooks`
directory of the git directory that every worktree shares. It refuses to replace
a `.pre-commit-config.yaml` that is a file. A project that takes the shell
should:

- add `.direnv/` and `.pre-commit-config.yaml` to `.gitignore`;
- commit inside the dev container ([FY-0012][fy-0012]): the hooks run tools by
  their paths in the store that built the shell, which the host may not have;
- run `direnv allow` in every worktree, which links its own configuration;
- run `direnv block` before checking out a branch it does not trust: entering
  the directory builds that branch's shell and runs its shell hook.

## Generated files

The top-level option `workspace.generated` lists the files that tools write, as
paths from the root of the project. No hook and no formatter touches them
([FY-0015][fy-0015]). Its entries are:

- `CHANGELOG.md`
- `.release-please-manifest.json`
- `**/flake.lock`
- `LICENSES/`

A trailing `/` makes an entry a directory with everything below it, and a
leading `**/` matches it at any depth, the root included. `*`, `?`, `[`, `]`,
`{`, `}` and `\` are not allowed. A plain definition adds entries, and
`lib.mkForce` replaces the list:

```nix
{
  workspace.generated = [ "docs/api/" ];
}
```

Each entry becomes an anchored regular expression in
`pre-commit.settings.excludes` and globs in `treefmt.settings.excludes`, both at
normal priority, so the project's own excludes add to them.

## Values it sets

With `lib.mkOverride 900`, so a plain definition of the project replaces them:

- `devShells.default`: `workspace.shell`;
- with git-hooks.nix, `pre-commit.check.enable`: `false`, which removes the
  aggregated `checks.pre-commit`; every atom has a check of its own;
- with treefmt-nix, `treefmt.projectRootFile`: `null`, so treefmt takes the top
  of the git working tree as the root and `nix fmt` formats the whole project
  from any directory;
- with both, `pre-commit.settings.hooks.treefmt.enable`: `true`. git-hooks.nix
  sets its package, and treefmt-nix sets `formatter`, to the wrapper of
  treefmt-nix.

With treefmt-nix, while `treefmt.flakeCheck` is true, `checks.treefmt` is the
check of treefmt-nix with `allowSubstitutes = true` and
`preferLocalBuild = false`, so an unchanged tree is not checked again. It is set
with `lib.mkOverride 99`; a project replaces it with `lib.mkForce`.

## Outputs

- `flakeModules.default`: the module. It adds the options `workspace.generated`
  and `perSystem.workspace.shell`, and the values above.

Supported systems are `x86_64-linux` and `aarch64-linux`.

## Supported upstream revisions

The oldest supported revisions are those the tests run with: git-hooks.nix
`204b6977e00caac19e2313015a598543ca7be150`, treefmt-nix
`0d6d739a833ba9a9c93034862e4a7b061a062a1c`, flake-parts
`ea2630b7470978622c7689a1ff75d2b389175399` and nixpkgs `nixos-26.05` at
`ac588ef1c914865dad517b337ea0eb9694a4021c`.

## Public API

Releases follow [semantic versioning][versioning] ([FY-0024][fy-0024]). The
public API is `flakeModules.default` without inputs, the options
`workspace.generated` with its grammar and its entries and
`perSystem.workspace.shell`, the shells it joins and how, the values it sets
with their priorities, the failures of evaluation, the file it reads, the
supported systems and the oldest supported upstream revisions.

The last minor release before a major one contains `nix/next-major.nix`; while
it exists, the shell warns at evaluation that the next major version is coming
and where its migration guide is ([FY-0038][fy-0038]).

## Develop in the container

Open the repository in the flakeyard dev container: the editor reads
[`.devcontainer/devcontainer.json`](.devcontainer/devcontainer.json), and
`direnv` loads the shell of [`dev/flake.nix`](dev/flake.nix) through
[`.envrc`](.envrc) ([FY-0012][fy-0012]). With Nix on the host, `direnv allow` or
`nix develop ./dev` gives the same shell.

The public [`flake.nix`](flake.nix) holds only the module ([FY-0017][fy-0017]).
[`dev/flake.nix`](dev/flake.nix), with its own lock, imports git-hooks.nix,
treefmt-nix and the atom as consumers do, and holds the tests:

- `treefmt`: the atom's check of this repository;
- `test-evaluation`: the atom alone, with git-hooks.nix, with treefmt-nix and
  with both, and the values it sets;
- `test-shell`: the fragments, variables, compilers and hooks of the shell, the
  committed `.pre-commit-config.yaml`, and a project's own `devShells.default`;
- `test-generated`: `workspace.generated` extended, replaced and outside its
  grammar;
- `test-patterns`: the regular expressions, with `builtins.match` and Python's
  `re.search`, and the globs of the entries;
- `test-format`: in a git repository, the wrapper of treefmt run from a
  subdirectory and the hooks run by pre-commit format the project and leave the
  generated files untouched;
- `test-install`: the shell hook installs the git hooks;
- `test-next-major`: the warning of the next major version.

Run the same commands as CI:

```sh
nix flake check --no-update-lock-file ./dev
nix flake check --no-update-lock-file --no-build --all-systems ./dev
```

CI runs [`test.yaml`](.github/workflows/test.yaml), which calls
[workflow-check][workflow-check] with `./dev`: it checks `dev/flake.lock`,
builds every check on x86_64 and arm64 runners, checks the pull request title
and `renovate.json`, fails on configuration files of atom tools, and reports
`check / required` ([FY-0034][fy-0034]). Its weekly run overrides nixpkgs,
git-hooks.nix and treefmt-nix with their current branches.
[`scorecard.yaml`](.github/workflows/scorecard.yaml) runs OpenSSF Scorecard, and
[`release.yaml`](.github/workflows/release.yaml) releases the repository with
[workflow-release][workflow-release].

Before a pull request, also run nixfmt, statix, deadnix, prettier, markdownlint,
typos and `reuse lint`; the atoms that will provide them are not released yet
([FY-0038][fy-0038]).

## License

[MIT](LICENSE).

[adr-0001]:
  docs/adr/records/0001-join-the-atoms-into-one-shell-hooks-and-formatter.md
[fy-0012]:
  https://github.com/flakeyard/decisions/blob/main/docs/adr/records/0012-develop-in-container.md
[fy-0015]:
  https://github.com/flakeyard/decisions/blob/main/docs/adr/records/0015-documentation-rules.md
[fy-0016]:
  https://github.com/flakeyard/decisions/blob/main/docs/adr/records/0016-pin-form.md
[fy-0017]:
  https://github.com/flakeyard/decisions/blob/main/docs/adr/records/0017-atom-contract.md
[fy-0024]:
  https://github.com/flakeyard/decisions/blob/main/docs/adr/records/0024-versioning-and-support.md
[fy-0034]:
  https://github.com/flakeyard/decisions/blob/main/docs/adr/records/0034-check-every-repository-with-workflow-check.md
[fy-0038]:
  https://github.com/flakeyard/decisions/blob/main/docs/adr/records/0038-roll-out-the-atoms.md
[versioning]: https://github.com/flakeyard/.github/blob/main/VERSIONING.md
[workflow-check]: https://github.com/flakeyard/workflow-check
[workflow-release]: https://github.com/flakeyard/workflow-release
