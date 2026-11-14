# facts pkgs name facts: a check that fails and names every fact, an
# attribute set of descriptions to booleans, that is false.
{
  _module.args.facts =
    pkgs: name: facts:
    let
      false' = builtins.attrNames (pkgs.lib.filterAttrs (_: fact: !fact) facts);
    in
    pkgs.runCommand name { } (
      if false' == [ ] then
        "touch $out"
      else
        ''
          printf 'false: %s\n' ${pkgs.lib.escapeShellArgs false'} >&2
          exit 1
        ''
    );
}
