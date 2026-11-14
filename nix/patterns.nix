# An entry of workspace.generated and its conversions. An entry is a path from
# the root of the project: a trailing / makes it a directory, with everything
# below it, and a leading **/ matches it at any depth. Glob and regular
# expression characters are not allowed, so that an entry means the same in
# both conversions.
{ lib }:
let
  parse = entry: rec {
    anyDepth = lib.hasPrefix "**/" entry;
    path = lib.removePrefix "**/" entry;
    directory = lib.hasSuffix "/" path;
  };
in
{
  # The grammar of an entry, for builtins.match.
  grammar = ''(\*\*/)?([^]/*?[{}\]+/)*[^]/*?[{}\]+/?'';

  # An anchored regular expression for pre-commit.settings.excludes, which
  # Python's re.search and builtins.match read the same.
  regex =
    entry:
    let
      inherit (parse entry) anyDepth path directory;
    in
    "^"
    + lib.optionalString anyDepth "(.*/)?"
    + lib.escapeRegex path
    + lib.optionalString directory ".*"
    + "$";

  # The globs for treefmt.settings.excludes. treefmt matches a glob against
  # the whole path, and its * also matches /, so **/ does not match at the
  # root.
  globs =
    entry:
    let
      inherit (parse entry) anyDepth path directory;
      glob = if directory then "${path}*" else path;
    in
    [ glob ] ++ lib.optional anyDepth "**/${glob}";
}
