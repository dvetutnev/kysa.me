{ lib
, fetchFromGitHub
, python3
, python3Packages
}:

with python3.pkgs;
buildPythonApplication rec {
  pname = "blag";
  version = "1.5.0";
  format = "pyproject";

  src = fetchFromGitHub {
    owner = "venthur";
    repo = "blag";
    rev = "refs/tags/${version}";
    hash = "sha256-xddWsbodplh3QfkkRWEeomRzj1KpNkq/g9CrKcBEmp8=";
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
