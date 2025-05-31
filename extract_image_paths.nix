{
  runCommand,
  pandoc,
  lib,
}:

file:
let
  json =
    runCommand "md2json"
      {
        preferLocalBulid = true;
        allowSubstitutes = false;
      }
      ''
        ${lib.getExe pandoc} --to=json \
                             --output=$out \
                             ${file}
      '';

  doc = lib.traceVal (with builtins; fromJSON (readFile json));

  filterFigure =
    blocks:
    lib.traceVal (
      builtins.filter # /
        (e: e.t == "Figure")
        blocks
    );

  extractImagePathFromBlock =
    entry:
    let
      imContThrid = builtins.elemAt entry.c 2;
      imContThridObj = builtins.head imContThrid;
      imContThridObjCont = builtins.head imContThridObj.c;
      imContThridObjContThrid = builtins.elemAt imContThridObjCont.c 2;
      imPath = builtins.head imContThridObjContThrid;
    in
    imPath;

  picPaths =
    map (x: extractImagePathFromBlock x) # /
      (filterFigure doc.blocks);
in
picPaths
