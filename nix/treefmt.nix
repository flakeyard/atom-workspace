# The glue of treefmt-nix, when the project imports it: the root of the
# project found by treefmt, no formatting of the generated files, a
# substitutable checks.treefmt and, with git-hooks.nix, the hook treefmt
# (FY-0017).
{ config, lib, ... }:
let
  patterns = import ./patterns.nix { inherit lib; };
  inherit (config.workspace) generated;
in
{
  _file = ./treefmt.nix;

  config.perSystem =
    { config, options, ... }:
    {
      # Only when the options exist; lib.mkIf would fail on an undeclared
      # option.
      config = lib.optionalAttrs (options ? treefmt) (
        {
          # treefmt finds the root itself, the top of the git working tree,
          # so nix fmt formats the whole project from any directory.
          treefmt.projectRootFile = lib.mkOverride 900 null;
          # A plain definition: the project's excludes add to it.
          treefmt.settings.excludes = lib.concatMap patterns.globs generated;
          # Substitutable, so that an unchanged tree is not checked again.
          checks = lib.mkIf config.treefmt.flakeCheck {
            treefmt = lib.mkOverride 99 (
              (config.treefmt.build.check config.treefmt.projectRoot).overrideAttrs {
                allowSubstitutes = true;
                preferLocalBuild = false;
              }
            );
          };
        }
        # git-hooks.nix sets the package of the hook to the wrapper of
        # treefmt-nix itself.
        // lib.optionalAttrs (options ? pre-commit) {
          pre-commit.settings.hooks.treefmt.enable = lib.mkOverride 900 true;
        }
      );
    };
}
