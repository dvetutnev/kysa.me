{
  removeCurrentDirPrefix,
  callPackage,
  runCommand,
  pandoc,
  lib,
}:

{
  css,
  siteUrl,
  sideBar,
}:

file:
let
  mkHTML =
    callPackage ./mk_html.nix
      {
        inherit removeCurrentDirPrefix;
      }
      {
        inherit css siteUrl sideBar;
      };
in
mkHTML file
