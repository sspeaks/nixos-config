//usr/bin/env nix shell nixpkgs#rust-script nixpkgs#cargo nixpkgs#rustc --command rust-script -d 'bevy={version="0.20.1",default-features=false,features=["3d_bevy_render","default_app","std","multi_threaded"]}' -d 'image={version="0.25",default-features=false,features=["jpeg"]}' -d flate2=1 -d base64=0.22 -d libc=0.2 "$0" "$@"; exit $?
//! plate-globe — the Earth, rendered by Bevy on the GPU and streamed into the terminal over the
//! Kitty graphics protocol. Bevy has no globe entity, but it has the parts for one:
//!   - a UV sphere with an `ExtendedMaterial`: Bevy's PBR `StandardMaterial` plus a small WESL
//!     shader that adds terrain relief (normals tilted by real elevation slopes, exaggerated so
//!     mountain ranges catch the low sun), cloud shadows, and city lights that fade in at dusk
//!   - a second, translucent sphere just above it carrying the clouds, drifting eastward
//!   - `Atmosphere` (Hillaire 2020 scattering), raymarched so it works from orbit: the blue
//!     limb, the reddened terminator and the haze over the day side are all physically computed
//!   - a `DirectionalLight` + `SunDisk` at real sunlight brightness, placed over the actual
//!     subsolar point for the current UTC time, so the day/night line is the real one
//!   - gizmo great-circle flight arcs between cities, depth-tested so they pass behind the planet
//!
//! Terminal side is the same as plate-field.rs (headless Bevy, GPU readback each frame, shared
//! memory or zlib + base64 transport, Unicode placeholder cells for tmux). The first run
//! compiles Bevy, which takes a few minutes; plate-field shares the same build cache.
//!
//! Data, downloaded once (~35 MB) into ~/.cache/plate-globe:
//!   - day, night-lights and cloud maps: Solar System Scope (solarsystemscope.com/textures),
//!     CC BY 4.0, derived from NASA Blue Marble and Black Marble imagery
//!   - elevation and ocean depth: NOAA ETOPO1 (public domain), via NOAA CoastWatch ERDDAP
//!
//! Usage: scripts/demo/plate-globe.rs [--fps N] [--width PX] [--direct] [--speed X] [--relief K]
//!                                    [--no-flights] [--dump F.png [--time S]]
//!   --fps N        target frame rate (default 60)
//!   --width PX     max render width; the terminal scales it to the cell grid
//!                  (default 1600 with shm, 960 with --direct)
//!   --direct       force inline zlib+base64 transmission instead of shared memory
//!   --speed X      run the sun X times faster than real time (default 1; 3600 = an hour a second)
//!   --relief K     terrain exaggeration (default 6; 0 = flat)
//!   --no-flights   hide the city and flight-arc overlay
//!   --dump F       render one 960x540 frame to F (PNG) and exit; needs no terminal
//!   --time S       with --dump, the animation time to render (default 0); --speed applies

use base64::Engine;
use bevy::{
    app::PluginsState,
    camera::{Exposure, RenderTarget},
    core_pipeline::tonemapping::Tonemapping,
    image::{ImageAddressMode, ImageSampler, ImageSamplerDescriptor},
    asset::uuid_handle,
    light::{atmosphere::ScatteringMedium, light_consts::lux, Atmosphere, NotShadowCaster, SunDisk},
    log::{Level, LogPlugin},
    pbr::{AtmosphereMode, AtmosphereSettings, ExtendedMaterial, MaterialExtension},
    post_process::bloom::Bloom,
    prelude::*,
    render::{
        gpu_readback::{Readback, ReadbackComplete},
        pipelined_rendering::PipelinedRenderingPlugin,
        render_resource::{AsBindGroup, Extent3d, PollType, TextureDimension, TextureFormat, TextureUsages},
        renderer::{RenderAdapterInfo, RenderDevice},
        RenderPlugin,
    },
    shader::ShaderRef,
    window::ExitCondition,
};
use flate2::{write::ZlibEncoder, Compression};
use std::f32::consts::PI;
use std::ffi::CString;
use std::io::{Read, Write};
use std::process::Command;
use std::time::{Duration, Instant, SystemTime, UNIX_EPOCH};

// Also the 256-color index the placeholder cells are painted with. plate-orb uses 42 and
// plate-field 43, so all three demos can run side by side in one terminal.
const IMAGE_ID: u32 = 44;

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

// ---------------------------------------------------------------- earth data

/// Size every map is resampled to: equirectangular, 180°W at u = 0, north at v = 0.
const TW: usize = 4096;
const TH: usize = 2048;

/// Solar System Scope's Earth maps (CC BY 4.0), built from NASA Blue Marble imagery.
const SSS: &str = "https://www.solarsystemscope.com/textures/download";
/// NOAA ETOPO1 elevation (ice surface) via ERDDAP: every 5th 1′ sample, 2161×4321, south first.
const ETOPO: &str = "https://coastwatch.pfeg.noaa.gov/erddap/griddap/etopo180.nc?altitude%5B(-90.0):5:(90.0)%5D%5B(-180.0):5:(180.0)%5D";

fn cache_dir() -> std::path::PathBuf {
    let base = std::env::var_os("XDG_CACHE_HOME").map(std::path::PathBuf::from).unwrap_or_else(|| {
        std::path::PathBuf::from(std::env::var_os("HOME").unwrap_or_default()).join(".cache")
    });
    base.join("plate-globe")
}

/// The bytes of `url`, downloaded into the cache the first time.
fn fetch(name: &str, url: &str) -> Vec<u8> {
    let dir = cache_dir();
    let path = dir.join(name);
    if let Ok(b) = std::fs::read(&path) {
        return b;
    }
    std::fs::create_dir_all(&dir).expect("create cache dir");
    eprintln!("plate-globe: downloading {name} into {} (first run only)", dir.display());
    let part = dir.join(format!("{name}.part"));
    let ok = Command::new("curl")
        .args(["-fL", "--retry", "5", "--retry-delay", "10", "--progress-bar", "-o"])
        .arg(&part)
        .arg(url)
        .status()
        .map(|s| s.success())
        .unwrap_or(false);
    if !ok {
        eprintln!("plate-globe: download failed: {url}");
        std::process::exit(1);
    }
    std::fs::rename(&part, &path).expect("move download into cache");
    std::fs::read(&path).expect("read download")
}

/// Decode a JPEG map and box-filter it down to TW×TH sRGB pixels.
fn decode_map(bytes: &[u8]) -> Vec<[u8; 3]> {
    let img = image::load_from_memory_with_format(bytes, image::ImageFormat::Jpeg).expect("decode map").to_rgb8();
    let (w, h) = (img.width() as usize, img.height() as usize);
    let (fx, fy) = ((w / TW).max(1), (h / TH).max(1));
    let raw = img.as_raw();
    (0..TW * TH)
        .map(|i| {
            let (x, y) = (i % TW, i / TW);
            let mut s = [0u32; 3];
            for dy in 0..fy {
                for dx in 0..fx {
                    let p = (((y * fy + dy).min(h - 1)) * w + (x * fx + dx).min(w - 1)) * 3;
                    for c in 0..3 {
                        s[c] += raw[p + c] as u32;
                    }
                }
            }
            let n = (fx * fy) as u32;
            [(s[0] / n) as u8, (s[1] / n) as u8, (s[2] / n) as u8]
        })
        .collect()
}

/// Parse ETOPO's NetCDF-3 file: (columns, rows, elevation in meters), row 0 at 90°S.
fn decode_etopo(d: &[u8]) -> (usize, usize, Vec<i16>) {
    assert!(&d[..3] == b"CDF", "ETOPO download is not NetCDF");
    let off64 = d[3] == 2;
    let be32 = |p: &mut usize| {
        let v = u32::from_be_bytes(d[*p..*p + 4].try_into().unwrap()) as usize;
        *p += 4;
        v
    };
    let name = |p: &mut usize| {
        let n = be32(p);
        let s = String::from_utf8_lossy(&d[*p..*p + n]).into_owned();
        *p += n.div_ceil(4) * 4;
        s
    };
    let skip_attrs = |p: &mut usize| {
        let (_tag, n) = (be32(p), be32(p));
        for _ in 0..n {
            name(p);
            let (t, count) = (be32(p), be32(p));
            *p += ([0, 1, 1, 2, 4, 4, 8][t] * count).div_ceil(4) * 4;
        }
    };
    let mut p = 4;
    be32(&mut p); // record count
    let (_tag, ndims) = (be32(&mut p), be32(&mut p));
    let dims: Vec<usize> = (0..ndims).map(|_| { name(&mut p); be32(&mut p) }).collect();
    skip_attrs(&mut p);
    let (_tag, nvars) = (be32(&mut p), be32(&mut p));
    for _ in 0..nvars {
        let var = name(&mut p);
        let ndim = be32(&mut p);
        let ids: Vec<usize> = (0..ndim).map(|_| be32(&mut p)).collect();
        skip_attrs(&mut p);
        let (_type, _size) = (be32(&mut p), be32(&mut p));
        let begin = if off64 {
            p += 8;
            u64::from_be_bytes(d[p - 8..p].try_into().unwrap()) as usize
        } else {
            be32(&mut p)
        };
        if var == "altitude" {
            let (rows, cols) = (dims[ids[0]], dims[ids[1]]);
            let z = d[begin..begin + rows * cols * 2].chunks_exact(2).map(|b| i16::from_be_bytes([b[0], b[1]])).collect();
            return (cols, rows, z);
        }
    }
    panic!("no altitude variable in the ETOPO download");
}

/// ETOPO resampled (bilinear) to the TW×TH texture grid, in meters.
fn elevation_grid() -> Vec<f32> {
    let (cols, rows, z) = decode_etopo(&fetch("etopo1-5min.nc", ETOPO));
    let at = |c: usize, r: usize| z[r.min(rows - 1) * cols + c.min(cols - 1)] as f32;
    (0..TW * TH)
        .map(|i| {
            let (x, y) = (i % TW, i / TW);
            let c = (x as f32 + 0.5) / TW as f32 * (cols - 1) as f32;
            let r = (1.0 - (y as f32 + 0.5) / TH as f32) * (rows - 1) as f32;
            let (c0, r0) = (c.floor() as usize, r.floor() as usize);
            let (fc, fr) = (c.fract(), r.fract());
            let a = at(c0, r0) * (1.0 - fc) + at(c0 + 1, r0) * fc;
            let b = at(c0, r0 + 1) * (1.0 - fc) + at(c0 + 1, r0 + 1) * fc;
            a * (1.0 - fr) + b * fr
        })
        .collect()
}

fn smoothstep(a: f32, b: f32, x: f32) -> f32 {
    let t = ((x - a) / (b - a)).clamp(0.0, 1.0);
    t * t * (3.0 - 2.0 * t)
}

/// sRGB byte -> linear.
fn lin(c: u8) -> f32 {
    let s = c as f32 / 255.0;
    if s <= 0.04045 { s / 12.92 } else { ((s + 0.055) / 1.055).powf(2.4) }
}

/// Linear -> sRGB byte.
fn enc(x: f32) -> u8 {
    let x = x.clamp(0.0, 1.0);
    let s = if x <= 0.0031308 { x * 12.92 } else { 1.055 * x.powf(1.0 / 2.4) - 0.055 };
    (s * 255.0 + 0.5) as u8
}

/// Wrap RGBA8 pixels in an image with a full box-filtered mip chain, sampled with wrapping
/// longitude and anisotropic filtering so the limb doesn't shimmer.
fn mipmapped(w: usize, h: usize, base: Vec<u8>, format: TextureFormat) -> Image {
    let mut data = base.clone();
    let (mut lw, mut lh, mut level, mut levels) = (w, h, base, 1);
    while lw > 1 || lh > 1 {
        let (nw, nh) = ((lw / 2).max(1), (lh / 2).max(1));
        let mut next = vec![0u8; nw * nh * 4];
        for y in 0..nh {
            for x in 0..nw {
                for c in 0..4 {
                    let px = |xx: usize, yy: usize| level[((yy.min(lh - 1)) * lw + xx.min(lw - 1)) * 4 + c] as u32;
                    let s = px(2 * x, 2 * y) + px(2 * x + 1, 2 * y) + px(2 * x, 2 * y + 1) + px(2 * x + 1, 2 * y + 1);
                    next[(y * nw + x) * 4 + c] = ((s + 2) / 4) as u8;
                }
            }
        }
        data.extend_from_slice(&next);
        (lw, lh, level, levels) = (nw, nh, next, levels + 1);
    }
    let size = Extent3d { width: w as u32, height: h as u32, ..default() };
    let mut img = Image::new_uninit(size, TextureDimension::D2, format, default());
    img.data = Some(data);
    img.texture_descriptor.mip_level_count = levels;
    img.sampler = ImageSampler::Descriptor(ImageSamplerDescriptor {
        address_mode_u: ImageAddressMode::Repeat,
        anisotropy_clamp: 16,
        ..ImageSamplerDescriptor::linear()
    });
    img
}

/// Slopes are stored as signed bytes scaled by this, so slopes up to 1:4 fit.
const SLOPE_SCALE: f32 = 4.0;

struct EarthMaps { albedo: Image, roughness: Image, lights: Image, clouds: Image, relief: Image }

/// Build every surface texture: albedo with depth-tinted oceans, glossy-water roughness,
/// night lights, cloud cover, and relief (east/north terrain slope + water mask).
fn earth_maps() -> EarthMaps {
    // Download sequentially (one progress bar at a time), then decode in parallel.
    let files = ["8k_earth_daymap.jpg", "8k_earth_nightmap.jpg", "8k_earth_clouds.jpg"].map(|f| fetch(f, &format!("{SSS}/{f}")));
    fetch("etopo1-5min.nc", ETOPO);
    eprint!("plate-globe: building surface maps…\r");
    let (day, night, clouds, elev) = std::thread::scope(|s| {
        let [d, n, c] = files.each_ref().map(|b| s.spawn(move || decode_map(b)));
        let e = s.spawn(elevation_grid);
        (d.join().unwrap(), n.join().unwrap(), c.join().unwrap(), e.join().unwrap())
    });

    let rgb = |hex: u32| [lin((hex >> 16) as u8), lin((hex >> 8) as u8), lin(hex as u8)];
    let (coast, shelf, deep) = (rgb(0x34788a), rgb(0x1c4e76), rgb(0x0a1c40));
    let n = TW * TH;
    let (mut albedo, mut rough, mut lights, mut cloud, mut relief) =
        (vec![0u8; n * 4], vec![0u8; n * 4], vec![0u8; n * 4], vec![0u8; n * 4], vec![0u8; n * 4]);
    let lights_floor = lin(28);
    for y in 0..TH {
        let lat = (90.0 - (y as f32 + 0.5) / TH as f32 * 180.0).to_radians();
        // Meters per texel east and north, for turning elevation steps into slopes.
        let (mx, my) = (6.371e6 * lat.cos().max(0.05) * std::f32::consts::TAU / TW as f32, 6.371e6 * PI / TH as f32);
        for x in 0..TW {
            let i = y * TW + x;
            let o = i * 4;
            let [r, g, b] = day[i];
            // The day map paints water a flat blue: that's the water mask (oceans and lakes).
            let water = smoothstep(18.0, 38.0, b as f32 - r.max(g) as f32);
            let e = elev[i];
            let depth = (-e).max(0.0);
            let tint: [f32; 3] = std::array::from_fn(|k| {
                let sea = shelf[k] + (deep[k] - shelf[k]) * smoothstep(150.0, 4500.0, depth);
                coast[k] + (sea - coast[k]) * smoothstep(0.0, 120.0, depth)
            });
            let sea = water * smoothstep(5.0, -30.0, e); // lakes above sea level keep the map's color
            for k in 0..3 {
                let c = lin(day[i][k]);
                albedo[o + k] = enc(c + (tint[k] - c) * sea);
                lights[o + k] = enc(((lin(night[i][k]) - lights_floor) / (1.0 - lights_floor)).max(0.0));
            }
            // glTF metallic-roughness: G = roughness. Water is glossy so it catches a sun glint.
            rough[o + 1] = ((0.88 - 0.74 * water) * 255.0) as u8;
            cloud[o] = clouds[i][0];
            // Terrain slope by central differences, wrapping in longitude.
            let ex = (elev[y * TW + (x + 1) % TW] - elev[y * TW + (x + TW - 1) % TW]) / (2.0 * mx);
            let ny = (elev[y.saturating_sub(1) * TW + x] - elev[(y + 1).min(TH - 1) * TW + x]) / (2.0 * my);
            let s = |v: f32| (((v * SLOPE_SCALE).clamp(-1.0, 1.0) * 0.5 + 0.5) * 255.0 + 0.5) as u8;
            (relief[o], relief[o + 1], relief[o + 2]) = (s(ex), s(ny), (water * 255.0) as u8);
            (albedo[o + 3], rough[o + 3], lights[o + 3], cloud[o + 3], relief[o + 3]) = (255, 255, 255, 255, 255);
        }
    }
    let srgb = TextureFormat::Rgba8UnormSrgb;
    let linear = TextureFormat::Rgba8Unorm;
    EarthMaps {
        albedo: mipmapped(TW, TH, albedo, srgb),
        roughness: mipmapped(TW, TH, rough, linear),
        lights: mipmapped(TW, TH, lights, srgb),
        clouds: mipmapped(TW, TH, cloud, linear),
        relief: mipmapped(TW, TH, relief, linear),
    }
}

// ---------------------------------------------------------------- shaders

/// Surface: StandardMaterial plus relief-mapped normals, cloud shadows and night lights.
const SURFACE_WESL: &str = r#"
import bevy_pbr::{
    render::pbr_fragment::pbr_input_from_standard_material,
    render::mesh_view_bindings::lights,
    render::forward_io::{VertexOutput, FragmentOutput},
    render::pbr_functions::{apply_pbr_lighting, main_pass_post_lighting_processing},
};

struct Surface { params: vec4<f32> } // x: relief strength, y: cloud drift (radians), z: night-light nits

@group(constants::MATERIAL_BIND_GROUP) @binding(100) var relief_tex: texture_2d<f32>;
@group(constants::MATERIAL_BIND_GROUP) @binding(101) var relief_smp: sampler;
@group(constants::MATERIAL_BIND_GROUP) @binding(102) var clouds_tex: texture_2d<f32>;
@group(constants::MATERIAL_BIND_GROUP) @binding(103) var clouds_smp: sampler;
@group(constants::MATERIAL_BIND_GROUP) @binding(104) var lights_tex: texture_2d<f32>;
@group(constants::MATERIAL_BIND_GROUP) @binding(105) var lights_smp: sampler;
@group(constants::MATERIAL_BIND_GROUP) @binding(106) var<uniform> surface: Surface;

const SLOPE_SCALE: f32 = 4.0;

@fragment
fn fragment(in: VertexOutput, @builtin(front_facing) is_front: bool) -> FragmentOutput {
    var pbr_input = pbr_input_from_standard_material(in, is_front);
    let n = normalize(in.world_normal);
    // East and north on the sphere (north is +Y).
    let east = normalize(cross(vec3(0.0, 1.0, 0.0), n) + vec3(1e-6, 0.0, 0.0));
    let north = cross(n, east);

    // Relief: tilt the normal against the terrain gradient. Exaggerated, or nothing would show.
    let r = textureSample(relief_tex, relief_smp, in.uv);
    let slope = (r.xy * 2.0 - 1.0) / SLOPE_SCALE * surface.params.x * (1.0 - r.z);
    let bumped = normalize(n - east * slope.x - north * slope.y);
    pbr_input.N = bumped;

    // Cloud shadows: sample the drifting cloud layer a little sunward of this point.
    let sun = lights.directional_lights[0].direction_to_light;
    let mu = dot(n, sun);
    let offset = (sun - n * mu) * 0.006;
    let cuv = in.uv + vec2(dot(offset, east) / 6.2832 - surface.params.y / 6.2832, -dot(offset, north) / 3.1416);
    let cover = textureSample(clouds_tex, clouds_smp, cuv).r;
    pbr_input.directional_shadow_factor = 1.0 - 0.55 * smoothstep(0.15, 0.8, cover);

    var out: FragmentOutput;
    out.color = apply_pbr_lighting(pbr_input);
    // City lights fade in through dusk and dim under cloud.
    let night = smoothstep(0.08, -0.12, mu);
    let city = textureSample(lights_tex, lights_smp, in.uv).rgb;
    out.color = vec4(out.color.rgb + city * surface.params.z * night * (1.0 - 0.7 * cover), out.color.a);
    out.color = main_pass_post_lighting_processing(pbr_input, out.color);
    return out;
}
"#;

/// Clouds: an alpha-blended shell just above the surface, drifting eastward.
const CLOUDS_WESL: &str = r#"
import bevy_pbr::{
    render::pbr_fragment::pbr_input_from_standard_material,
    render::forward_io::{VertexOutput, FragmentOutput},
    render::pbr_functions::{apply_pbr_lighting, main_pass_post_lighting_processing},
};

struct Drift { params: vec4<f32> } // x: drift (radians)

@group(constants::MATERIAL_BIND_GROUP) @binding(100) var cover_tex: texture_2d<f32>;
@group(constants::MATERIAL_BIND_GROUP) @binding(101) var cover_smp: sampler;
@group(constants::MATERIAL_BIND_GROUP) @binding(102) var<uniform> drift: Drift;

@fragment
fn fragment(in: VertexOutput, @builtin(front_facing) is_front: bool) -> FragmentOutput {
    var pbr_input = pbr_input_from_standard_material(in, is_front);
    let uv = in.uv - vec2(drift.params.x / 6.2832, 0.0);
    let cover = smoothstep(0.08, 0.85, textureSample(cover_tex, cover_smp, uv).r);
    pbr_input.material.base_color = vec4(pbr_input.material.base_color.rgb, cover * 0.95);
    var out: FragmentOutput;
    out.color = apply_pbr_lighting(pbr_input);
    out.color = main_pass_post_lighting_processing(pbr_input, out.color);
    return out;
}
"#;

#[derive(Asset, AsBindGroup, TypePath, Debug, Clone)]
struct SurfaceExt {
    #[texture(100)]
    #[sampler(101)]
    relief: Handle<Image>,
    #[texture(102)]
    #[sampler(103)]
    clouds: Handle<Image>,
    #[texture(104)]
    #[sampler(105)]
    lights: Handle<Image>,
    #[uniform(106)]
    params: Vec4,
}

impl MaterialExtension for SurfaceExt {
    fn fragment_shader() -> ShaderRef {
        SURFACE_SHADER.into()
    }
}

#[derive(Asset, AsBindGroup, TypePath, Debug, Clone)]
struct CloudExt {
    #[texture(100)]
    #[sampler(101)]
    cover: Handle<Image>,
    #[uniform(102)]
    params: Vec4,
}

impl MaterialExtension for CloudExt {
    fn fragment_shader() -> ShaderRef {
        CLOUDS_SHADER.into()
    }
    // Clouds are translucent: no depth prepass, and they don't shadow the ground via shadow
    // maps (the surface shader does that from the same texture, softly).
    fn enable_prepass() -> bool {
        false
    }
    fn enable_shadows() -> bool {
        false
    }
}

type SurfaceMaterial = ExtendedMaterial<StandardMaterial, SurfaceExt>;
type CloudMaterial = ExtendedMaterial<StandardMaterial, CloudExt>;

const SURFACE_SHADER: Handle<Shader> = uuid_handle!("6f4a3f0e-5b1c-4c7e-9a9e-8f2d6b1e7c01");
const CLOUDS_SHADER: Handle<Shader> = uuid_handle!("6f4a3f0e-5b1c-4c7e-9a9e-8f2d6b1e7c02");

// ---------------------------------------------------------------- geography

/// Unit vector for a latitude/longitude in degrees, in the frame of the rotated UV sphere
/// below: north is +Y and longitude 0 faces −X... see `globe_mesh` for the derivation.
fn geo(lat: f32, lon: f32) -> Vec3 {
    let (lat, phi) = (lat.to_radians(), (lon + 180.0).to_radians());
    Vec3::new(lat.cos() * phi.cos(), lat.sin(), -lat.cos() * phi.sin())
}

/// Bevy's UV sphere puts the poles on ±Z and texture u at sector angle 2πu around Z; rotating
/// it −90° about X puts north on +Y, so u (= (lon + 180°) / 360°) lands where `geo` says.
fn globe_mesh(radius: f32) -> Mesh {
    Sphere::new(radius).mesh().uv(256, 128).rotated_by(Quat::from_rotation_x(-PI / 2.0))
}

/// The point on Earth with the sun directly overhead at a Unix time, as (lat, lon) in degrees.
/// Low-precision solar position (Astronomical Almanac), good to about 0.01°.
fn subsolar(unix: f64) -> (f32, f32) {
    let n = (unix - 946_728_000.0) / 86_400.0; // days since J2000.0
    let l = (280.460 + 0.985_647_4 * n).to_radians();
    let g = (357.528 + 0.985_600_3 * n).to_radians();
    let lambda = l + (1.915f64.to_radians()) * g.sin() + (0.020f64.to_radians()) * (2.0 * g).sin();
    let eps = (23.439 - 4e-7 * n).to_radians();
    let dec = (eps.sin() * lambda.sin()).asin();
    let ra = (eps.cos() * lambda.sin()).atan2(lambda.cos());
    let gmst = (280.460_618_37 + 360.985_647_366_29 * n).to_radians();
    let lon = (ra - gmst).to_degrees().rem_euclid(360.0);
    (dec.to_degrees() as f32, (if lon > 180.0 { lon - 360.0 } else { lon }) as f32)
}

const CITIES: [(&str, f32, f32); 18] = [
    ("New York", 40.71, -74.01), ("London", 51.51, -0.13), ("Tokyo", 35.68, 139.69),
    ("Sydney", -33.87, 151.21), ("São Paulo", -23.55, -46.63), ("Lagos", 6.52, 3.38),
    ("Dubai", 25.20, 55.27), ("Singapore", 1.35, 103.82), ("Los Angeles", 34.05, -118.24),
    ("Seattle", 47.61, -122.33), ("Mumbai", 19.08, 72.88), ("Cape Town", -33.92, 18.42),
    ("Moscow", 55.76, 37.62), ("Mexico City", 19.43, -99.13), ("Reykjavík", 64.15, -21.94),
    ("Honolulu", 21.31, -157.86), ("Santiago", -33.45, -70.67), ("Nairobi", -1.29, 36.82),
];

/// City index pairs flown between.
const ROUTES: [(usize, usize); 18] = [
    (0, 1), (1, 6), (6, 7), (7, 3), (2, 9), (8, 2), (9, 1), (0, 4), (4, 11), (11, 17),
    (17, 6), (10, 1), (12, 2), (13, 16), (14, 0), (15, 3), (8, 15), (5, 1),
];

/// A point `s` of the way along the great circle a -> b, lifted into an arc.
fn arc(a: Vec3, b: Vec3, s: f32) -> Vec3 {
    let w = a.dot(b).clamp(-1.0, 1.0).acos();
    let p = (a * ((1.0 - s) * w).sin() + b * (s * w).sin()) / w.sin();
    p * (1.004 + (0.02 + 0.16 * w / PI) * (PI * s).sin())
}

// ---------------------------------------------------------------- scene

/// Animation state, set by the main loop before every update so --dump is deterministic.
#[derive(Resource, Default)]
struct Clock {
    t: f32,    // seconds of camera animation
    unix: f64, // simulated wall-clock time driving the sun
}

/// Render size requested at startup.
#[derive(Resource)]
struct InitialSize(u32, u32);

/// The offscreen image the camera renders into.
#[derive(Resource)]
struct Target(Handle<Image>);

/// The most recent frame read back from the GPU (RGBA8, sRGB).
#[derive(Resource, Default)]
struct Latest(Option<Vec<u8>>);

fn plate(hex: u32) -> Color {
    Color::srgb_u8((hex >> 16) as u8, (hex >> 8) as u8, hex as u8)
}

fn setup(
    mut commands: Commands,
    mut meshes: ResMut<Assets<Mesh>>,
    mut surfaces: ResMut<Assets<SurfaceMaterial>>,
    mut cloud_mats: ResMut<Assets<CloudMaterial>>,
    mut images: ResMut<Assets<Image>>,
    mut shaders: ResMut<Assets<Shader>>,
    mut media: ResMut<Assets<ScatteringMedium>>,
    mut gizmo_store: ResMut<GizmoConfigStore>,
    size: Res<InitialSize>,
    maps: Res<Maps>,
) {
    // Render target, plus a persistent readback that copies it to the CPU every frame.
    let mut img = Image::new_target_texture(size.0, size.1, TextureFormat::Rgba8UnormSrgb, None);
    img.texture_descriptor.usage |= TextureUsages::COPY_SRC;
    let target = images.add(img);
    commands.insert_resource(Target(target.clone()));
    commands
        .spawn(Readback::texture(target.clone()))
        .observe(|mut ev: On<ReadbackComplete>, mut latest: ResMut<Latest>| {
            latest.0 = Some(std::mem::take(&mut ev.data));
        });

    commands.spawn((
        Camera3d::default(),
        RenderTarget::from(target),
        // Raymarching integrates the scattering along each ray, which the lookup-table mode
        // only approximates near the ground; it's the mode for planets seen from orbit.
        AtmosphereSettings { rendering_method: AtmosphereMode::Raymarched, sky_max_samples: 32, ..default() },
        Exposure { ev100: 13.4 }, // raw sunlight is ~130,000 lux; expose for it
        Tonemapping::AcesFitted,
        Bloom::NATURAL,
        Transform::from_xyz(0.0, 0.0, 3.0).looking_at(Vec3::ZERO, Vec3::Y),
    ));

    // Earth's atmosphere is specified in meters around a 6,360 km planet; scaling its transform
    // maps that onto our unit sphere. The rotation is ignored (it's spherically symmetric).
    let earth = Atmosphere::earth(media.add(ScatteringMedium::earth(256, 256)));
    let scale = Transform::from_scale(Vec3::splat(1.0 / earth.inner_radius));
    commands.spawn((earth, scale, GlobalTransform::from(scale)));

    commands.spawn((
        DirectionalLight { illuminance: lux::RAW_SUNLIGHT, ..default() },
        SunDisk::EARTH,
        Transform::default(),
    ));

    let _ = shaders.insert(&SURFACE_SHADER, Shader::from_wesl(SURFACE_WESL, "plate_globe/surface.wesl"));
    let _ = shaders.insert(&CLOUDS_SHADER, Shader::from_wesl(CLOUDS_WESL, "plate_globe/clouds.wesl"));

    let m = maps.0.lock().unwrap().take().expect("earth maps already used");
    let clouds = images.add(m.clouds);
    commands.spawn((
        Mesh3d(meshes.add(globe_mesh(1.0))),
        MeshMaterial3d(surfaces.add(SurfaceMaterial {
            base: StandardMaterial {
                base_color_texture: Some(images.add(m.albedo)),
                metallic_roughness_texture: Some(images.add(m.roughness)),
                perceptual_roughness: 1.0, // multiplied by the texture
                metallic: 0.0,
                ..default()
            },
            extension: SurfaceExt {
                relief: images.add(m.relief),
                clouds: clouds.clone(),
                lights: images.add(m.lights),
                params: Vec4::ZERO,
            },
        })),
    ));
    commands.spawn((
        Mesh3d(meshes.add(globe_mesh(1.006))),
        MeshMaterial3d(cloud_mats.add(CloudMaterial {
            base: StandardMaterial {
                base_color: Color::WHITE,
                perceptual_roughness: 1.0,
                reflectance: 0.0,
                alpha_mode: AlphaMode::Blend,
                ..default()
            },
            extension: CloudExt { cover: clouds, params: Vec4::ZERO },
        })),
        NotShadowCaster,
    ));

    let (config, _) = gizmo_store.config_mut::<DefaultGizmoConfigGroup>();
    config.line.width = 2.0;
}

fn animate(
    clock: Res<Clock>,
    mut gizmos: Gizmos,
    mut camera: Query<&mut Transform, With<Camera3d>>,
    mut sun: Query<&mut Transform, (With<DirectionalLight>, Without<Camera3d>)>,
    mut surfaces: ResMut<Assets<SurfaceMaterial>>,
    mut cloud_mats: ResMut<Assets<CloudMaterial>>,
    overlay: Res<Overlay>,
) {
    let t = clock.t;
    let (sun_lat, sun_lon) = subsolar(clock.unix);
    for mut tf in &mut sun {
        *tf = Transform::from_translation(geo(sun_lat, sun_lon) * 10.0).looking_at(Vec3::ZERO, Vec3::Y);
    }
    // Orbit eastward from just past the terminator on the night side, so the first thing in
    // view is the day/night line, then sweep over the day side and back around.
    for mut tf in &mut camera {
        let lon = sun_lon - 75.0 + t * 4.0;
        let lat = 18.0 + 14.0 * (t * 0.07).sin();
        *tf = Transform::from_translation(geo(lat, lon) * 3.0).looking_at(Vec3::ZERO, Vec3::Y);
    }

    // Clouds drift east about 1° a second, faster than any real weather, so it reads as motion.
    let drift = (t * 0.018).rem_euclid(std::f32::consts::TAU);
    for (_, m) in surfaces.iter_mut() {
        m.extension.params = Vec4::new(overlay.relief, drift, 2.5, 0.0);
    }
    for (_, m) in cloud_mats.iter_mut() {
        m.extension.params = Vec4::new(drift, 0.0, 0.0, 0.0);
    }

    if !overlay.flights {
        return;
    }
    let verm = LinearRgba::from(plate(0xe03c28));
    for &(_, lat, lon) in &CITIES {
        let p = geo(lat, lon);
        gizmos.circle(Isometry3d::new(p * 1.008, Quat::from_rotation_arc(Vec3::Z, p)), 0.007, verm * 1.5);
    }
    for (i, &(a, b)) in ROUTES.iter().enumerate() {
        let (a, b) = (geo(CITIES[a].1, CITIES[a].2), geo(CITIES[b].1, CITIES[b].2));
        // Each flight: the head races ahead, the tail follows, then a ring pulses on arrival.
        let period = 6.0 + 1.7 * (i % 5) as f32;
        let p = ((t + i as f32 * 1.37) / period).fract();
        let (head, tail) = (smoothstep(0.0, 0.55, p), smoothstep(0.2, 0.75, p));
        if head - tail > 1e-3 {
            gizmos.linestrip_gradient((0..=40).map(|k| {
                let f = k as f32 / 40.0;
                let c = verm * (0.3 + 4.0 * f.powi(3));
                (arc(a, b, tail + (head - tail) * f), c.with_alpha(f))
            }));
        }
        let ring = smoothstep(0.55, 0.95, p);
        if ring > 0.0 && ring < 1.0 {
            gizmos.circle(Isometry3d::new(b * 1.008, Quat::from_rotation_arc(Vec3::Z, b)), 0.01 + 0.04 * ring, (verm * 2.0).with_alpha(1.0 - ring));
        }
    }
}

/// The surface maps, built before the app starts and handed to `setup` once.
#[derive(Resource)]
struct Maps(std::sync::Mutex<Option<EarthMaps>>);

/// Command-line overlay options.
#[derive(Resource, Clone, Copy)]
struct Overlay { relief: f32, flights: bool }

/// Build the headless app and finish plugin setup ourselves, since we never call `app.run()`.
fn build_app(w: u32, h: u32, maps: EarthMaps, overlay: Overlay) -> App {
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
    .add_plugins((MaterialPlugin::<SurfaceMaterial>::default(), MaterialPlugin::<CloudMaterial>::default()))
    .insert_resource(ClearColor(plate(0x0a0a0a)))
    // A little ambient (in nits, before exposure) so the night side isn't pure black.
    .insert_resource(GlobalAmbientLight { color: plate(0x909090), brightness: 900.0, ..default() })
    .insert_resource(InitialSize(w, h))
    .insert_resource(Maps(std::sync::Mutex::new(Some(maps))))
    .insert_resource(overlay)
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

/// Run one frame and wait for the GPU, so the readback it queued gets mapped.
fn step(app: &mut App, t: f32, unix: f64) {
    *app.world_mut().resource_mut::<Clock>() = Clock { t, unix };
    app.update();
    let _ = app.world().resource::<RenderDevice>().poll(PollType::wait_indefinitely());
}

fn now_unix() -> f64 {
    SystemTime::now().duration_since(UNIX_EPOCH).map(|d| d.as_secs_f64()).unwrap_or(0.0)
}

/// "19:42 UTC · sun 19.9°S 112.3°W" for the caption.
fn sun_caption(unix: f64) -> String {
    let (lat, lon) = subsolar(unix);
    let day = unix.rem_euclid(86_400.0) as u32;
    format!(
        "{:02}:{:02} UTC · sun over {:.1}°{} {:.1}°{}",
        day / 3600, day / 60 % 60,
        lat.abs(), if lat >= 0.0 { 'N' } else { 'S' },
        lon.abs(), if lon >= 0.0 { 'E' } else { 'W' },
    )
}

// ---------------------------------------------------------------- terminal plumbing
// Same transport as plate-field.rs.

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
            let name = format!("/pglb{}-{}", std::process::id(), self.seq);
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
    let name = format!("/pglb{}-probe", std::process::id());
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

fn dump(path: &str, t: f32, speed: f64, overlay: Overlay) {
    let (w, h) = (960, 540);
    let mut app = build_app(w, h, earth_maps(), overlay);
    // A few frames: one to build the scene, one for the readback to land, spare for pipelines.
    let unix = now_unix() + t as f64 * speed;
    for _ in 0..6 {
        step(&mut app, t, unix);
    }
    let data = app.world_mut().resource_mut::<Latest>().0.take().expect("no frame read back");
    let img = Image::new(
        Extent3d { width: w, height: h, ..default() },
        TextureDimension::D2,
        data,
        TextureFormat::Rgba8UnormSrgb,
        default(),
    );
    img.try_into_dynamic().expect("convert frame").save(path).expect("write frame");
    eprintln!("{}", sun_caption(unix));
}

fn main() {
    let args: Vec<String> = std::env::args().collect();
    let overlay = Overlay { relief: arg(&args, "--relief", 6.0), flights: !args.iter().any(|a| a == "--no-flights") };
    let speed: f64 = arg(&args, "--speed", 1.0);
    if let Some(path) = args.iter().position(|a| a == "--dump").and_then(|i| args.get(i + 1)) {
        return dump(path, arg(&args, "--time", 0.0), speed, overlay);
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
    let maps = earth_maps(); // before the alternate screen, so first-run downloads show progress
    let mut geom = geometry(in_tmux, None);
    let (mut img_cols, mut img_rows, mut w, mut h) = layout(geom);
    let mut app = build_app(w, h, maps, overlay);
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
    let unix0 = now_unix();
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

        let elapsed = (frame_start - start).as_secs_f64();
        let unix = unix0 + elapsed * speed;
        let g0 = Instant::now();
        step(&mut app, elapsed as f32, unix);
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
            "\x1b[{};1H \x1b[38;5;9m●\x1b[0m plate-globe  \x1b[38;5;8m{}{} · bevy · {}×{}px → {}×{} cells · {:5.1}/{} fps · gpu {:4.1} ms · tty wait {:4.1} ms · {} · {}{} · ctrl-c to quit\x1b[0m  {}\x1b[K",
            img_rows + 1, sun_caption(unix),
            if speed != 1.0 { format!(" (×{speed})") } else { String::new() },
            w, h, img_cols, img_rows, fps, target_fps, gpu_ms, tty_ms, gpu,
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
