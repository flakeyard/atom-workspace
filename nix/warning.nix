# The warning of FY-0016 that the next major version is coming, given while
# the file nix/next-major.nix exists (FY-0038). That file holds
# { version = <next major version>; guide = "<path of its migration guide>"; }.
{ lib, file }:
value:
if builtins.pathExists file then
  let
    next = import file;
  in
  lib.warn (
    "atom-workspace: version ${toString next.version} is coming with breaking changes;"
    + " support of this major version ends 6 months after its first release."
    + " Migration guide: https://github.com/flakeyard/atom-workspace/blob/main/${next.guide}"
  ) value
else
  value
