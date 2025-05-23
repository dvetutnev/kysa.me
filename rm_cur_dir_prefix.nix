{ lib }:

filePath:
with lib;
let
  withoutPathPrefix = path.removePrefix ./. filePath;
  withoutPrefix = strings.removePrefix "./" withoutPathPrefix;
in
withoutPrefix
