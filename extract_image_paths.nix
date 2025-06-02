{
  callPackage,
}:

file:
let
  md2ast = callPackage ./md2ast.nix { };
  collectImages = import ./collect_images;

  ast = md2ast file;
  images = collectImages ast.blocks;
  paths = with builtins; map (e: head (elemAt e.c 2)) images;
in
paths
