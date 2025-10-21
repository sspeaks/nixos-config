{ stdenv, fetchFromGitHub, cmake, curl, pkg-config, qt5Full }:
stdenv.mkDerivation {
  name = "simc";
  src = fetchFromGitHub {
    owner = "simulationcraft";
    repo = "simc";
    rev = "26f71da0bdc55355b5ba479c6ecebcb987cdbeec";
    sha256 = "sha256-2aURkencFKA8CuxVN04vmnTURIE63jwUxouM9kOD1g0=";
  };
  nativeBuildInputs = [ curl cmake pkg-config qt5Full ];
  buildPhase = ''
    cmake ../ -DBUILD_GUI=OFF
  '';
}
