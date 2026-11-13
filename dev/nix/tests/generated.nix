# workspace.generated: its entries by default, a plain definition of the
# project adds to them, lib.mkForce replaces them, the hooks and treefmt
# follow, and entries outside the grammar fail.
{
  facts,
  fixture,
  inputs,
  ...
}:
{
  perSystem =
    { pkgs, system, ... }:
    let
      inherit (pkgs) lib;
      default = [
        "CHANGELOG.md"
        ".release-please-manifest.json"
        "**/flake.lock"
        "LICENSES/"
      ];
      flake =
        generated:
        fixture {
          modules = [
            inputs.git-hooks.flakeModule
            inputs.treefmt-nix.flakeModule
          ]
          ++ lib.optional (generated != null) { workspace.generated = generated; };
        };
      generated = generated: (flake generated).debug.workspace.generated;
      values = (flake [ "own/" ]).allSystems.${system};
      fails = entry: !(builtins.tryEval (builtins.deepSeq (generated [ entry ]) true)).success;
    in
    {
      checks.test-generated = facts pkgs "test-generated" {
        "the default entries" = generated null == default;
        "a plain definition adds" = generated [ "own/" ] == default ++ [ "own/" ];
        "lib.mkForce replaces" = generated (lib.mkForce [ "own/" ]) == [ "own/" ];
        "the hooks follow" = lib.elem "^own/.*$" values.pre-commit.settings.excludes;
        "treefmt follows" = lib.elem "own/*" values.treefmt.settings.excludes;
        "an entry with a glob fails" = fails "own/*.md";
        "an entry with a regular expression fails" = fails "own/[a-z]";
        "an absolute path fails" = fails "/own";
        "an empty segment fails" = fails "own//x";
        "an empty entry fails" = fails "";
        "**/ alone fails" = fails "**/";
        "a path with spaces and dots" = !fails "own dir/.file.json";
      };
    };
}
