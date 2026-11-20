//usr/bin/env nix shell nixpkgs#rust-script nixpkgs#cargo nixpkgs#rustc --command rust-script -d 'bevy={version="0.20.1",default-features=false,features=["3d_bevy_render","default_app","std","multi_threaded"]}' -d flate2=1 -d base64=0.22 -d libc=0.2 "$0" "$@"; exit $?
//! plate-field — a Bevy scene rendered on the GPU and streamed into the terminal over the
//! Kitty graphics protocol. Where plate-orb ray-traces one sphere on the CPU, this is a real
//! engine: an ECS world of ~4,600 entities, PBR rasterization, cascaded shadow maps, HDR
//! bloom and distance fog, all through wgpu (Metal on macOS, Vulkan on Linux).
//!
//! Same polyglot first line as plate-orb.rs: your shell runs it, rustc sees a comment, and
//! rust-script caches the binary. The first run compiles Bevy and takes a few minutes.
//!
//! Pipeline:
//!   1. Bevy runs headless (no window, no winit). The camera renders into an offscreen
//!      image, and a `Readback` component copies that texture back to the CPU every frame.
//!   2. We own the main loop: `app.update()` runs the ECS schedules and the render graph,
//!      then we wait on the GPU so the readback is mapped. Frame N's pixels arrive during
//!      update N+1, a one-frame latency.
//!   3. The pixels go to the terminal exactly as in plate-orb: through POSIX shared memory
//!      locally, or zlib + base64 inline over SSH, shown through Unicode placeholder cells so
//!      tmux treats the image as text.
//!
//! The scene: a 48×48 field of pillars driven by two orbiting wave sources. Where the waves
//! interfere constructively the pillars rise and their caps glow vermilion, bloom spreads
//! that glow, and two vermilion point lights ride the sources.
//!
//! Usage: scripts/demo/plate-field.rs [--fps N] [--width PX] [--direct] [--dump F.png [--time S]]
//!   --fps N     target frame rate (default 60)
//!   --width PX  max render width; the terminal scales it to the cell grid
//!               (default 1600 with shm, 960 with --direct)
//!   --direct    force inline zlib+base64 transmission instead of shared memory
//!   --dump F    render one 960x540 frame to F (PNG) and exit; needs no terminal
//!   --time S    with --dump, the animation time to render (default 6)

use base64::Engine;
use bevy::{
    app::PluginsState,
    camera::RenderTarget,
    core_pipeline::tonemapping::Tonemapping,
    light::CascadeShadowConfigBuilder,
    log::{Level, LogPlugin},
    post_process::bloom::Bloom,
    prelude::*,
    render::{
        gpu_readback::{Readback, ReadbackComplete},
        pipelined_rendering::PipelinedRenderingPlugin,
        render_resource::{Extent3d, PollType, TextureFormat, TextureUsages},
        renderer::{RenderAdapterInfo, RenderDevice},
        RenderPlugin,
    },
    window::ExitCondition,
};
use flate2::{write::ZlibEncoder, Compression};
use std::ffi::CString;
use std::io::{Read, Write};
use std::process::Command;
use std::time::{Duration, Instant};

// Also the 256-color index the placeholder cells are painted with. plate-orb uses 42, so
// both demos can run side by side in one terminal.
const IMAGE_ID: u32 = 43;

// Row/column diacritics from kitty's gen/rowcolumn-diacritics.txt (index -> combining char).
const DIACRITICS: [u32; 297] = [
    0x0305, 0x030D, 0x030E, 0x0310, 0x0312, 0x033D, 0x033E, 0x033F, 0x0346, 0x034A, 0x034B, 0x034C,
    0x0350, 0x0351, 0x0352, 0x0357, 0x035B, 0x0363, 0x0364, 0x0365, 0x0366, 0x0367, 0x0368, 0x0369,
    0x036A, 0x036B, 0x036C, 0x036D, 0x036E, 0x036F, 0x0483, 0x0484, 0x0485, 0x0486, 0x0487, 0x0592,
    0x0593, 0x0594, 0x0595, 0x0597, 0x0598, 0x0599, 0x059C, 0x059D, 0x059E, 0x059F, 0x05A0, 0x05A1,
    0x05A8, 0x05A9, 0x05AB, 0x05AC, 0x05AF, 0x05C4, 0x0610, 0x0611, 0x0612, 0x0613, 0x0614, 0x0615,
    0x0616, 0x0617, 0x0657, 0x0658, 0x0659, 0x065A, 0x065B, 0x065D, 0x065E, 0x06D6, 0x06D7, 0x06D8,
    0x06D9, 0x06DA, 0x06DB, 0x06DC, 0x06DF, 0x06E0, 0x06E1, 0x06E2, 0x06E4, 0x06E7, 0x06E8, 0x06EB,
    0x06EC, 0x0730, 0x0732, 0x0733, 0x0735, 0x0736, 0x073A, 0x073D, 0x073F, 0x0740, 0x0741, 0x0743,
    0x0745, 0x0747, 0x0749, 0x074A, 0x07EB, 0x07EC, 0x07ED, 0x07EE, 0x07EF, 0x07F0, 0x07F1, 0x07F3,
    0x0816, 0x0817, 0x0818, 0x0819, 0x081B, 0x081C, 0x081D, 0x081E, 0x081F, 0x0820, 0x0821, 0x0822,
    0x0823, 0x0825, 0x0826, 0x0827, 0x0829, 0x082A, 0x082B, 0x082C, 0x082D, 0x0951, 0x0953, 0x0954,
    0x0F82, 0x0F83, 0x0F86, 0x0F87, 0x135D, 0x135E, 0x135F, 0x17DD, 0x193A, 0x1A17, 0x1A75, 0x1A76,
    0x1A77, 0x1A78, 0x1A79, 0x1A7A, 0x1A7B, 0x1A7C, 0x1B6B, 0x1B6D, 0x1B6E, 0x1B6F, 0x1B70, 0x1B71,
    0x1B72, 0x1B73, 0x1CD0, 0x1CD1, 0x1CD2, 0x1CDA, 0x1CDB, 0x1CE0, 0x1DC0, 0x1DC1, 0x1DC3, 0x1DC4,
    0x1DC5, 0x1DC6, 0x1DC7, 0x1DC8, 0x1DC9, 0x1DCB, 0x1DCC, 0x1DD1, 0x1DD2, 0x1DD3, 0x1DD4, 0x1DD5,
    0x1DD6, 0x1DD7, 0x1DD8, 0x1DD9, 0x1DDA, 0x1DDB, 0x1DDC, 0x1DDD, 0x1DDE, 0x1DDF, 0x1DE0, 0x1DE1,
    0x1DE2, 0x1DE3, 0x1DE4, 0x1DE5, 0x1DE6, 0x1DFE, 0x20D0, 0x20D1, 0x20D4, 0x20D5, 0x20D6, 0x20D7,
    0x20DB, 0x20DC, 0x20E1, 0x20E7, 0x20E9, 0x20F0, 0x2CEF, 0x2CF0, 0x2CF1, 0x2DE0, 0x2DE1, 0x2DE2,
    0x2DE3, 0x2DE4, 0x2DE5, 0x2DE6, 0x2DE7, 0x2DE8, 0x2DE9, 0x2DEA, 0x2DEB, 0x2DEC, 0x2DED, 0x2DEE,
    0x2DEF, 0x2DF0, 0x2DF1, 0x2DF2, 0x2DF3, 0x2DF4, 0x2DF5, 0x2DF6, 0x2DF7, 0x2DF8, 0x2DF9, 0x2DFA,
    0x2DFB, 0x2DFC, 0x2DFD, 0x2DFE, 0x2DFF, 0xA66F, 0xA67C, 0xA67D, 0xA6F0, 0xA6F1, 0xA8E0, 0xA8E1,
    0xA8E2, 0xA8E3, 0xA8E4, 0xA8E5, 0xA8E6, 0xA8E7, 0xA8E8, 0xA8E9, 0xA8EA, 0xA8EB, 0xA8EC, 0xA8ED,
    0xA8EE, 0xA8EF, 0xA8F0, 0xA8F1, 0xAAB0, 0xAAB2, 0xAAB3, 0xAAB7, 0xAAB8, 0xAABE, 0xAABF, 0xAAC1,
    0xFE20, 0xFE21, 0xFE22, 0xFE23, 0xFE24, 0xFE25, 0xFE26, 0x10A0F, 0x10A38, 0x1D185, 0x1D186,
    0x1D187, 0x1D188, 0x1D189, 0x1D1AA, 0x1D1AB, 0x1D1AC, 0x1D1AD, 0x1D242, 0x1D243, 0x1D244,
];

// ---------------------------------------------------------------- scene

const N: i32 = 48; // pillars per side
const PITCH: f32 = 1.0; // pillar spacing
const GLOW_LEVELS: usize = 16;

/// Plate hex token -> Bevy color.
fn plate(hex: u32) -> Color {
    Color::srgb_u8((hex >> 16) as u8, (hex >> 8) as u8, hex as u8)
}

fn smoothstep(a: f32, b: f32, x: f32) -> f32 {
    let t = ((x - a) / (b - a)).clamp(0.0, 1.0);
    t * t * (3.0 - 2.0 * t)
}

/// Where the two wave sources are at time t: opposite points on a slow circle.
fn sources(t: f32) -> [Vec2; 2] {
    let a = t * 0.35;
    let r = 9.0 + 3.0 * (t * 0.23).sin();
    [Vec2::new(a.cos(), a.sin()) * r, Vec2::new(-a.cos(), -a.sin()) * r]
}

/// Pillar height at (x, z): the constructive part of two interfering ripples, plus a slow swell.
fn height(p: Vec2, src: &[Vec2; 2], t: f32) -> f32 {
    let wave = |s: Vec2| {
        let d = p.distance(s);
        (d * 0.75 - t * 2.6).sin() * (-d * 0.035).exp()
    };
    let crest = ((wave(src[0]) + wave(src[1])) * 0.5).max(0.0);
    let swell = 0.5 + 0.5 * (p.x * 0.12 + t * 0.4).sin() * (p.y * 0.1 - t * 0.3).cos();
    0.3 + 0.5 * swell + 3.4 * crest.powf(1.4)
}

fn glow(h: f32) -> f32 { smoothstep(1.2, 2.8, h) }

#[derive(Component)]
struct Cell(Vec2);

/// A pillar's cap, with the glow level it currently shows (so materials only swap on change).
#[derive(Component)]
struct Cap(usize);

#[derive(Component)]
struct SourceLight(usize);

#[derive(Resource)]
struct GlowMaterials(Vec<Handle<StandardMaterial>>);

/// Animation time, set by the main loop before every update so --dump is deterministic.
#[derive(Resource, Default)]
struct Clock(f32);

/// Render size requested at startup.
#[derive(Resource)]
struct InitialSize(u32, u32);

/// The offscreen image the camera renders into.
#[derive(Resource)]
struct Target(Handle<Image>);

/// The most recent frame read back from the GPU (RGBA8, sRGB).
#[derive(Resource, Default)]
struct Latest(Option<Vec<u8>>);

fn target_image(w: u32, h: u32) -> Image {
    let mut img = Image::new_target_texture(w, h, TextureFormat::Rgba8UnormSrgb, None);
    img.texture_descriptor.usage |= TextureUsages::COPY_SRC; // so it can be read back
    img
}

fn setup(
    mut commands: Commands,
    mut meshes: ResMut<Assets<Mesh>>,
    mut materials: ResMut<Assets<StandardMaterial>>,
    mut images: ResMut<Assets<Image>>,
    size: Res<InitialSize>,
) {
    let void = plate(0x0a0a0a);
    let vermilion = LinearRgba::from(plate(0xe03c28));
    let bright = LinearRgba::from(plate(0xe6e6e6));

    // Render target, plus a persistent readback that copies it to the CPU every frame.
    let target = images.add(target_image(size.0, size.1));
    commands.insert_resource(Target(target.clone()));
    commands
        .spawn(Readback::texture(target.clone()))
        .observe(|mut ev: On<ReadbackComplete>, mut latest: ResMut<Latest>| {
            latest.0 = Some(std::mem::take(&mut ev.data));
        });

    commands.spawn((
        Camera3d::default(),
        RenderTarget::from(target),
        Tonemapping::TonyMcMapface, // desaturates bright emissives toward white, which bloom wants
        Bloom::NATURAL,
        DistanceFog {
            color: void,
            falloff: FogFalloff::Exponential { density: 0.024 },
            ..default()
        },
        Transform::from_xyz(0.0, 15.0, 34.0).looking_at(Vec3::Y, Vec3::Y),
    ));

    commands.spawn((
        DirectionalLight {
            color: plate(0xd4d4d4),
            illuminance: 5000.0,
            shadow_maps_enabled: true,
            ..default()
        },
        CascadeShadowConfigBuilder {
            first_cascade_far_bound: 20.0,
            maximum_distance: 90.0,
            ..default()
        }
        .build(),
        Transform::from_xyz(-12.0, 30.0, 8.0).looking_at(Vec3::ZERO, Vec3::Y),
    ));
    for i in 0..2 {
        commands.spawn((
            PointLight {
                color: plate(0xe03c28),
                intensity: 3_000_000.0,
                range: 30.0,
                ..default()
            },
            Transform::default(),
            SourceLight(i),
        ));
    }

    commands.spawn((
        Mesh3d(meshes.add(Plane3d::default().mesh().size(400.0, 400.0))),
        MeshMaterial3d(materials.add(StandardMaterial {
            base_color: plate(0x111111),
            perceptual_roughness: 0.9,
            ..default()
        })),
    ));

    // Cap materials: level 0 is plain inset grey; the rest glow vermilion, brightest going
    // toward white like plate-orb's equator band.
    let glow_mats: Vec<_> = (0..GLOW_LEVELS)
        .map(|i| {
            let g = i as f32 / (GLOW_LEVELS - 1) as f32;
            if i == 0 {
                return materials.add(StandardMaterial {
                    base_color: plate(0x2e2e2e),
                    perceptual_roughness: 0.5,
                    ..default()
                });
            }
            let c = vermilion.mix(&bright, g.powi(4) * 0.35);
            let k = 4.0 + 120.0 * g * g;
            materials.add(StandardMaterial {
                base_color: plate(0xe03c28),
                emissive: LinearRgba::rgb(c.red * k, c.green * k, c.blue * k),
                ..default()
            })
        })
        .collect();

    let body = meshes.add(Cuboid::new(0.82, 1.0, 0.82));
    let cap = meshes.add(Cuboid::new(0.82, 0.06, 0.82));
    let body_mat = materials.add(StandardMaterial {
        base_color: plate(0x1a1a1a),
        perceptual_roughness: 0.35,
        ..default()
    });
    let half = (N - 1) as f32 * PITCH * 0.5;
    for ix in 0..N {
        for iz in 0..N {
            let p = Vec2::new(ix as f32 * PITCH - half, iz as f32 * PITCH - half);
            commands.spawn((Mesh3d(body.clone()), MeshMaterial3d(body_mat.clone()), Transform::default(), Cell(p)));
            commands.spawn((Mesh3d(cap.clone()), MeshMaterial3d(glow_mats[0].clone()), Transform::default(), Cell(p), Cap(0)));
        }
    }
    commands.insert_resource(GlowMaterials(glow_mats));
}

fn animate(
    clock: Res<Clock>,
    glow_mats: Res<GlowMaterials>,
    mut bodies: Query<(&Cell, &mut Transform), Without<Cap>>,
    mut caps: Query<(&Cell, &mut Cap, &mut Transform, &mut MeshMaterial3d<StandardMaterial>)>,
    mut lights: Query<(&SourceLight, &mut Transform), Without<Cell>>,
    mut camera: Query<&mut Transform, (With<Camera3d>, Without<Cell>, Without<SourceLight>)>,
) {
    let t = clock.0;
    let src = sources(t);
    for (cell, mut tf) in &mut bodies {
        let h = height(cell.0, &src, t);
        *tf = Transform::from_xyz(cell.0.x, h * 0.5, cell.0.y).with_scale(Vec3::new(1.0, h, 1.0));
    }
    for (cell, mut cap, mut tf, mut mat) in &mut caps {
        let h = height(cell.0, &src, t);
        tf.translation = Vec3::new(cell.0.x, h + 0.03, cell.0.y);
        let level = (glow(h) * (GLOW_LEVELS - 1) as f32).round() as usize;
        if cap.0 != level {
            cap.0 = level;
            mat.0 = glow_mats.0[level].clone();
        }
    }
    for (light, mut tf) in &mut lights {
        let s = src[light.0];
        tf.translation = Vec3::new(s.x, 2.5, s.y);
    }
    for mut tf in &mut camera {
        let a = t * 0.12 + 0.6;
        let eye = Vec3::new(a.sin() * 28.0, 11.0 + 2.5 * (t * 0.3).sin(), a.cos() * 28.0);
        *tf = Transform::from_translation(eye).looking_at(Vec3::new(0.0, 0.0, 0.0), Vec3::Y);
    }
}

/// Build the headless app and finish plugin setup ourselves, since we never call `app.run()`.
fn build_app(w: u32, h: u32) -> App {
    let mut app = App::new();
    app.add_plugins(
        DefaultPlugins
            // No window, and don't exit just because there isn't one.
            .set(WindowPlugin { primary_window: None, exit_condition: ExitCondition::DontExit, ..default() })
            // Compile every shader before the first frame instead of drawing without them.
            .set(RenderPlugin { synchronous_pipeline_compilation: true, ..default() })
            // Only errors, and they'd draw over the image anyway.
            .set(LogPlugin { level: Level::ERROR, filter: "error".into(), ..default() })
            // Render on this thread, so after update() + a GPU wait the frame is really done.
            .disable::<PipelinedRenderingPlugin>(),
    )
    .insert_resource(ClearColor(plate(0x0a0a0a)))
    .insert_resource(GlobalAmbientLight { color: plate(0x909090), brightness: 120.0, ..default() })
    .insert_resource(InitialSize(w, h))
    .init_resource::<Clock>()
    .init_resource::<Latest>()
    .add_systems(Startup, setup)
    .add_systems(Update, animate);

    // The renderer initializes asynchronously; wait for it (what App::run does internally).
    while app.plugins_state() == PluginsState::Adding {
        bevy::tasks::tick_global_task_pools_on_main_thread();
    }
    app.finish();
    app.cleanup();
    app
}

/// Run one frame at time t and wait for the GPU, so the readback it queued gets mapped.
fn step(app: &mut App, t: f32) {
    app.world_mut().resource_mut::<Clock>().0 = t;
    app.update();
    let _ = app.world().resource::<RenderDevice>().poll(PollType::wait_indefinitely());
}

// ---------------------------------------------------------------- terminal plumbing
// Same transport as plate-orb.rs, for RGBA frames.

fn tmux(args: &[&str]) -> String {
    Command::new("tmux").args(args).output()
        .map(|o| String::from_utf8_lossy(&o.stdout).trim().to_string())
        .unwrap_or_default()
}

/// Wrap an escape sequence so tmux forwards it untouched to the outer terminal.
fn graphics(seq: &[u8], in_tmux: bool, out: &mut Vec<u8>) {
    if in_tmux {
        out.extend_from_slice(b"\x1bPtmux;");
        for &b in seq {
            if b == 0x1b { out.push(0x1b); }
            out.push(b);
        }
        out.extend_from_slice(b"\x1b\\");
    } else {
        out.extend_from_slice(seq);
    }
}

#[derive(Clone, Copy, PartialEq)]
struct Geometry { rows: usize, cols: usize, cell_w: f32, cell_h: f32 }

/// Current terminal size. Polled every frame, so it only asks tmux for the cell size (a
/// subprocess) when the pty doesn't report pixels and the grid size actually changed.
fn geometry(in_tmux: bool, last: Option<Geometry>) -> Geometry {
    let mut ws: libc::winsize = unsafe { std::mem::zeroed() };
    unsafe { libc::ioctl(libc::STDOUT_FILENO, libc::TIOCGWINSZ, &mut ws) };
    let (rows, cols) = (ws.ws_row.max(1) as usize, ws.ws_col.max(1) as usize);
    if ws.ws_xpixel > 0 && ws.ws_ypixel > 0 {
        let (cw, ch) = (ws.ws_xpixel as f32 / cols as f32, ws.ws_ypixel as f32 / rows as f32);
        return Geometry { rows, cols, cell_w: cw, cell_h: ch };
    }
    if let Some(g) = last.filter(|g| g.rows == rows && g.cols == cols) {
        return g;
    }
    let (mut cw, mut ch) = (8.0, 17.0);
    if in_tmux {
        let s = tmux(&["display", "-p", "#{client_cell_width} #{client_cell_height}"]);
        let v: Vec<f32> = s.split_whitespace().filter_map(|x| x.parse().ok()).collect();
        if v.len() == 2 && v[0] > 0.0 && v[1] > 0.0 { cw = v[0]; ch = v[1]; }
    }
    Geometry { rows, cols, cell_w: cw, cell_h: ch }
}

/// Create a POSIX shared-memory object holding `data`. The terminal unlinks it after reading.
fn shm_write(name: &str, data: &[u8]) -> std::io::Result<()> {
    let cname = CString::new(name).unwrap();
    let err = std::io::Error::last_os_error;
    unsafe {
        let fd = libc::shm_open(cname.as_ptr(), libc::O_CREAT | libc::O_EXCL | libc::O_RDWR, 0o600 as libc::c_uint);
        if fd < 0 {
            return Err(err());
        }
        let fail = |fd| {
            let e = err();
            libc::close(fd);
            libc::shm_unlink(cname.as_ptr());
            Err(e)
        };
        if libc::ftruncate(fd, data.len() as libc::off_t) != 0 {
            return fail(fd);
        }
        let map = libc::mmap(std::ptr::null_mut(), data.len(), libc::PROT_READ | libc::PROT_WRITE, libc::MAP_SHARED, fd, 0);
        if map == libc::MAP_FAILED {
            return fail(fd);
        }
        std::slice::from_raw_parts_mut(map as *mut u8, data.len()).copy_from_slice(data);
        libc::munmap(map, data.len());
        libc::close(fd);
    }
    Ok(())
}

fn shm_unlink(name: &str) {
    let cname = CString::new(name).unwrap();
    unsafe { libc::shm_unlink(cname.as_ptr()) };
}

#[derive(Clone, Copy, PartialEq)]
enum Mode { Shm, Direct }

struct Transmitter {
    mode: Mode,
    in_tmux: bool,
    seq: u64,
    recent: std::collections::VecDeque<String>, // shm names to clean up if the terminal never reads them
}

impl Transmitter {
    fn new(mode: Mode, in_tmux: bool) -> Self {
        Transmitter { mode, in_tmux, seq: 0, recent: Default::default() }
    }

    /// Upload a w x h RGBA frame and (re)create its virtual placement spanning cols x rows cells.
    fn send(&mut self, w: usize, h: usize, cols: usize, rows: usize, rgba: &[u8], out: &mut Vec<u8>) {
        let head = format!("a=T,U=1,f=32,s={w},v={h},i={IMAGE_ID},c={cols},r={rows},q=2");
        let b64 = &base64::engine::general_purpose::STANDARD;
        if self.mode == Mode::Shm {
            // macOS caps shm names at 31 bytes.
            let name = format!("/pfld{}-{}", std::process::id(), self.seq);
            self.seq += 1;
            if shm_write(&name, rgba).is_ok() {
                let seq = format!("\x1b_G{head},t=s,S={};{}\x1b\\", rgba.len(), b64.encode(&name));
                graphics(seq.as_bytes(), self.in_tmux, out);
                // The terminal unlinks each object as it reads it. Anything still around 32
                // frames later was never consumed, so remove it rather than leak it until reboot.
                self.recent.push_back(name);
                if self.recent.len() > 32 {
                    if let Some(old) = self.recent.pop_front() {
                        shm_unlink(&old);
                    }
                }
                return;
            }
            self.mode = Mode::Direct; // shm unavailable: fall back for the rest of the run
        }
        let mut z = ZlibEncoder::new(Vec::with_capacity(rgba.len() / 4), Compression::fast());
        z.write_all(rgba).unwrap();
        let payload = b64.encode(z.finish().unwrap());
        let chunks: Vec<&[u8]> = payload.as_bytes().chunks(4096).collect();
        let mut seq = Vec::with_capacity(4096 + 128);
        for (i, chunk) in chunks.iter().enumerate() {
            let more = (i + 1 < chunks.len()) as u8;
            seq.clear();
            seq.extend_from_slice(b"\x1b_G");
            if i == 0 {
                write!(seq, "{head},o=z,m={more}").unwrap();
            } else {
                write!(seq, "m={more}").unwrap();
            }
            seq.push(b';');
            seq.extend_from_slice(chunk);
            seq.extend_from_slice(b"\x1b\\");
            graphics(&seq, self.in_tmux, out);
        }
    }

    fn cleanup(&mut self) {
        for name in self.recent.drain(..) {
            shm_unlink(&name); // already gone (ENOENT) for every frame the terminal consumed
        }
    }
}

/// Ask the terminal whether it accepts shared-memory images. Sends a 1x1 query followed by
/// a Primary Device Attributes request, which every terminal answers, so we know when to stop
/// waiting. Returns None when no answer can be read (e.g. tmux swallows the reply).
fn probe_shm() -> Option<bool> {
    let name = format!("/pfld{}-probe", std::process::id());
    shm_write(&name, &[0, 0, 0]).ok()?;
    let b64 = base64::engine::general_purpose::STANDARD.encode(&name);
    let fd = libc::STDIN_FILENO;
    let mut saved: libc::termios = unsafe { std::mem::zeroed() };
    if unsafe { libc::tcgetattr(fd, &mut saved) } != 0 {
        shm_unlink(&name);
        return None;
    }
    let mut raw = saved;
    raw.c_lflag &= !(libc::ICANON | libc::ECHO);
    raw.c_cc[libc::VMIN] = 0;
    raw.c_cc[libc::VTIME] = 0;
    unsafe { libc::tcsetattr(fd, libc::TCSANOW, &raw) };

    let mut tty = std::io::stdout();
    let _ = write!(tty, "\x1b_Gi=31,a=q,t=s,s=1,v=1,f=24;{b64}\x1b\\\x1b[c");
    let _ = tty.flush();

    let mut reply = Vec::new();
    let deadline = Instant::now() + Duration::from_millis(1000);
    let mut stdin = std::io::stdin();
    while Instant::now() < deadline {
        let mut pfd = libc::pollfd { fd, events: libc::POLLIN, revents: 0 };
        let left = deadline.saturating_duration_since(Instant::now()).as_millis() as libc::c_int;
        if unsafe { libc::poll(&mut pfd, 1, left) } <= 0 {
            break;
        }
        let mut chunk = [0u8; 256];
        match stdin.read(&mut chunk) {
            Ok(n) if n > 0 => reply.extend_from_slice(&chunk[..n]),
            _ => break,
        }
        // The device-attributes reply ends with 'c' after "\x1b[?".
        if let Some(i) = reply.windows(3).position(|w| w == b"\x1b[?") {
            if reply[i..].contains(&b'c') {
                break;
            }
        }
    }
    unsafe { libc::tcsetattr(fd, libc::TCSANOW, &saved) };
    shm_unlink(&name);

    let text = String::from_utf8_lossy(&reply);
    if text.contains("i=31;OK") {
        Some(true)
    } else if text.contains("i=31;") {
        Some(false)
    } else {
        None
    }
}

/// Text cells that the terminal replaces with the image; tmux just sees characters.
fn placeholders(cols: usize, rows: usize) -> String {
    let dia = |i: usize| char::from_u32(DIACRITICS[i]).unwrap();
    let mut s = format!("\x1b[38;5;{IMAGE_ID}m");
    for r in 0..rows {
        s += &format!("\x1b[{};1H", r + 1);
        for c in 0..cols {
            s.push('\u{10EEEE}');
            s.push(dia(r));
            s.push(dia(c));
        }
    }
    s + "\x1b[0m"
}

fn palette_strip() -> String {
    (0..16).map(|i| format!("\x1b[38;5;{i}m■")).collect::<String>() + "\x1b[0m"
}

fn arg<T: std::str::FromStr>(args: &[String], name: &str, default: T) -> T {
    args.iter().position(|a| a == name)
        .and_then(|i| args.get(i + 1))
        .and_then(|v| v.parse().ok())
        .unwrap_or(default)
}

/// Render width for a pixel area, capped at max_w and rounded down to a multiple of 64 pixels:
/// GPU readback pads rows to 256 bytes, so at that width the rows arrive unpadded.
fn render_size(px_w: f32, px_h: f32, max_w: usize) -> (u32, u32) {
    let scale = (max_w as f32 / px_w).min(1.0);
    let w = (((px_w * scale) as u32) / 64 * 64).max(64);
    let h = ((w as f32 * px_h / px_w) as u32).max(16);
    (w, h)
}

fn dump(path: &str, t: f32) {
    let (w, h) = (960, 540);
    let mut app = build_app(w, h);
    // A few frames: one to build the scene, one for the readback to land, spare for pipelines.
    for _ in 0..4 {
        step(&mut app, t);
    }
    let data = app.world_mut().resource_mut::<Latest>().0.take().expect("no frame read back");
    let img = Image::new(
        Extent3d { width: w, height: h, ..default() },
        bevy::render::render_resource::TextureDimension::D2,
        data,
        TextureFormat::Rgba8UnormSrgb,
        default(),
    );
    img.try_into_dynamic().expect("convert frame").save(path).expect("write frame");
}

fn main() {
    let args: Vec<String> = std::env::args().collect();
    if let Some(path) = args.iter().position(|a| a == "--dump").and_then(|i| args.get(i + 1)) {
        return dump(path, arg(&args, "--time", 6.0));
    }
    let target_fps: f64 = arg(&args, "--fps", 60.0);

    let in_tmux = std::env::var_os("TMUX").is_some();
    let outer = if in_tmux {
        tmux(&["display", "-p", "#{client_termname} #{client_termtype}"])
    } else {
        format!("{} {}", std::env::var("TERM_PROGRAM").unwrap_or_default(), std::env::var("TERM").unwrap_or_default())
    };
    let lower = outer.to_lowercase();
    if !["ghostty", "kitty", "wezterm"].iter().any(|k| lower.contains(k)) {
        eprintln!("Needs a terminal with the Kitty graphics protocol (Ghostty, Kitty, WezTerm); got: {outer:?}");
        std::process::exit(1);
    }
    if in_tmux {
        tmux(&["set", "-p", "allow-passthrough", "on"]); // this pane only; the tmux config enables it globally
    }

    // Shared memory needs the terminal on this machine: skip it over SSH or when asked.
    // Outside tmux, ask the terminal; inside tmux the reply can't come back, so assume local works.
    let remote = std::env::var_os("SSH_CONNECTION").is_some();
    let mode = if args.iter().any(|a| a == "--direct") || remote {
        Mode::Direct
    } else if in_tmux {
        Mode::Shm
    } else {
        match probe_shm() {
            Some(false) => Mode::Direct,
            _ => Mode::Shm,
        }
    };
    let mut tx = Transmitter::new(mode, in_tmux);
    // RGBA frames are 4 bytes a pixel and the GPU never limits us here, so cap the width at
    // what the terminal can take in comfortably.
    let max_w: usize = arg(&args, "--width", if mode == Mode::Shm { 1600 } else { 960 });

    let layout = |g: Geometry| {
        let rows = g.rows.saturating_sub(2).max(4).min(DIACRITICS.len());
        let cols = g.cols.min(DIACRITICS.len());
        let (w, h) = render_size(cols as f32 * g.cell_w, rows as f32 * g.cell_h, max_w);
        (cols, rows, w, h)
    };
    let mut geom = geometry(in_tmux, None);
    let (mut img_cols, mut img_rows, mut w, mut h) = layout(geom);
    let mut app = build_app(w, h);
    let gpu = app.world().get_resource::<RenderAdapterInfo>()
        .map(|i| format!("{} · {:?}", i.name, i.backend))
        .unwrap_or_default();

    let stdout = std::io::stdout();
    let mut tty = stdout.lock();
    let mut out: Vec<u8> = Vec::with_capacity(1 << 20);
    out.extend_from_slice(b"\x1b[?1049h\x1b[?25l\x1b[2J");
    out.extend_from_slice(placeholders(img_cols, img_rows).as_bytes());

    let frame_dt = Duration::from_secs_f64(1.0 / target_fps);
    let start = Instant::now();
    let mut last = start;
    let mut fps = 0.0f64;
    let (mut gpu_ms, mut tty_ms) = (0.0f64, 0.0f64);
    let mut next_frame = Instant::now();

    loop {
        let frame_start = Instant::now();

        // Re-layout on resize: resize the render target in place; the camera follows it.
        let g = geometry(in_tmux, Some(geom));
        if g != geom {
            geom = g;
            (img_cols, img_rows, w, h) = layout(g);
            let handle = app.world().resource::<Target>().0.clone();
            if let Some(mut img) = app.world_mut().resource_mut::<Assets<Image>>().get_mut(&handle) {
                img.resize(Extent3d { width: w, height: h, ..default() });
            }
            out.extend_from_slice(b"\x1b[2J");
            out.extend_from_slice(placeholders(img_cols, img_rows).as_bytes());
        }

        let g0 = Instant::now();
        step(&mut app, (frame_start - start).as_secs_f32());
        gpu_ms = gpu_ms * 0.9 + 0.1 * g0.elapsed().as_secs_f64() * 1e3;
        if app.should_exit().is_some() {
            break; // Bevy's own Ctrl-C handler asked to quit
        }

        // Synchronized output: the terminal holds rendering until the whole frame has arrived.
        graphics(b"\x1b[?2026h", in_tmux, &mut out);
        // Skip a frame rendered at the old size right after a resize.
        if let Some(rgba) = app.world_mut().resource_mut::<Latest>().0.take() {
            if rgba.len() == (w * h * 4) as usize {
                tx.send(w as usize, h as usize, img_cols, img_rows, &rgba, &mut out);
            }
        }
        // Overwrite the caption in place and clear only to its right (no blank-line gap).
        let _ = write!(
            out,
            "\x1b[{};1H \x1b[38;5;9m●\x1b[0m plate-field  \x1b[38;5;8mbevy · {}×{}px → {}×{} cells · {:5.1}/{} fps · gpu {:4.1} ms · tty wait {:4.1} ms · {} · {}{} · ctrl-c to quit\x1b[0m  {}\x1b[K",
            img_rows + 1, w, h, img_cols, img_rows, fps, target_fps, gpu_ms, tty_ms, gpu,
            if tx.mode == Mode::Shm { "shm" } else { "direct" },
            if in_tmux { " · via tmux" } else { "" }, palette_strip()
        );
        graphics(b"\x1b[?2026l", in_tmux, &mut out);

        // Time blocked writing: when the terminal can't keep up, the pty fills and this grows.
        let w0 = Instant::now();
        if tty.write_all(&out).and_then(|_| tty.flush()).is_err() {
            break;
        }
        out.clear();
        tty_ms = tty_ms * 0.9 + 0.1 * w0.elapsed().as_secs_f64() * 1e3;

        let now = Instant::now();
        fps = fps * 0.95 + 0.05 / (now - last).as_secs_f64().max(1e-6);
        last = now;

        // Pace against an absolute schedule so sleep overshoot doesn't add up to a lower fps.
        // If a frame ran long, restart the schedule instead of rushing to catch up.
        next_frame += frame_dt;
        let now = Instant::now();
        if next_frame > now {
            std::thread::sleep(next_frame - now);
        } else {
            next_frame = now;
        }
    }

    let mut bye = Vec::new();
    graphics(format!("\x1b_Ga=d,d=I,i={IMAGE_ID},q=2\x1b\\").as_bytes(), in_tmux, &mut bye);
    bye.extend_from_slice(b"\x1b[?25h\x1b[?1049l");
    let _ = tty.write_all(&bye);
    let _ = tty.flush();
    tx.cleanup();
}
