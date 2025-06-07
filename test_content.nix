{
  pkgs ? import <nixpkgs> { },
}:
with pkgs;
with builtins;
let
  traceVal = lib.fileset.traceVal;

  stripPrefix = callPackage ./strip-prefix { };

  contentPath = ./content;

  src = lib.fileset.toList contentPath;

  #  withoutStorePrefix = map (e: stripPrefix e contentPath) src;
  withoutStorePrefix = map (
    e:
    stripPrefix {
      path = e;
      prefix = contentPath;
    }
  ) src;
in
[
  src
  withoutStorePrefix
]
