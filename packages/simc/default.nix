{ stdenv, lib, fetchFromGitHub, cmake, curl, pkg-config }:
stdenv.mkDerivation {
  name = "simc";
  src = fetchFromGitHub {
    owner = "simulationcraft";
    repo = "simc";
    rev = "204b88dcc30f174264531404319e9fe28f946012";
    sha256 = "sha256-aKKEYxkn/Sxey94vvsKetJeZvSVbpvEJL0x/unRL+WU=";
  };
  nativeBuildInputs = [ cmake pkg-config ];
  buildInputs = [ curl ];
  cmakeFlags = [ "-DBUILD_GUI=OFF" ];

  meta = {
    description = "SimulationCraft — World of Warcraft combat simulator";
    homepage = "https://www.simulationcraft.org/";
    license = lib.licenses.gpl3Only;
    mainProgram = "simc";
    platforms = lib.platforms.linux;
  };
}
