{ stdenv, fetchFromGitHub, cmake, curl, pkg-config, qt5Full }:
stdenv.mkDerivation {
  name = "simc";
  src = fetchFromGitHub {
    owner = "simulationcraft";
    repo = "simc";
    rev = "8a2bf5fb29d3b83ea8d864825b4c6f58981bf8bb";
    sha256 = "sha256-opJex9wFSd2zuZCNqdVn5AExhvW3+AUD39X89C7umYw=";
  };
  nativeBuildInputs = [ curl cmake pkg-config qt5Full ];
  buildPhase = ''
    cmake ../ -DBUILD_GUI=OFF
  '';
}
