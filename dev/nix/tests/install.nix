# The shell hook of devShells.default installs the git hooks: in a git
# repository in the sandbox with a linked worktree, it links the configuration
# of pre-commit in the checkout it starts in, installs the hook pre-commit into
# the hooks every checkout shares and points core.hooksPath at them. A checkout
# without the link skips the hooks; one with it runs them.
{
  fixture,
  inputs,
  root,
  ...
}:
{
  perSystem =
    { pkgs, system, ... }:
    let
      flake = fixture {
        source = root;
        module.imports = [
          inputs.git-hooks.flakeModule
          {
            perSystem = {
              # The sandbox has no store to register a root with.
              pre-commit.settings.addGcRoot = false;
              # A hook that shows it ran, on every commit.
              pre-commit.settings.hooks.marker = {
                enable = true;
                entry = toString (pkgs.writeShellScript "marker" ''touch "$HOME/marker"'');
                always_run = true;
                pass_filenames = false;
              };
            };
          }
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
            export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.com
            export GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.com
            git init --quiet project
            git -C project commit --quiet --allow-empty --message initial
            git -C project worktree add --quiet ../worktree
            shared=$PWD/project/.git/hooks

            # The shell in the linked worktree: the link only there, the
            # hooks shared, core.hooksPath absolute.
            cd worktree
            source "$shellHookPath"
            [[ $(readlink .pre-commit-config.yaml) == ${configFile} ]]
            [[ ! -e ../project/.pre-commit-config.yaml ]]
            [[ -x $shared/pre-commit ]]
            grep -q -- --skip-on-missing-config "$shared/pre-commit"
            [[ $(git config core.hooksPath) == "$shared" ]]
            git commit --quiet --allow-empty --message worktree
            [[ -e $HOME/marker ]]
            rm "$HOME/marker"

            # The main checkout without the link skips the hooks.
            cd ../project
            output=$(git commit --allow-empty --message skipped 2>&1)
            grep -qF '`.pre-commit-config.yaml` config file not found. Skipping `pre-commit`.' <<<"$output"
            [[ ! -e $HOME/marker ]]

            # The shell in the main checkout: core.hooksPath relative.
            source "$shellHookPath"
            [[ $(readlink .pre-commit-config.yaml) == ${configFile} ]]
            grep -q -- --skip-on-missing-config "$shared/pre-commit"
            [[ $(git config core.hooksPath) == .git/hooks ]]
            git commit --quiet --allow-empty --message main
            [[ -e $HOME/marker ]]
            touch $out
          '';
    };
}
