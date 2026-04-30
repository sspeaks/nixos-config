{
  flake.overlays.default = final: prev:
    let
      applied = builtins.foldl'
        (acc: ov: acc // (ov final (prev // acc)))
        { }
        (import ../overlays.nix);
    in
    applied;
  flake.lib.overlayList = import ../overlays.nix;
}
