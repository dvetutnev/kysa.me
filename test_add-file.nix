{
  pkgs ? import <nixpkgs> { },
}:

with pkgs;
with builtins;

let
  contentPath = ./content;
  stripPrefix = callPackage ./strip-prefix { };

  src = lib.fileset.toList contentPath;
  entry = elemAt src 0;

  addFile = pkgs.callPackage ./add-file { inherit stripPrefix; }

in
addFile { path = (elemAt src 1); prefix = contentPath; }
