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
    atom-data-formats = {
      url = "git+https://github.com/flakeyard/atom-data-formats?ref=v0&rev=933cbb3ff234825dd19a55c91a1bb279ea2682cb&shallow=1";
      inputs.treefmt-nix.follows = "treefmt-nix";
      inputs.git-hooks.follows = "git-hooks";
    };
    atom-markdown = {
      url = "git+https://github.com/flakeyard/atom-markdown?ref=v0&rev=90a9dc7b59521c187fabd6662205b88e712d088d&shallow=1";
      inputs.treefmt-nix.follows = "treefmt-nix";
      inputs.git-hooks.follows = "git-hooks";
    };
    atom-nix = {
      url = "git+https://github.com/flakeyard/atom-nix?ref=v0&rev=c591b0716c9fe3f16074637e63ee9128e602ee6a&shallow=1";
      inputs.treefmt-nix.follows = "treefmt-nix";
      inputs.git-hooks.follows = "git-hooks";
    };
    atom-shell = {
      url = "git+https://github.com/flakeyard/atom-shell?ref=v0&rev=9cc395d50024ee12c6b71ae6df77ea8b4a2aba66&shallow=1";
      inputs.treefmt-nix.follows = "treefmt-nix";
      inputs.git-hooks.follows = "git-hooks";
    };
    atom-text = {
      url = "git+https://github.com/flakeyard/atom-text?ref=v0&rev=64bd85b85d3fc823cf43c71baa9279caeda8a92c&shallow=1";
      inputs.git-hooks.follows = "git-hooks";
    };
    import-tree.url = "git+https://github.com/vic/import-tree?ref=main&rev=eb1b52eaecc57f7c136d07ae8a93e724dfecac46&shallow=1";
  };

  outputs =
    inputs:
    let
      # The root of the repository; every other file reaches it as the module
      # argument root.
      root = ../.;
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      # The loader of lib-atom (FY-0040): the source of the revision that the
      # atom's root flake.lock pins, so that the atom has one pin of it.
      lock = builtins.fromJSON (builtins.readFile (root + "/flake.lock"));
      lib-atom-source = builtins.fetchTree lock.nodes.${lock.nodes.root.inputs.lib-atom}.locked;
      lib-atom = (import (lib-atom-source + "/flake.nix")).outputs { };
      # The atom as a consumer gets it: its flake's outputs with its own
      # lib-atom, unless given. An input path:.. would leave the directory of
      # this flake, which the pin form of action-flake-lock forbids for path
      # inputs.
      atomFor = given: (import (root + "/flake.nix")).outputs ({ inherit lib-atom; } // given);
      # The helpers of the tests, from the same revision of lib-atom.
      testing = import (lib-atom-source + "/internal/testing") {
        inherit inputs root systems;
        atom = atomFor;
        lib-atom = lib-atom.lib;
      };
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
        inherit systems;
        imports = [
          inputs.git-hooks.flakeModule
          inputs.treefmt-nix.flakeModule
          inputs.atom-data-formats.flakeModules.default
          inputs.atom-markdown.flakeModules.default
          inputs.atom-nix.flakeModules.default
          inputs.atom-shell.flakeModules.default
          inputs.atom-text.flakeModules.default
          (atomFor { }).flakeModules.default
          # Every file under nix/ is a flake-parts module.
          (inputs.import-tree ./nix)
        ];
        _module.args = {
          inherit root testing;
          inherit (testing) facts fixture;
        };
      };
}
