{stdenv, fetchFromGitHub, cmake, curl, pkg-config, qt5Full }:
stdenv.mkDerivation {
  name = "simc";
  src = fetchFromGitHub {
    owner = "simulationcraft";
    repo = "simc";
    rev = "dragonflight";
    sha256 = "sha256-opJex9wFSd2zuZCNqdVn5AExhvW3+AUD39X89C7umYw=";
  };
  nativeBuildInputs = [ curl cmake pkg-config qt5Full ];
  buildPhase = ''
    cmake ../ -DBUILD_GUI=OFF
  '';
#  setSourceRoot="sourceRoot=$(echo */engine)";
}
