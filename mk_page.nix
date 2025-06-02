{
  removeCurrentDirPrefix,
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
    import ./mk_html.nix
      {
        inherit
          lib
          removeCurrentDirPrefix
          pandoc
          runCommand
          ;
      }
      {
        inherit css siteUrl sideBar;
      };
in
mkHTML file
