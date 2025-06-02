{
  removeCurrentDirPrefix,
  addFile,

  callPackage,
  runCommand,
  pandoc,
  symlinkJoin,

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

  extractImagePaths = callPackage ./extract_image_paths.nix { };

  paths = extractImagePaths file;
in
symlinkJoin {
  name = builtins.toString file;
  paths =
    [
      (mkHTML file)
    ] # /
    ++ map (p: addFile (./. + "/${p}")) paths;
}
