{
  # No inputs (FY-0017): the atom imports no upstream module. It wires
  # git-hooks.nix and treefmt-nix only when the project imports them.
  outputs = inputs: { flakeModules.default = import ./nix inputs; };
}
