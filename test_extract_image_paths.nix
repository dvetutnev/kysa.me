{
  pkgs ? import <nixpkgs> { },
}:

with pkgs;
let
  extractImagePaths = callPackage ./md2json.nix { };
  testMarkdown = writeTextDir "test.md" ''
    ![pic](dir/pic.png)

    ![pic2](d/n/image.jpg)

    # Header
  '';
  expectedArray = [
    "dir/pic.png"
    "d/n/image.jpg"
  ];
in
testers.testEqualContents {
  assertion = "Check extractImagePaths";
  expected = writeText "expected" (builtins.toJSON expectedArray);
  actual = writeText "actual" (builtins.toJSON (extractImagePaths "${testMarkdown}/test.md"));
}
