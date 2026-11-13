# fixture: the flake of a project that imports the atom as consumers do, with
# the given modules, such as those of git-hooks.nix and treefmt-nix, and the
# given source, the repository unless named.
{
  atom,
  inputs,
  root,
  ...
}:
{
  _module.args.fixture =
    {
      modules ? [ ],
      source ? root,
    }:
    inputs.flake-parts.lib.mkFlake
      {
        inputs = inputs // {
          self = {
            outPath = source;
            inherit inputs;
          };
        };
      }
      {
        systems = [
          "x86_64-linux"
          "aarch64-linux"
        ];
        imports = [ atom.flakeModules.default ] ++ modules;
        # allSystems.<system> exposes the options and values to the tests.
        debug = true;
      };
}
