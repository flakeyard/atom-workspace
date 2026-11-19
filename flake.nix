{
  # The only input is lib-atom, which the atom pins in its own flake.lock;
  # consumers neither declare nor follow it (FY-0017, FY-0040). The atom
  # imports no upstream module: it wires git-hooks.nix and treefmt-nix only
  # when the project imports them.
  inputs.lib-atom.url = "git+https://github.com/flakeyard/lib-atom?ref=v0&rev=99d4af06332a1a4b33f51aa4d2ccf2b3627af46b&shallow=1";

  outputs = inputs: { flakeModules.default = import ./nix inputs; };
}
