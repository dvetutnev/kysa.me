{
  removeCurrentDirPrefix,
  runCommand,
  pandoc,
  lib,
}:

{
  cssArgs,
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
        inherit cssArgs sideBar;
      };
in
mkHTML file
