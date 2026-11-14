# The shell hook of devShells.default installs the git hooks: in a git
# repository in the sandbox, it links the configuration of pre-commit, installs
# the hook pre-commit and points core.hooksPath at the hooks of the
# repository.
{ fixture, inputs, ... }:
{
  perSystem =
    { pkgs, system, ... }:
    let
      flake = fixture {
        modules = [
          inputs.git-hooks.flakeModule
          # The sandbox has no store to register a root with.
          { perSystem.pre-commit.settings.addGcRoot = false; }
        ];
      };
      inherit (flake.allSystems.${system}.pre-commit.settings) configFile;
    in
    {
      checks.test-install =
        pkgs.runCommand "test-install"
          {
            nativeBuildInputs = [ pkgs.gitMinimal ];
            shellHook = flake.devShells.${system}.default.shellHook;
            passAsFile = [ "shellHook" ];
          }
          ''
            export HOME=$TMPDIR PRE_COMMIT_HOME=$TMPDIR/pre-commit
            git init --quiet project
            cd project
            source "$shellHookPath"
            [[ $(readlink .pre-commit-config.yaml) == ${configFile} ]]
            [[ -x .git/hooks/pre-commit ]]
            grep -q pre-commit .git/hooks/pre-commit
            [[ $(git config core.hooksPath) == .git/hooks ]]
            touch $out
          '';
    };
}
