# The glue of git-hooks.nix, when the project imports it: no aggregated
# checks.pre-commit, and no hook over the generated files (FY-0017).
{ config, lib, ... }:
let
  patterns = import ./patterns.nix { inherit lib; };
  inherit (config.workspace) generated;
in
{
  _file = ./hooks.nix;

  config.perSystem =
    { options, ... }:
    {
      # Only when the options exist; lib.mkIf would fail on an undeclared
      # option.
      config = lib.optionalAttrs (options ? pre-commit) {
        # It depends on the whole source; every atom has a check of its own.
        pre-commit.check.enable = lib.mkOverride 900 false;
        # A plain definition: the project's excludes add to it.
        pre-commit.settings.excludes = map patterns.regex generated;
      };
    };
}
