{
  runCommand,
  pandoc,
  lib,
}:

file:
let
  json =
    runCommand "md2ast"
      {
        preferLocalBuild = true;
        allowSubstitutes = false;
      }
      ''
        ${lib.getExe pandoc} --to=json \
                             --output=$out \
                             ${file}
      '';
  ast = with builtins; fromJSON (readFile json);

  collectImages = import ./collect_images;
  images = collectImages ast.blocks;

  paths = with builtins; map (e: head (elemAt e.c 2)) images;
in
paths
