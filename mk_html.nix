{
  runCommand,
  pandoc,
  plantuml,
  pandoc-plantuml-filter,
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
    nativeBuildInputs = [
      plantuml
      pandoc-plantuml-filter
    ];
  }
  ''
     target=$out/${lib.escapeShellArg name}
     mkdir -p "$(dirname "$target")"
     mkdir d
     ${lib.getExe pandoc} --standalone \
                          --template=${template} \
                          --to=html5 \
                          --output="$target" \
                          ${cssArgs} \
                          --variable=include-before:${lib.escapeShellArg sideBar} \
                          --title-prefix=${lib.escapeShellArg titlePrefix} \
                          ${file} \
                          --filter pandoc-plantuml \
                          --extract-media=d \
                          --verbose
    echo "$PWD"
    ls -la
    ls -la /build/d/
    if [ -d "/build/d/plantuml-images" ]; then
       echo "Exists plantuml-images"
       ls -la /build/d/plantuml-images/
    else
      echo "No plantuml-images"
    fi

    echo 21
  ''
