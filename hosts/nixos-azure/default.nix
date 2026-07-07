{ inputs, lib, outputs, pkgs, ... }:
{
  imports = [
    ./hardware-configuration.nix
    inputs.home-manager.nixosModules.home-manager
  ];

  home-manager.extraSpecialArgs = {
    inherit inputs outputs;
  };

  nixpkgs = {
    overlays = lib.mkDefault outputs.lib.overlayList;
    config.allowUnfree = lib.mkDefault true;
  };

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = lib.mkForce "no";
      X11Forwarding = false;
    };
  };

  systemd.tmpfiles.rules = [
    "d /opt 0755 root root"
  ];

  programs.zsh.enable = lib.mkDefault true;
  programs.nix-ld.enable = lib.mkDefault true;

  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;
  home-manager.users.sspeaks = { ... }: {
    imports = [ ../../home/sspeaks-bare.nix ];
  };

  security.sudo.wheelNeedsPassword = false;

  users.mutableUsers = lib.mkOverride 999 false;
  users.users.sspeaks = {
    isNormalUser = lib.mkOverride 999 true;
    shell = lib.mkOverride 999 pkgs.zsh;
    extraGroups = lib.mkOverride 999 [ "wheel" "input" ];
    hashedPassword = lib.mkOverride 999 "!";
    openssh.authorizedKeys.keys = [
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC69N60R8Op+ds2m9gDtfF4Kvol8dZQPEBJ9XFivfAUUj7BmNfQg4l4w+sXxaTuUnwacWYLfnCXP1kssKH/K+8ZK+/cvjQ+iBKG8Qt0yEsfogH1yREWHChelqLFgPywWH7oFURp05sdGq+hVrMX0djkl1xQ95QOAWryNb0nOY0P0lZ40Pb/iyXWtlqAWMGmuB/3k92p2Lt/qXItWrVumok4SV+jDlCTojuvAZL1e07UvoU6e6V6IOXRtnn1+6gYnSK4SL4nHZIjeMctFpUqvzJGrYGymNYeACQiuEDXvp89HqigTZH3gJdppjBlHiX+RUZ7f0PjvI8JL+mTCcFNQUVD"
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDoeR5btP9aI6DfjNE0yQGBpGWgkL/Po5NW5xWgUxWTUkA7c69HIoJgO4oOsohvZXhhFjb1AXCG8aNgqFw+0Tp3UFM55MXfmx6OP7HwWL5/01mUHz1/BAh0ythvYvOzLCPxbY54w2jhQlFo4i91dTNz4ENX294L8Kne3PhH7TBkyJrsjnN3InBK3qEdwI06VKJAj33i0vrygjhMRn5T4ZYyQ35bSNeII95wmKfP/lTlWJFhxhk23rhoEBNe8s0arnnlX0OGTOrLq6N8QpfVLpIkhNyDnXg2LcjTIF1eqRlSXXLOZweirLKE91xR6XzA+dMRPeJuEZYvxhTQtA0kJhqp"
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCwUcujpjx453KzHN6KqLUXZ6OOtfAIhVLe/1c82fm/Tpjh1g93CHw+UlbQJPb/R6+bbXlyWF1kjUGJEeVX9F048VNltUJashsmQtzdxmB2WHyOzBEaVTuEgKnZJXr353Yajg8vo6t0q/n9ZyTh9X+oHW1X2yPCDi0RzQ6yGUYJ/5WiShKzgLWPzn/PdzsvlFLlk8tyOkA7cGxhQTryWKjx7Lc3G5FfZ1hEj9r29R135FXEZkYaEmWVYSgURhUBwC1Klvsp8Bj/rXAd5CVyXSKjWRNw8OaqKr72Dl2J9hoC/XgOgGlL29Xb4c6HVGZW3a/udlnLwyw/C4ynqrABSw+Pt5+1NNLirKbCQfgEOyXtJOD/dJLcqSXYDk/Xj79D8SH0Zl+PV1diDqtVX13JXj1kYM00anEwqLM+e0PnFq+dtHdudJOEHIYDW5iqeHoxTO/WFvaetMaS67UKV5H9c4P+8kFws///sE49aL0m0+plYCRLwQFT+TfImFc/9xYgqUU="
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDC78YTLful5gTbzdbO15Rx7XePaGtxj3nyt1QVrS9/BnlJDeE1J1ah+H4Fh0WvIN6HfgjU54EFTZ07/5A/qmVJWRAnBWBxzMaQNFMKrOZaApTjZWxFPQMa49dMPQ+m5qFpLc2RBqJNE35OBJONDeXYgtlh+ym1BGIenQsxpQ67vsV0vBXtpIi9VjUVj+1Ni0p4s6tUQL5+PBTItKtJt+yhpEA8fThLjgVJC44sCaS7R6SB9gmdLHeaKp9ZS7KTHB+rwvZl4xiek9Hel4/fHjGgbM/aWSR0HzNsFaO/0+vRORHyF4GLtaQZlqoEziuOsDtsBfBfRcbeIqCBCxXV5MHViC70ZQZClpsLReXE2xmwYcWFrWly1pWvgl3WiDGkB4mqCf/pTVGI5jk7HViv2WFUBak1UjJAigHNPIEgS3z9Hd/Qzvcycuo4P5ZV49aWdj4GTHS38ekhMU5JS1zlQFUyasDhgDwqmT/dOmQ959GmN8vDesWp+ljx+3V3jhyrGNE="
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC+ZOxlbIpvXB6NDFUqX2OGGbEyIfA+7Zd6mxq78e5abuYD80bMyJdAS1H/05oBKFI5zV45Bb39DXV9HHxVJXVKQ35bs3sfrf6myTK94grgHbCn3o0pru+PsdtXBnCjsC8EMS9pua17ZPyLgCy1jYxGocCoYpxZoP1CLV+LkHauL2IxXAvZkU+W7pHgphF1jnUNjEl52TY++W5BfEJ6xvCUKj7xDMyXpAmNNdpohFpL2ughbdkL5F8s7O/RQFfzh7O13hWlbdgLHMOcoA3tuLSd5pTZjHvqEs0n1CLT/SnvONtD9uNUMGdLGisMydRVFYmOOJ9LxF1pdEvowExbMvAEa0a7nFLASnmnxqzL1lbFxvUQ5p55s3CO4y1B72lpIRRAwuvOUBrpHw83zq6FQ8Z0C2bbmJa/YFOPre6GPw6WbnvUhsYegvxBEHFPUf5zFBqzZGfjbneRptexq8Yl7vtbXP3jyRMj59IumRBOAKHXQj/6fxo4n3WnkiXGmaWh2pk="
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQC0XL/A/LJGYwiVh/WZaE8cmSBvPJU878PDTRaPV4ixuz5mT9E2Y+hlrP9eQm4SvznjD8TqaSwAgNlE1BfOFlBZ5UjRlOdDfSSSM9MjxLda+TTwFntRum+3irjFLwAzP1O4HCtavxdvJPpZWdVuR6Ku8WH+9Ls30Kp0SzouGkHVSD2udEQm6yFWfSYfMNEfFzg04SRovLkz3NQpEo8evgbxiNYT7pa0m4RMd7VohJn8H/P7Fl7xeEEJdLNKLPEnyxTK0ZH+hPnoNtPqLp+oz8xqefGtvl8ff9cPvXnz2jIS3b6PR+MGEV6eQIOtKuEDCIx3b0kdoSWY9OeglB9eoAl7mUKKZGpH6pKgCLf7QZUL3QSh3jUxp/jZD2TxdKXd0ejBz4DC9CNIvuu95sDnWmwnch+lJU4ObtXW44Xlfal+SYDSD88GYqwFwPhPakFTRhlncoOh2FL7TUcaiopUhYRl8bg+H1yfC0oiciUrT9HC4Jxp0xR/KLwfymFccWObr1c= sspeaks@Seths-MacBook-Pro.local"
    ];
  };

  system.stateVersion = "23.05";
  time.timeZone = "America/Los_Angeles";
}
