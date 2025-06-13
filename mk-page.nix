{
  stripPrefix,
  addFile,

  callPackage,
  runCommandLocal,
  lib,
  pandoc,
  symlinkJoin,
  plantuml,
  pandoc-plantuml-filter,
  makeFontsConf,
}:

{
  siteUrl,
  cssLinks,
  sideBar,
  titlePrefix ? "kysa.me",
  lang ? "ru-RU",
}:

{ path, prefix }:
let
  destName = builtins.replaceStrings [ ".md" ] [ ".html" ] (stripPrefix {
    inherit path prefix;
  });

  html =
    let
      template = ./default.html5;
      relative2absolute-links = ./relative2absolute-links.lua;

      mkCmdArg =
        x:
        let
          link =
            if
              lib.strings.hasPrefix "http" x # /
            then
              x
            else
              siteUrl + x;
        in
        lib.escapeShellArg "--css=${link}";

      cssArgs = lib.concatStringsSep " " (map mkCmdArg cssLinks);
    in
    runCommandLocal destName
      {
        nativeBuildInputs = [
          pandoc
          plantuml
          pandoc-plantuml-filter
        ];

        FONTCONFIG_FILE = makeFontsConf { fontDirectories = [ ]; };
        SITE_URL = siteUrl;
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
                              --title-prefix=${lib.escapeShellArg titlePrefix} \
                              --metadata=lang:${lang} \
                              --lua-filter=${relative2absolute-links} \
                              --filter pandoc-plantuml \
                              --verbose \
                              ${path}

        if [ -d "plantuml-images" ]; then
           echo "Install plantuml images"
           find plantuml-images -type d -exec install -d -m 755 {} $out/{} \;
           find plantuml-images -type f -name '*.png' -exec install -m 644 {} $out/{} \;
        fi
      '';
  extractImageLinks = callPackage ./extract-image-links { };
  imageLinks = extractImageLinks path;
  imageDrvs = map (
    p:
    addFile {
      path = (prefix + "/${p}");
      inherit prefix;
    }
  ) imageLinks;
in
symlinkJoin {
  name = destName;
  paths = [
    html
  ] ++ imageDrvs;
}
