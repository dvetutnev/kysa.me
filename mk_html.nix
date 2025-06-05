{
  removeCurrentDirPrefix,
  runCommand,
  pandoc,
  plantuml,
  pandoc-plantuml-filter,
  makeFontsConf,
  lib,
}:

{
  css,
  siteUrl,
  sideBar,
  titlePrefix ? "kysa.me",
  lang ? "ru-RU",
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

  relative2absolute-links = ./relative2absolute-links.lua;
in
runCommand drvName
  {
    preferLocalBuild = true;
    allowSubstitutes = false;
    nativeBuildInputs = [
      plantuml
      pandoc-plantuml-filter
    ];
    FONTCONFIG_FILE = makeFontsConf { fontDirectories = [ ]; };
    SITE_URL = siteUrl;
  }
  ''
     target=$out/${lib.escapeShellArg name}
     mkdir -p "$(dirname "$target")"
     HOME="$(mktemp -d)" # for fontconfig

     ${lib.getExe pandoc} --standalone \
                          --template=${template} \
                          --to=html5 \
                          --output="$target" \
                          ${cssArgs} \
                          --variable=include-before:${lib.escapeShellArg sideBar} \
                          --title-prefix=${lib.escapeShellArg titlePrefix} \
                          --metadata=lang:${lang} \
                          --lua-filter=${relative2absolute-links} \
                          --filter pandoc-plantuml \
                          --verbose \
                          ${file}

    if [ -d "plantuml-images" ]; then
       echo "Install plantuml images"
       find plantuml-images -type d -exec install -d -m 755 {} $out/{} \;
       find plantuml-images -type f -name '*.png' -exec install -m 644 {} $out/{} \;
    fi
  ''
