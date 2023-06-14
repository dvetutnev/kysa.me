{ lib
, python3
, fetchPypi
, python3Packages
}:

with python3.pkgs;
buildPythonApplication rec {
  pname = "blag";
  version = "1.5.0";
  format = "pyproject";

  src = fetchPypi {
    inherit pname version;
    hash = "sha256-kYS/JWBIX5g2SfbW8U5VMiLl2XrCN4UVLx/cv5uwZno=";
  };

  buildInputs = with python3Packages; [
    setuptools
  ];

  propagatedBuildInputs = with python3Packages; [
    markdown
    feedgenerator
    jinja2
    pygments
  ];

  doCheck = false;

  meta = with lib; {
    description = "blag is a blog-aware, static site generator, written in Python.";
    homepage = "https://blag.readthedocs.io/";
    changelog = "https://github.com/venthur/blag/blob/master/CHANGELOG.md";
    license = licenses.mit;
  };
}
