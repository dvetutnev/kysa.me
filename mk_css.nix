{ lib, removeCurrentDirPrefix }:

siteUrl:
let
  cssList = [
    ./css/poole.css
    ./css/syntax.css
    ./css/hyde.css
    ./css/hyde-styx.css
    "https://fonts.googleapis.com/css?family=PT+Sans:400,400italic,700|Abril+Fatface"
  ];

  mkCmdArg =
    cssPath:
    let
      res =
        if
          builtins.isPath cssPath # \
        then
          siteUrl + (removeCurrentDirPrefix cssPath)
        else
          cssPath;
    in
    lib.escapeShellArg "--css=${res}";

  args = lib.concatStringsSep " " (map mkCmdArg cssList);
in
{
  inherit args;
  paths = builtins.filter (x: builtins.isPath x) cssList;
}
