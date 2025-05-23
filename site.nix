{
  runCommand,
  stdenv,
  writeTextDir,
  symlinkJoin,
  pandoc,
  lib,
}:
siteUrl:

let

  removeCurrentDirPrefix = import ./rm_cur_dir_prefix.nix { inherit lib; };
  addFile = import ./add_file.nix { inherit stdenv removeCurrentDirPrefix; };
  mkSideBar = import ./mk_side_bar.nix { inherit lib; };
  mkCSS = import ./mk_css.nix { inherit lib removeCurrentDirPrefix; };
  css = mkCSS siteUrl;

  mkHTML =
    file:
    let
      template = ./default.html5;
      include_before = mkSideBar siteUrl;
      name = builtins.replaceStrings [ ".md" ] [ ".html" ] (removeCurrentDirPrefix file);
      drvName = builtins.replaceStrings [ "/" ] [ "-" ] name;

    in
    runCommand drvName
      {
        preferLocalBuild = true;
        allowSubstitutes = false;
      }
      ''
        target=$out/${lib.escapeShellArg name}
        mkdir -p "$(dirname "$target")"
        ${lib.getExe pandoc} --standalone \
                             --template=${template} \
                             --to=html5 \
                             --output="$target" \
                             ${css.args} \
                             --variable=include-before:${lib.escapeShellArg include_before} \
                             ${file} \
                             --verbose
      '';

  homePage = mkHTML ./README.md;
  mkIndex =
    homePage:
    stdenv.mkDerivation {
      name = "index.html";
      buildInputs = [ homePage ];
      preferLocalBuild = true;
      allowSubstitutes = false;
      buildCommand = ''
        mkdir -p $out
        ln -s "${homePage}/${homePage.name}" $out/index.html
      '';
    };
  index = mkIndex homePage;

in
symlinkJoin {
  name = "www_root";
  paths = [
    homePage
    index
    #(page ./README.md)
    (mkHTML ./pages/about.md)
    (addFile ./dir/nix_hacking_1.png)
    (addFile ./you_are_here.png)
  ] ++ map (p: addFile p) css.paths;
}
