# The atom evaluates alone, with git-hooks.nix, with treefmt-nix and with
# both, and sets what each of them needs: no checks.pre-commit, a
# substitutable checks.treefmt, the hook treefmt with the wrapper of
# treefmt-nix, and the excludes of the generated files, to which the
# project's own add.
{
  facts,
  fixture,
  inputs,
  root,
  ...
}:
{
  perSystem =
    { pkgs, system, ... }:
    let
      inherit (pkgs) lib;
      patterns = import (root + "/nix/patterns.nix") { inherit lib; };
      generated = [
        "CHANGELOG.md"
        ".release-please-manifest.json"
        "**/flake.lock"
        "LICENSES/"
      ];
      gitHooks = inputs.git-hooks.flakeModule;
      treefmtNix = inputs.treefmt-nix.flakeModule;
      flake = modules: fixture { inherit modules; };
      alone = flake [ ];
      withHooks = flake [ gitHooks ];
      withTreefmt = flake [ treefmtNix ];
      both = flake [
        gitHooks
        treefmtNix
      ];
      own = flake [
        gitHooks
        treefmtNix
        {
          perSystem = {
            pre-commit.settings.excludes = [ "^own$" ];
            treefmt.settings.excludes = [ "own" ];
          };
        }
      ];
      noCheck = flake [
        treefmtNix
        { perSystem.treefmt.flakeCheck = false; }
      ];
      values = flake: flake.allSystems.${system};
      checks = flake: lib.attrNames flake.checks.${system};
      inherit (values both) treefmt;
      check = both.checks.${system}.treefmt;
    in
    {
      checks.test-evaluation = facts pkgs "test-evaluation" {
        "alone: the shell evaluates" = alone.devShells.${system}.default.drvPath != "";
        "alone: no options of git-hooks.nix and treefmt-nix" =
          !(values alone ? pre-commit) && !(values alone ? treefmt);
        "alone: no checks" = checks alone == [ ];
        "git-hooks.nix: no checks.pre-commit" = checks withHooks == [ ];
        "git-hooks.nix: no hook treefmt" = !(values withHooks).pre-commit.settings.hooks.treefmt.enable;
        "git-hooks.nix: the excludes of the generated files" =
          (values withHooks).pre-commit.settings.excludes == map patterns.regex generated;
        "treefmt-nix: checks.treefmt" = checks withTreefmt == [ "treefmt" ];
        # Besides the default excludes of treefmt-nix.
        "treefmt-nix: the excludes of the generated files" = lib.all (
          glob: lib.elem glob (values withTreefmt).treefmt.settings.excludes
        ) (lib.concatMap patterns.globs generated);
        "treefmt-nix: the root found by treefmt" = (values withTreefmt).treefmt.projectRootFile == null;
        "both: only checks.treefmt" = checks both == [ "treefmt" ];
        "both: the hook treefmt" = (values both).pre-commit.settings.hooks.treefmt.enable;
        "both: the hook runs the wrapper" =
          (values both).pre-commit.settings.hooks.treefmt.package == treefmt.build.wrapper;
        "both: the formatter is the wrapper" = both.formatter.${system} == treefmt.build.wrapper;
        "checks.treefmt is substitutable" = check.allowSubstitutes && !check.preferLocalBuild;
        "treefmt.flakeCheck = false: no checks.treefmt" = checks noCheck == [ ];
        "the excludes of the project add" =
          lib.elem "^own$" (values own).pre-commit.settings.excludes
          && lib.length (values own).pre-commit.settings.excludes == 1 + lib.length generated
          && lib.elem "own" (values own).treefmt.settings.excludes
          && lib.elem "LICENSES/*" (values own).treefmt.settings.excludes;
      };
    };
}
