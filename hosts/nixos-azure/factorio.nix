{ inputs, config, ... }:
{
  imports = [ inputs.factorio.nixosModules.default ];

  services.factorio-server = {
    enable = true;
    username = "bloodfox";
    token = "{factorio-pull-from-web-secret}";
  };
}
