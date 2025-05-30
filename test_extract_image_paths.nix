{
  pkgs ? import <nixpkgs> { },
}:

with pkgs;
let
  extractImagePaths = callPackage ./extract_image_paths.nix { };
  testMarkdown = writeText "md" ''
    ![pic](dir/pic.png)
    ![pic2](d/n/image.jpg)
  '';
  expectedArray = [
    "fake.jpg"
  ];
in
testers.testEqualContents {
  assertion = "Check extractImagePaths";
  expected = writeText "expected" (builtins.toJSON expectedArray);
  actual = writeText "actual" (builtins.toJSON (extractImagePaths testMarkdown));
}
