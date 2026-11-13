# devShells.default: the packages, variables and compiler of every
# devShells.flakeyard-* fragment, the hooks of git-hooks.nix, the error for a
# committed .pre-commit-config.yaml, and a devShells.default of the project
# wins.
{
  facts,
  fixture,
  inputs,
  root,
  ...
}:
{
  perSystem =
    { pkgs, system, ... }:
    let
      inherit (pkgs) lib;
      # A module that adds the shell made by shell pkgs as devShells.<name>.
      shell = name: make: {
        perSystem =
          { pkgs, ... }:
          {
            devShells.${name} = make pkgs;
          };
      };
      noCC =
        name: packages: env:
        shell name (
          pkgs:
          pkgs.mkShellNoCC {
            packages = map (package: pkgs.${package}) packages;
            passthru.flakeyard = { inherit env; };
          }
        );
      gcc = name: shell name (pkgs: pkgs.mkShell { });
      clang = name: shell name (pkgs: pkgs.mkShell.override { stdenv = pkgs.clangStdenv; } { });
      default = modules: (fixture { inherit modules; }).devShells.${system}.default;
      evaluates = modules: (builtins.tryEval (default modules).drvPath).success;
      # By name: mkDerivation puts the dev output of a package there.
      has =
        package: shell: lib.elem pkgs.${package}.name (map (input: input.name) shell.nativeBuildInputs);

      composed = default [
        (noCC "flakeyard-a" [ "hello" ] { FOO = "1"; })
        (noCC "flakeyard-project" [ "cowsay" ] { BAR = "2"; })
        (noCC "other" [ "jq" ] { BAZ = "3"; })
      ];
      compiled = default [
        (noCC "flakeyard-a" [ ] { })
        (gcc "flakeyard-b")
      ];
      hooks = fixture { modules = [ inputs.git-hooks.flakeModule ]; };
      inherit (hooks.allSystems.${system}) pre-commit;
      own = default [
        (noCC "flakeyard-a" [ "hello" ] { FOO = "1"; })
        {
          perSystem =
            { config, pkgs, ... }:
            {
              devShells.default = config.workspace.shell.overrideAttrs (old: {
                nativeBuildInputs = old.nativeBuildInputs ++ [ pkgs.jq ];
              });
            };
        }
      ];
      committed =
        modules:
        (builtins.tryEval
          (fixture {
            inherit modules;
            source = root + "/dev/fixtures/committed-config";
          }).devShells.${system}.default.drvPath
        ).success;
    in
    {
      checks.test-shell = facts pkgs "test-shell" {
        "the packages of every fragment" = has "hello" composed && has "cowsay" composed;
        "no packages of other shells" = !has "jq" composed;
        "the variables of every fragment" = composed.FOO == "1" && composed.BAR == "2";
        "no variables of other shells" = !(composed ? BAZ);
        "no compiler from fragments without one" = composed.stdenv.cc == null;
        "the same value of a variable twice" = evaluates [
          (noCC "flakeyard-a" [ ] { FOO = "1"; })
          (noCC "flakeyard-b" [ ] { FOO = "1"; })
        ];
        "different values of a variable fail" =
          !evaluates [
            (noCC "flakeyard-a" [ ] { FOO = "1"; })
            (noCC "flakeyard-b" [ ] { FOO = "2"; })
          ];
        "the compiler of a fragment" = compiled.stdenv == pkgs.stdenv;
        "the same compiler twice" = evaluates [
          (gcc "flakeyard-a")
          (gcc "flakeyard-b")
        ];
        "two compilers fail" =
          !evaluates [
            (gcc "flakeyard-a")
            (clang "flakeyard-b")
          ];
        "the tool of the hooks" =
          lib.elem pre-commit.settings.package
            hooks.devShells.${system}.default.nativeBuildInputs;
        "the hooks installed" =
          hooks.devShells.${system}.default.shellHook == pre-commit.installationScript;
        "no tool and no hooks without git-hooks.nix" =
          (default [ ]).shellHook == "" && (default [ ]).nativeBuildInputs == [ ];
        "a committed .pre-commit-config.yaml fails" = !committed [ inputs.git-hooks.flakeModule ];
        "a committed .pre-commit-config.yaml without git-hooks.nix" = committed [ ];
        "the devShells.default of the project wins" = has "jq" own && has "hello" own && own.FOO == "1";
      };
    };
}
