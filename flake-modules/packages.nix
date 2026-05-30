{
  perSystem = { system, pkgs, ... }: {
    packages = import ../packages { inherit pkgs system; };
  };
}
