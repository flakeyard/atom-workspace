# The root module of atom-workspace (FY-0017): the glue a project has once.
# The atom imports no upstream module; its modules wire git-hooks.nix and
# treefmt-nix only when the project imports them. Its input lib-atom and the
# root of the repository reach the other files only as function arguments.
atomInputs:
let
  root = ./..;
  # The warning of the next major version (FY-0038), from the functions that
  # atoms share, of the revision the atom pins (FY-0040), with lib of the
  # consumer's nixpkgs.
  warning =
    lib:
    atomInputs.lib-atom.lib.warning {
      inherit lib root;
      atom = "atom-workspace";
    };
in
{
  key = toString ./default.nix;
  _file = ./default.nix;
  imports = [
    ./generated.nix
    (import ./shell.nix { inherit warning; })
    ./hooks.nix
    ./treefmt.nix
  ];
}
