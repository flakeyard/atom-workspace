# The conversions of the entries of workspace.generated: the regular
# expressions, read by builtins.match and by Python's re.search as pre-commit
# reads them, and the globs of treefmt.
{ root, ... }:
{
  perSystem =
    { pkgs, ... }:
    let
      inherit (pkgs) lib;
      patterns = import (root + "/nix/patterns.nix") { inherit lib; };
      # Entries, and the paths that each one matches or not.
      cases = {
        "CHANGELOG.md" = {
          matches = [ "CHANGELOG.md" ];
          misses = [
            "sub/CHANGELOG.md"
            "CHANGELOG.mdx"
            "CHANGELOGxmd"
          ];
        };
        ".release-please-manifest.json" = {
          matches = [ ".release-please-manifest.json" ];
          misses = [ "x.release-please-manifest.json" ];
        };
        "**/flake.lock" = {
          matches = [
            "flake.lock"
            "dev/flake.lock"
            "a/b/flake.lock"
          ];
          misses = [
            "devflake.lock"
            "dev/flake.lock.bak"
          ];
        };
        "LICENSES/" = {
          matches = [
            "LICENSES/MIT.txt"
            "LICENSES/a/b.txt"
          ];
          misses = [
            "LICENSES"
            "LICENSESx/a"
            "sub/LICENSES/MIT.txt"
          ];
        };
        "**/gen/" = {
          matches = [
            "gen/a"
            "a/gen/b/c"
          ];
          misses = [
            "agen/b"
            "gen"
          ];
        };
        "a+b(c)|d^$" = {
          matches = [ "a+b(c)|d^$" ];
          misses = [ "aab(c)|d^$" ];
        };
      };
      globs = {
        "CHANGELOG.md" = [ "CHANGELOG.md" ];
        "**/flake.lock" = [
          "flake.lock"
          "**/flake.lock"
        ];
        "LICENSES/" = [ "LICENSES/*" ];
        "**/gen/" = [
          "gen/*"
          "**/gen/*"
        ];
      };
      # Every entry and path with the result of builtins.match.
      table = lib.concatLists (
        lib.mapAttrsToList (
          entry: paths:
          map (path: {
            inherit entry path;
            regex = patterns.regex entry;
            expected = lib.elem path paths.matches;
            nix = builtins.match (patterns.regex entry) path != null;
          }) (paths.matches ++ paths.misses)
        ) cases
      );
      wrongGlobs = lib.filterAttrs (entry: expected: patterns.globs entry != expected) globs;
    in
    {
      checks.test-patterns =
        pkgs.runCommand "test-patterns"
          {
            nativeBuildInputs = [ pkgs.python3 ];
            table = builtins.toJSON table;
            wrongGlobs = builtins.toJSON wrongGlobs;
          }
          ''
            python3 - <<'PYTHON'
            import json, os, re, sys
            failed = False
            for case in json.loads(os.environ["table"]):
                python = re.search(case["regex"], case["path"]) is not None
                if case["nix"] != case["expected"] or python != case["expected"]:
                    failed = True
                    print(f"{case['entry']} on {case['path']}: expected {case['expected']}, "
                          f"builtins.match {case['nix']}, re.search {python}", file=sys.stderr)
            for entry in json.loads(os.environ["wrongGlobs"]):
                failed = True
                print(f"wrong globs of {entry}", file=sys.stderr)
            sys.exit(1 if failed else 0)
            PYTHON
            touch $out
          '';
    };
}
