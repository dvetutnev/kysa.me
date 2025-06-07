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

  addFile = pkgs.callPackage ./add-file { inherit stripPrefix; };
in
symlinkJoin {
  name = "www_root";
  paths =
    [ ]
    ++ map (
      p:
      addFile {
        path = p;
        prefix = contentPath;
      }
    ) src;

}
