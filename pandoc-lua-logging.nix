{
  stdenvNoCC,
  fetchFromGitHub,
  lib,
}:

stdenvNoCC.mkDerivation {
  name = "pandoc-lua-logging.lua";
  src = fetchFromGitHub {
    owner = "pandoc-ext";
    repo = "logging";
    rev = "v1.0.0";
    sha256 = "sha256-Atmv1bPdMIR+8HxvQnBMWd76qHy9NrL3QwxvLMaK3ks=";
  };

  dontBuild = true;
  installPhase = ''
    runHook preInstall

    install logging.lua $out

    runHook postInstall
  '';
}
