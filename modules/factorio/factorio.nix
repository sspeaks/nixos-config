{ pkgs, lib, ... }:
let
  version = "1.1.69";
  unfreePredicate = (pkg: builtins.elem (lib.getName pkg) [
    "factorio-headless"
  ]);

  fPack = import (fetchTarball "https://github.com/NixOS/nixpkgs/archive/9e10ba3ee8b8fb43b7419e90144c530a62876527.tar.gz") { config = { allowUnfreePredicate = unfreePredicate; }; };
  newerHeadlessVersion = (fPack.factorio-headless-experimental.override {
    username = "Bloodfox";
    token = "01f47125ee5540cc4d4d15599c57d7";
  }).overrideAttrs (old: {
    name = "factorio-headless-experimental";
    src = pkgs.fetchurl {
      name = "factorio_headless_x64-${version}.tar.xz";
      sha256 = "sha256-g8Nd1uXrbRDxuet4WGuWo7AqrOXtGMhn0Gihb72/+uU=";
      url = "https://factorio.com/get-download/${version}/headless/linux64";
    };
  });


  # Mods
  #factoryplanner_1.1.59.zip
  #flib_0.11.2.zip
  #MaxRateCalculator_3.4.48.zip
  #Nanobots_3.2.19.zip
  #stdlib_1.4.7.zip
  modFolder = "/home/sspeaks/factorio-mods";

  mkDer = f: pkgs.stdenv.mkDerivation {
    name = with builtins; (elemAt (split "\\." (baseNameOf f)) 0);
    src = builtins.path { path = modFolder; };
    buildPhase = ''
      mkdir -p $out
      cp ${builtins.baseNameOf f} $out
    '';
    dontInstall = true;
    deps = [ ];
    optionalDeps = [ ];
    recommendedDeps = [ ];
  };


  stdEnv = mkDer "stdlib_1.4.7.zip";
  flib = mkDer "flib_0.11.2.zip";
  fPlan = (mkDer "factoryplanner_1.1.59.zip").overrideAttrs (f: p: { deps = [ flib ]; });
  mRate = mkDer "MaxRateCalculator_3.4.48.zip";
  nano = (mkDer "Nanobots_3.2.19.zip").overrideAttrs (f: p: { deps = [ stdEnv ]; });

  # listMods = with builtins; let dict = attrNames (readDir modFolder); in map (n: "${modFolder}/${n}") dict;
  # myMods = with builtins; map mkDer listMods;
  myMods = [ stdEnv flib fPlan mRate nano ];

in
{
  services.factorio = {
    enable = true;
    admins = [ "bloodfox" ];
    openFirewall = true;
    loadLatestSave = true;
    game-name = "Engineering Nerds Factorio Server";
    description = "Factorio server for Daisy and Bluff";
    mods = myMods;
    package = newerHeadlessVersion;
  };
}
