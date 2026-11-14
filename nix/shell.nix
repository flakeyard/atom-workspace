# workspace.shell and devShells.default: the development shell of every
# devShells.flakeyard-* fragment, with their environment variables and at
# most one compiler, which installs the git hooks of git-hooks.nix when the
# project imports it (FY-0017).
{ flake-parts-lib, self, ... }:
{
  _file = ./shell.nix;

  options.perSystem = flake-parts-lib.mkPerSystemOption (
    { lib, ... }:
    {
      options.workspace.shell = lib.mkOption {
        type = lib.types.package;
        readOnly = true;
        description = ''
          The shell that atom-workspace builds: the base of devShells.default
          for a project that defines its own.
        '';
      };
    }
  );

  config.perSystem =
    {
      config,
      options,
      pkgs,
      ...
    }:
    let
      inherit (pkgs) lib;
      warning = import ./warning.nix {
        inherit lib;
        file = ./next-major.nix;
      };
      hooks = options ? pre-commit;
      # Every fragment, also devShells.flakeyard-project of the project.
      fragments = lib.filterAttrs (name: _: lib.hasPrefix "flakeyard-" name) config.devShells;
      # The variables of passthru.flakeyard.env of every fragment, each with
      # the fragment that sets it.
      variables = lib.mapAttrsToList (
        name: shell: lib.mapAttrs (_: value: { inherit name value; }) (shell.passthru.flakeyard.env or { })
      ) fragments;
      # One value per variable; different values fail.
      merge =
        variable: definitions:
        let
          values = lib.unique (map (definition: toString definition.value) definitions);
        in
        if lib.length values == 1 then
          lib.head values
        else
          throw (
            "atom-workspace: the fragments set ${variable} to different values:"
            + lib.concatMapStrings (
              definition: "\n  ${definition.name} = ${builtins.toJSON (toString definition.value)}"
            ) definitions
          );
      # The fragments that bring a compiler, and their distinct stdenvs;
      # derivations are equal when their outputs are.
      compilers = lib.attrNames (lib.filterAttrs (_: shell: (shell.stdenv.cc or null) != null) fragments);
      stdenvs = lib.unique (map (name: fragments.${name}.stdenv) compilers);
      mkShell =
        if stdenvs == [ ] then
          pkgs.mkShellNoCC
        else if lib.length stdenvs == 1 then
          pkgs.mkShell.override { stdenv = lib.head stdenvs; }
        else
          throw (
            "atom-workspace: the fragments bring more than one compiler:"
            + lib.concatMapStrings (
              stdenv:
              "\n  ${
                lib.concatStringsSep ", " (lib.filter (name: fragments.${name}.stdenv == stdenv) compilers)
              }: ${stdenv.cc.name}"
            ) stdenvs
          );
      shell = mkShell (
        {
          inputsFrom = lib.attrValues fragments;
          env = lib.zipAttrsWith merge variables;
        }
        // lib.optionalAttrs hooks {
          # The tool of the hooks, as the shellHook of git-hooks.nix adds it.
          packages = [ config.pre-commit.settings.package ];
          shellHook = config.pre-commit.installationScript;
        }
      );
    in
    {
      workspace.shell =
        # git-hooks.nix links its configuration there and refuses to install
        # the hooks over a file.
        if hooks && builtins.pathExists (self.outPath + "/.pre-commit-config.yaml") then
          throw ''
            atom-workspace: .pre-commit-config.yaml is committed, and git-hooks.nix
              links its own there; remove it from git and add it to .gitignore.''
        else
          warning shell;
      devShells.default = lib.mkOverride 900 config.workspace.shell;
    };
}
