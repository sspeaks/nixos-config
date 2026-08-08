{ pkgs, ... }:
{
  # Plate XIV typography — Iosevka Nerd Font for mono/code (plate.type.mono),
  # IosevkaTerm Nerd Font for the terminal emulator (plate.type.terminal).
  # D17: JetBrainsMono and CaskaydiaCove retained as rollback path; retirement
  # deferred to the batch that decommissions Hyprland.
  home.packages = [
    pkgs.nerd-fonts.iosevka # "Iosevka Nerd Font"
    pkgs.nerd-fonts.iosevka-term # "IosevkaTerm Nerd Font"
    pkgs.nerd-fonts.jetbrains-mono # D17 rollback — do not remove in batch 1
    pkgs.nerd-fonts.caskaydia-cove # D17 rollback — do not remove in batch 1
  ];

  fonts.fontconfig.enable = true;
}
