{ lib }:

{ path, prefix }:
let
  withoutPathPrefix = lib.path.removePrefix prefix path;
  withoutPrefix = lib.strings.removePrefix "./" withoutPathPrefix;
in
withoutPrefix
