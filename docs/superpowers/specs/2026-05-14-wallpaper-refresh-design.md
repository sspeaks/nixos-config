# Wallpaper Refresh Design

## Problem

The Asahi Hyprland session starts `swaybg` once with `/var/lib/bing-wallpaper/wallpaper.jpg`. The system-level Bing wallpaper service updates that file after boot and daily, but the already-running `swaybg` process keeps displaying the image it loaded at startup. This makes the desktop background appear stuck on the previous image until the session is restarted.

## Approved scope

Refresh the visible Hyprland wallpaper automatically after the Bing wallpaper image changes.

The implementation should:

- Keep using `swaybg`, because `hyprpaper` is intentionally disabled on this host due to an Asahi crash.
- Keep the existing shared wallpaper path at `/var/lib/bing-wallpaper/wallpaper.jpg`.
- Avoid user/session control from the system-level Bing download service.
- Preserve the existing Bing wallpaper download service and timer behavior.

## Key decisions

Move wallpaper display ownership from Hyprland `exec-once` into a Home Manager user systemd service.

Add a Home Manager user systemd path unit that watches the shared wallpaper file and restarts the user `swaybg` service whenever the file changes. This keeps display refresh logic in the user session, where Wayland and Hyprland environment variables are available, while leaving the system Bing download service focused on fetching the image.

Rejected alternatives:

- Restarting `swaybg` from the system Bing service would cross user/session boundaries and depend on the active graphical session environment.
- Switching wallpaper tools would add unnecessary churn, and the most obvious Hyprland-native option is already disabled because it crashes on this Asahi setup.

## Architecture

`home/features/hyprland/startup.nix` should stop launching `swaybg` through `wayland.windowManager.hyprland.settings.exec-once`.

The same module should define:

- `systemd.user.services.swaybg`, a long-running service that executes `swaybg -i ${asahiPaths.wallpaper} -m fill`.
- `systemd.user.paths.swaybg-wallpaper`, a path unit watching `${asahiPaths.wallpaper}` and triggering the service on changes.

The `swaybg` service should be part of the graphical session so it starts and stops with Hyprland. The path unit should also be part of the graphical session so it is only active while a user session exists.

## Data flow

1. `bing-wallpaper.timer` triggers `bing-wallpaper.service` at boot and daily.
2. `bing-wallpaper.service` downloads the current image to a temporary file, then atomically moves it to `/var/lib/bing-wallpaper/wallpaper.jpg`.
3. The user systemd path unit observes the changed wallpaper file.
4. The path unit restarts the user `swaybg` service.
5. The new `swaybg` process loads and displays the updated image.

## Error handling

If the Bing wallpaper download fails, the existing service behavior keeps the last good wallpaper file in place and the path unit is not triggered by a successful replacement.

If `swaybg` exits unexpectedly, the user service should restart on failure. If the wallpaper file does not exist yet, the service may fail until the Bing service creates it; the restart policy should retry without requiring manual intervention.

## Validation

Use existing repository tooling only:

- Run the relevant Nix formatting/check command available in the repo.
- Build or check the Asahi NixOS configuration if feasible.
- Reload/apply the user service or inspect the generated config enough to confirm `swaybg` is no longer in Hyprland `exec-once` and the user path unit watches the shared wallpaper file.
- Manually restart or trigger the user path/service only if needed to refresh the current live session.

## Non-goals

Do not change the Bing wallpaper provider, image path, or daily timer schedule.

Do not replace `swaybg` with another wallpaper tool.

Do not change SDDM wallpaper behavior.
