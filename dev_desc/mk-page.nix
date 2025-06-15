{
  stripPrefix,

  runCommandLocal,
  pandoc,
  makeFontsConf,
  lib,
}:

{ cssLinks, sideBar }:

{ path, prefix }:
let
  destName = builtins.replaceStrings [ ".md" ] [ ".html" ] (stripPrefix {
    inherit path prefix;
  });

  template = ./default.html5;

  mkCmdArg = link: lib.escapeShellArg "--css=${link}";
  cssArgs = lib.concatStringsSep " " (map mkCmdArg cssLinks);

  html =
    runCommandLocal destName
      {
        nativeBuildInputs = [ pandoc ];
        FONTCONFIG_FILE = makeFontsConf { fontDirectories = [ ]; };
      }
      ''
        target=$out/${lib.escapeShellArg destName}
        mkdir -p "$(dirname "$target")"
        HOME="$(mktemp -d)" # for fontconfig

        ${lib.getExe pandoc} --standalone \
                             --template=${template} \
                             --to=html5 \
                             --output="$target" \
                             ${cssArgs} \
                             --variable=include-before:${lib.escapeShellArg sideBar} \
                             --verbose \
                             ${path}
      '';
in
html
