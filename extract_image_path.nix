{ runCommand, pandoc }:

let
  file = ./t.md;
in
runCommand "extract_image_path"
  {
    preferLocalBuild = true;
    allowSubstitutes = false;
  }
''
${lib.getExe pandoc} --to=json \
                     --output=$out
                     ${file}
'';
