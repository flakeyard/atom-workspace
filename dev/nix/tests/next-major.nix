# The warning of the next major version (FY-0038).
{ testing, ... }:
{
  perSystem = testing.next-major {
    output = [
      "devShells"
      "default"
    ];
    # Restated: the text is the interface (FY-0035).
    message =
      "atom-workspace: version 1 is coming with breaking changes;"
      + " support of this major version ends 6 months after its first release."
      + " Migration guide: https://github.com/flakeyard/atom-workspace/blob/main/docs/migration/v1.md";
  };
}
