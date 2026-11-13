{
  description = "atom-workspace: the tests of the atom and the checks of this repository.";

  inputs = {
    nixpkgs.url = "git+https://github.com/NixOS/nixpkgs?ref=nixos-26.05&rev=ac588ef1c914865dad517b337ea0eb9694a4021c&shallow=1";
    flake-parts = {
      url = "git+https://github.com/hercules-ci/flake-parts?ref=main&rev=ea2630b7470978622c7689a1ff75d2b389175399&shallow=1";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };
    git-hooks = {
      url = "git+https://github.com/cachix/git-hooks.nix?ref=master&rev=204b6977e00caac19e2313015a598543ca7be150&shallow=1";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    treefmt-nix = {
      url = "git+https://github.com/numtide/treefmt-nix?ref=main&rev=0d6d739a833ba9a9c93034862e4a7b061a062a1c&shallow=1";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    import-tree.url = "git+https://github.com/vic/import-tree?ref=main&rev=eb1b52eaecc57f7c136d07ae8a93e724dfecac46&shallow=1";
  };

  outputs =
    inputs:
    let
      # The root of the repository; every other file reaches it as the module
      # argument root.
      root = ../.;
      # The atom as a consumer gets it. It has no inputs. An input path:..
      # would leave the directory of this flake, which the pin form of
      # action-flake-lock forbids for path inputs.
      atom = (import (root + "/flake.nix")).outputs { };
    in
    inputs.flake-parts.lib.mkFlake
      {
        # The project is the whole repository, not dev/.
        inputs = inputs // {
          self = inputs.self // {
            outPath = root;
          };
        };
      }
      {
        systems = [
          "x86_64-linux"
          "aarch64-linux"
        ];
        imports = [
          inputs.git-hooks.flakeModule
          inputs.treefmt-nix.flakeModule
          atom.flakeModules.default
          # Every file under nix/ is a flake-parts module.
          (inputs.import-tree ./nix)
        ];
        _module.args = { inherit root atom; };
      };
}
