{
  pkgs ? import <nixpkgs> { },
}:
with pkgs;
let
  src = lib.fileset.toSource {
    root = ./.;
    fileset = ./content;
  };
in
runCommandLocal "testToSource"
  {
    inherit src;
  }
  ''
    echo 12
    echo "$out"
    echo "${src}"
    ls -l $src/
    ls -l $src/content/
    touch $out
  ''
