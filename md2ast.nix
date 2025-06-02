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
in
ast
