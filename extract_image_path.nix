{
  runCommand,
  pandoc,
  lib,
}:

file:
runCommand "extract_image_path"
  {
    preferLocalBuild = true;
    allowSubstitutes = false;
  }
  ''
    ${lib.getExe pandoc} --to=json \
                         --output=$out \
                         ${file}
  ''
