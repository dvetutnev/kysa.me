{
  pkgs ? import <nixpkgs> { },
}:

let
  md2ast = import ./md2ast.nix { };
  collectImages = import ./collect_images;

  ast = md2ast ./t.md;
  images = collectImages ast.blocks;
  paths = with builtins; map (e: head (elemAt e.c 2)) images;
in
paths
