{
  runCommand,
  pandoc,
  plantuml,
  lib,
  removeCurrentDirPrefix,
}:

{
  css,
  siteUrl,
  sideBar,
  titlePrefix ? "kysa.me",
}:

file:
let
  template = ./default.html5;

  name = builtins.replaceStrings [ ".md" ] [ ".html" ] (removeCurrentDirPrefix file);
  drvName = builtins.replaceStrings [ "/" ] [ "-" ] name;

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

  cssArgs = lib.concatStringsSep " " (map mkCmdArg css);

in
runCommand drvName
  {
    preferLocalBuild = true;
    allowSubstitutes = false;
    nativeBuildInputs = [ plantuml ];
  }
  ''
    target=$out/${lib.escapeShellArg name}
    mkdir -p "$(dirname "$target")"
    ${lib.getExe pandoc} --standalone \
                         --template=${template} \
                         --to=html5 \
                         --output="$target" \
                         ${cssArgs} \
                         --variable=include-before:${lib.escapeShellArg sideBar} \
                         --title-prefix=${lib.escapeShellArg titlePrefix} \
                         ${file} \
                         --verbose
  ''
