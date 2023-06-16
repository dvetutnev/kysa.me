{ lib
, fetchPypi
, python3
, python3Packages
}:

with python3.pkgs;
buildPythonApplication rec {
  pname = "blag";
  version = "2.0.0";
  format = "pyproject";

  src = fetchPypi {
    inherit pname version;
    sha256 = "V/CGKtcKVKY0ejAx1FVWERuEbPcHcHIhqZTna7qBckA=";
  };

  nativeBuildInputs = with python3Packages; [
    setuptools
  ];

  propagatedBuildInputs = with python3Packages; [
    markdown
    feedgenerator
    jinja2
    pygments
  ];

  nativeCheckInputs = with python3Packages; [
    pytestCheckHook
    pytest-cov
  ];

  meta = with lib; {
    description = "blag is a blog-aware, static site generator, written in Python.";
    homepage = "https://blag.readthedocs.io/";
    changelog = "https://github.com/venthur/blag/blob/master/CHANGELOG.md";
    license = licenses.mit;
  };
}
