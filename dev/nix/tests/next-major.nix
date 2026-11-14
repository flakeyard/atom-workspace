# The warning of the next major version (FY-0038): given while
# nix/next-major.nix exists, with the version and the migration guide it
# names, and a real nix/next-major.nix names a version above the current one.
{ facts, root, ... }:
{
  perSystem =
    { pkgs, ... }:
    let
      inherit (pkgs) lib;
      current = lib.toInt (
        lib.versions.major (lib.importJSON (root + "/.release-please-manifest.json"))."."
      );
      # A file as the maintainer adds it, and a lib.warn that returns what it
      # was given. A file of the repository: one written during evaluation
      # cannot be imported when the store is read-only (nix flake check
      # --no-build).
      file = root + "/dev/fixtures/next-major.nix";
      warned = import (root + "/nix/warning.nix") {
        lib = lib // {
          warn = message: value: { inherit message value; };
        };
        inherit file;
      } "value";
      unwarned = import (root + "/nix/warning.nix") {
        inherit lib;
        file = root + "/nix/absent.nix";
      } "value";
      real = root + "/nix/next-major.nix";
    in
    {
      checks.test-next-major = facts pkgs "test-next-major" {
        # Restated: the text is the interface (FY-0035).
        "the warning names the version and the guide" =
          warned.message == "atom-workspace: version 1 is coming with breaking changes;"
          + " support of this major version ends 6 months after its first release."
          + " Migration guide: https://github.com/flakeyard/atom-workspace/blob/main/docs/migration/v1.md";
        "the value is kept" = warned.value == "value";
        "no file, no warning" = unwarned == "value";
        "nix/next-major.nix names a version above the current one" =
          !builtins.pathExists real || (import real).version > current;
      };
    };
}
