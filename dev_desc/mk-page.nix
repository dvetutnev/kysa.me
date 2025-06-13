{
  callPackage,
  runCommandLocal,
  pandoc,
  makeFontsConf,
  lib,
}:

{ path, prefix }:
let
  stripPrefix = callPackage ./strip-prefix { };

  destName = builtins.replaceStrings [ ".md" ] [ ".html" ] (stripPrefix {
    inherit path prefix;
  });

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
                             --to=html5 \
                             --output="$target" \
                             --verbose \
                             ${path}
      '';
in
html
