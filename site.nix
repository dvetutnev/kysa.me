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
    import ./mk_html.nix
      {
        inherit
          lib
          removeCurrentDirPrefix
          pandoc
          runCommand
          ;
      }
      {
        cssArgs = css.args;
        inherit sideBar;
      };

  sideBar = mkSideBar siteUrl;

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
