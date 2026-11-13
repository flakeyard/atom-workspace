# The option workspace.generated: the files that tools write, which no git
# hook and no formatter touches (FY-0015). One list for every system, since
# the files of the project are the same on each.
{ lib, ... }:
let
  patterns = import ./patterns.nix { inherit lib; };
in
{
  _file = ./generated.nix;

  options.workspace.generated = lib.mkOption {
    type = lib.types.listOf (lib.types.strMatching patterns.grammar);
    description = ''
      Paths from the root of the project of files that tools write. A
      trailing / makes a path a directory, with everything below it, and a
      leading **/ matches it at any depth.
    '';
  };

  # A definition, not a default: a plain definition of the project adds to
  # it, and lib.mkForce replaces it.
  config.workspace.generated = [
    "CHANGELOG.md"
    ".release-please-manifest.json"
    "**/flake.lock"
    "LICENSES/"
  ];
}
