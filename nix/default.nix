# The root module of atom-workspace (FY-0017): the glue a project has once.
# The atom has no inputs and imports no upstream module; its modules wire
# git-hooks.nix and treefmt-nix only when the project imports them.
_atomInputs: {
  key = toString ./default.nix;
  _file = ./default.nix;
  imports = [
    ./generated.nix
    ./shell.nix
  ];
}
