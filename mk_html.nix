{
  runCommand,
  pandoc,
  lib,
  removeCurrentDirPrefix,
}:

{
  cssArgs,
  sideBar,
  titlePrefix ? "kysa.me",
}:

file:
let
  template = ./default.html5;
  name = builtins.replaceStrings [ ".md" ] [ ".html" ] (removeCurrentDirPrefix file);
  drvName = builtins.replaceStrings [ "/" ] [ "-" ] name;

in
runCommand drvName
  {
    preferLocalBuild = true;
    allowSubstitutes = false;
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
