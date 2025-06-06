{
  pkgs ? import <nixpkgs> { },
}:

let
  runTests = pkgs.lib.runTests;
  collectImages = import ./.;

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
              t = "Space";
            }
            {
              t = "Image";
              c = "pic4.jpg";
            }
          ];
        }
      ];
    }
    {
      t = "Figure";
      c = [
        [ ]
        [ ]
        [ ]
        [
          {
            t = "Plain";
            c = [
              {
                t = "Image";
                c = "pic_fig.png";
              }
            ];
          }
        ]
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
        c = "pic3.jpg";
      }
      {
        t = "Image";
        c = "pic4.jpg";
      }
      {
        t = "Image";
        c = "pic_fig.png";
      }
    ];
  };
}
