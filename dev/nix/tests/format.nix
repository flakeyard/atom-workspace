# In a git repository in the sandbox: the wrapper of treefmt, run from a
# subdirectory, formats the whole project, and neither treefmt nor the git
# hooks run by pre-commit touch the generated files.
{ fixture, inputs, ... }:
{
  perSystem =
    { pkgs, system, ... }:
    let
      inherit (pkgs) lib;
      # Appends a line to every file it gets.
      mark =
        line:
        lib.getExe (
          pkgs.writeShellScriptBin "mark" ''
            for file; do echo ${line} >> "$file"; done
          ''
        );
      values =
        (fixture {
          modules = [
            inputs.git-hooks.flakeModule
            inputs.treefmt-nix.flakeModule
            {
              perSystem = {
                treefmt.settings.formatter.mark = {
                  command = mark "formatted";
                  includes = [ "*" ];
                };
                pre-commit.settings.hooks.mark = {
                  enable = true;
                  entry = mark "marked";
                };
              };
            }
          ];
        }).allSystems.${system};
      inherit (values.pre-commit.settings) configFile package;
      generated = [
        "CHANGELOG.md"
        ".release-please-manifest.json"
        "LICENSES/MIT.txt"
        "LICENSES/sub/x.txt"
        "flake.lock"
        "dev/flake.lock"
      ];
      others = [
        "a.txt"
        "dev/b.txt"
        "sub/CHANGELOG.md"
        "sub/LICENSES/x.txt"
      ];
      files = lib.escapeShellArgs (generated ++ others);
      # Fails unless every file of the list has the content.
      expect = list: content: ''
        for file in ${lib.escapeShellArgs list}; do
          if [[ $(< "$file") != "${content}" ]]; then
            echo "$file: $(< "$file")" >&2
            exit 1
          fi
        done
      '';
    in
    {
      checks.test-format =
        pkgs.runCommand "test-format"
          {
            nativeBuildInputs = [
              pkgs.gitMinimal
              values.treefmt.build.wrapper
              package
            ];
          }
          ''
            export HOME=$TMPDIR PRE_COMMIT_HOME=$TMPDIR/pre-commit
            git config --global user.name test
            git config --global user.email test@localhost
            git config --global init.defaultBranch main
            git init --quiet project
            cd project
            for file in ${files}; do
              mkdir -p "$(dirname "$file")"
              echo original > "$file"
            done
            echo /.pre-commit-config.yaml > .gitignore
            git add .
            git commit --quiet -m init

            (cd dev && treefmt --no-cache)
            ${expect generated "original"}
            ${expect others "original\nformatted"}

            git checkout --quiet .
            ln -s ${configFile} .pre-commit-config.yaml
            # It fails, since the hooks change files.
            pre-commit run --all-files || true
            ${expect generated "original"}
            ${expect others "original\nmarked\nformatted"}
            touch $out
          '';
    };
}
