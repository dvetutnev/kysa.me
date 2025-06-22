{
  runCommandLocal,
  pandoc,
  lib,
}:

file:
let
  json = runCommandLocal "md2ast" { } ''
    ${lib.getExe pandoc} --to=json \
                         --output=$out \
                         ${file}
  '';
  ast = with builtins; fromJSON (readFile json);

  collectImages = import ./collect-images;
  images = collectImages ast.blocks;

  allPaths = with builtins; map (e: head (elemAt e.c 2)) images;
  relativeImagePaths = builtins.filter (e: !lib.strings.hasPrefix "http" e) allPaths;
in
relativeImagePaths
