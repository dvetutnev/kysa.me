{
  pkgs ? import <nixpkgs> { },
}:

let
  runTests = pkgs.lib.runTests;
  collectImages = import ./collect_images.nix;

  blocks = [
    {
      t = "Image";
      c = "pic1.jpg";
    }
    {
      t = "Block";
      c = [
        1
        {
          t = "Image";
          c = "pic2.jpg";
        }
        {
          t = "Header";
          c = "tEEExt";
        }
        {
          t = "Image";
          c = "pic3.jpg";
        }
        {
          t = "Block";
          c = [
            {
              t = "Text";
              c = "text";
            }
            {
              t = "Image";
              c = "pic4.jpg";
            }
          ];
        }
      ];
    }
  ];
in
runTests {
  test2 = {
    expr = collectImages blocks;
    expected = [
      {
        t = "Image";
        c = "pic1.jpg";
      }
      {
        t = "Image";
        c = "pic2.jpg";
      }
      {
        t = "Image";
        c = "pic3.jpg";
      }
      {
        t = "Image";
        c = "pic4.jpg";
      }
    ];
  };
}
