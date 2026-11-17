{
  # The only input is lib-atom, which the atom pins in its own flake.lock;
  # consumers neither declare nor follow it (FY-0017, FY-0040). The atom
  # imports no upstream module: it wires git-hooks.nix and treefmt-nix only
  # when the project imports them.
  inputs.lib-atom.url = "git+https://github.com/flakeyard/lib-atom?ref=v0&rev=f2c83b7399315afb477abba1e112bca107f0b345&shallow=1";

  outputs = inputs: { flakeModules.default = import ./nix inputs; };
}
