{
  removeCurrentDirPrefix,
  runCommand,
  pandoc,
  lib,
}:

{
  cssArgs,
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
        inherit cssArgs siteUrl sideBar;
      };
in
mkHTML file
