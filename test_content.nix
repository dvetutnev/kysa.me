{
  pkgs ? import <nixpkgs> { },
}:
with pkgs;
with builtins;
let
  traceVal = lib.fileset.traceVal;
  contentPath = ./content;

  #  stripPrefix =
  #    path: prefix:
  #    let
  #      withoutPathPrefix = lib.path.removePrefix prefix path;
  #      withoutPrefix = lib.strings.removePrefix "./" withoutPathPrefix;
  #    in
  #    withoutPrefix;

  src = lib.fileset.toList contentPath;

  stripPrefix = callPackage ./strip-prefix { };

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
