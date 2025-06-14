{
  pkgs ? import <nixpkgs> { },
}:
with pkgs;
let
  testEqualContents = testers.testEqualContents;
  recurseIntoAttrs = lib.recurseIntoAttrs;

  contentPrefix = ./test_content;

  stripPrefix = callPackage ../strip-prefix { };
  addFile = callPackage ./. { inherit stripPrefix; };
in
recurseIntoAttrs {
  testRoot =
    let
      file = lib.path.append contentPrefix "file.md";
    in
    testEqualContents {
      assertion = "root";
      expected = writeTextDir "file.md" (builtins.readFile file);
      actual = addFile {
        path = file;
        prefix = contentPrefix;
      };
    };

  testNested =
    let
      file = lib.path.append contentPrefix "pages/about.md";
    in
    testEqualContents {
      assertion = "nested";
      expected = writeTextDir "pages/about.md" (builtins.readFile file);
      actual = addFile {
        path = file;
        prefix = contentPrefix;
      };
    };
}
