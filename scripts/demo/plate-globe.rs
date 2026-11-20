//usr/bin/env nix shell nixpkgs#rust-script nixpkgs#cargo nixpkgs#rustc --command rust-script -d 'bevy={version="0.20.1",default-features=false,features=["3d_bevy_render","default_app","std","multi_threaded"]}' -d 'image={version="0.25",default-features=false,features=["jpeg"]}' -d flate2=1 -d base64=0.22 -d libc=0.2 "$0" "$@"; exit $?
//! plate-globe — the Earth, rendered by Bevy on the GPU and streamed into the terminal over the
//! Kitty graphics protocol. Bevy has no globe entity, but it has the parts for one:
//!   - a UV sphere with an `ExtendedMaterial`: Bevy's PBR `StandardMaterial` plus a small WESL
//!     shader that adds terrain relief (normals tilted by real elevation slopes, exaggerated so
//!     mountain ranges catch the low sun), cloud shadows, and city lights that fade in at dusk
//!   - a second, translucent sphere just above it carrying the clouds, fixed to the planet but
//!     evolving in place: they churn along banded winds and eddies, and form and dissipate
//!   - `Atmosphere` (Hillaire 2020 scattering), raymarched so it works from orbit: the blue
//!     limb, the reddened terminator and the haze over the day side are all physically computed
//!   - a `DirectionalLight` + `SunDisk` at real sunlight brightness, placed over the actual
//!     subsolar point for the current UTC time, so the day/night line is the real one
//!   - the real night sky behind it: the 8,404 naked-eye stars of the Yale Bright Star Catalogue
//!     (embedded), colored by temperature and turned to the actual sidereal time, so the stars
//!     and the sun agree; plus a procedural Milky Way laid along the true galactic plane
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
    mesh::{Indices, PrimitiveTopology},
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

/// Cloud cover, shared by both shaders. The clouds are pinned to the planet: a flow map moves
/// them along banded winds (easterly trades, mid-latitude westerlies, polar easterlies) plus
/// slowly evolving eddies, but the displacement oscillates around zero instead of accumulating,
/// so weather churns in place and never slides over the continents as one sheet. A drifting
/// noise threshold makes clouds form and dissipate.
const CLOUD_LIB: &str = r#"
const FLOW_PERIOD: f32 = 9.0; // seconds per flow-map cycle
const FLOW_SPAN: f32 = 3.0;   // degrees of travel per cycle at unit wind

fn hash3(p: vec3<f32>) -> f32 {
    var q = fract(p * 0.1031);
    q = q + dot(q, q.yzx + 33.33);
    return fract((q.x + q.y) * q.z);
}

fn vnoise(p: vec3<f32>) -> f32 {
    let i = floor(p);
    let f = fract(p);
    let u = f * f * (3.0 - 2.0 * f);
    let x00 = mix(hash3(i), hash3(i + vec3(1.0, 0.0, 0.0)), u.x);
    let x10 = mix(hash3(i + vec3(0.0, 1.0, 0.0)), hash3(i + vec3(1.0, 1.0, 0.0)), u.x);
    let x01 = mix(hash3(i + vec3(0.0, 0.0, 1.0)), hash3(i + vec3(1.0, 0.0, 1.0)), u.x);
    let x11 = mix(hash3(i + vec3(0.0, 1.0, 1.0)), hash3(i + vec3(1.0, 1.0, 1.0)), u.x);
    return mix(mix(x00, x10, u.y), mix(x01, x11, u.y), u.z);
}

/// Cloud coverage in [0, 1] at unit-sphere point n (texture coordinate uv) at weather time t.
/// grad_uv supplies the derivatives for mip selection, so the flow offsets can't cause seams.
fn cloud_cover(tex: texture_2d<f32>, smp: sampler, n: vec3<f32>, uv: vec2<f32>, grad_uv: vec2<f32>, t: f32) -> f32 {
    let lat = asin(clamp(n.y, -1.0, 1.0));
    let coslat = max(cos(lat), 0.2);
    let zonal = -cos(4.0 * lat) * 0.6 * smoothstep(1.45, 1.2, abs(lat)); // + is eastward
    let q = n * 2.5 + vec3(0.0, 0.0, t * 0.02);
    let eddy = vec2(vnoise(q), vnoise(q + vec3(17.1, 3.7, 9.2))) - 0.5;
    let wind = vec2(zonal + eddy.x * 1.6, eddy.y * 1.2) * FLOW_SPAN; // degrees east, north
    let flow = vec2(wind.x / (360.0 * coslat), -wind.y / 180.0);

    // Two samples half a cycle apart; each resets to zero offset while its weight is zero.
    let ph0 = fract(t / FLOW_PERIOD + vnoise(n * 6.0));
    let ph1 = fract(ph0 + 0.5);
    let gx = dpdx(grad_uv);
    let gy = dpdy(grad_uv);
    let a = textureSampleGrad(tex, smp, uv - flow * (ph0 - 0.5), gx, gy).r;
    let b = textureSampleGrad(tex, smp, uv - flow * (ph1 - 0.5), gx, gy).r;
    let c = mix(a, b, abs(2.0 * ph0 - 1.0));

    let grow = (vnoise(n * 3.0 + vec3(t * 0.015, 0.0, -t * 0.011)) - 0.5) * 0.25;
    return smoothstep(0.08 + grow, 0.85 + grow, c);
}
"#;

/// Surface: StandardMaterial plus relief-mapped normals, cloud shadows and night lights.
const SURFACE_WESL: &str = r#"
import bevy_pbr::{
    render::pbr_fragment::pbr_input_from_standard_material,
    render::mesh_view_bindings::lights,
    render::forward_io::{VertexOutput, FragmentOutput},
    render::pbr_functions::{apply_pbr_lighting, main_pass_post_lighting_processing},
};

struct Surface { params: vec4<f32> } // x: relief strength, y: weather time (s), z: night-light nits

@group(constants::MATERIAL_BIND_GROUP) @binding(100) var relief_tex: texture_2d<f32>;
@group(constants::MATERIAL_BIND_GROUP) @binding(101) var relief_smp: sampler;
@group(constants::MATERIAL_BIND_GROUP) @binding(102) var clouds_tex: texture_2d<f32>;
@group(constants::MATERIAL_BIND_GROUP) @binding(103) var clouds_smp: sampler;
@group(constants::MATERIAL_BIND_GROUP) @binding(104) var lights_tex: texture_2d<f32>;
@group(constants::MATERIAL_BIND_GROUP) @binding(105) var lights_smp: sampler;
@group(constants::MATERIAL_BIND_GROUP) @binding(106) var<uniform> surface: Surface;

const SLOPE_SCALE: f32 = 4.0;

// @cloud-lib

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

    // Cloud shadows: the cloud cover a little sunward of this point.
    let sun = lights.directional_lights[0].direction_to_light;
    let mu = dot(n, sun);
    let offset = (sun - n * mu) * 0.006;
    let cuv = in.uv + vec2(dot(offset, east) / 6.2832, -dot(offset, north) / 3.1416);
    let cover = cloud_cover(clouds_tex, clouds_smp, n, cuv, in.uv, surface.params.y);
    pbr_input.directional_shadow_factor = 1.0 - 0.55 * cover;

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

/// Clouds: an alpha-blended shell just above the surface, fixed to the planet.
const CLOUDS_WESL: &str = r#"
import bevy_pbr::{
    render::pbr_fragment::pbr_input_from_standard_material,
    render::forward_io::{VertexOutput, FragmentOutput},
    render::pbr_functions::{apply_pbr_lighting, main_pass_post_lighting_processing},
};

struct Weather { params: vec4<f32> } // x: weather time (s)

@group(constants::MATERIAL_BIND_GROUP) @binding(100) var cover_tex: texture_2d<f32>;
@group(constants::MATERIAL_BIND_GROUP) @binding(101) var cover_smp: sampler;
@group(constants::MATERIAL_BIND_GROUP) @binding(102) var<uniform> weather: Weather;

// @cloud-lib

@fragment
fn fragment(in: VertexOutput, @builtin(front_facing) is_front: bool) -> FragmentOutput {
    var pbr_input = pbr_input_from_standard_material(in, is_front);
    let cover = cloud_cover(cover_tex, cover_smp, normalize(in.world_normal), in.uv, in.uv, weather.params.x);
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

// ---------------------------------------------------------------- sky

/// Marks the star and Milky Way spheres, which turn with sidereal time.
#[derive(Component)]
struct Sky;

const SKY_RADIUS: f32 = 500.0;
/// Overall brightness of the stars and the Milky Way. Unlit, so these are display values: the
/// camera's sunlight exposure would otherwise make the sky pitch black, as it is in photos.
const STAR_GAIN: f32 = 4.0;
const MILKY_WAY_GAIN: f32 = 0.11;

/// Greenwich mean sidereal time at a Unix time, in radians.
fn gmst(unix: f64) -> f64 {
    let n = (unix - 946_728_000.0) / 86_400.0; // days since J2000.0
    (280.460_618_37 + 360.985_647_366_29 * n).to_radians()
}

/// The sky's rotation at a Unix time. The meshes are built with right ascension as longitude;
/// a star at right ascension α is over Earth longitude α − GMST, and turning about +Y adds to
/// longitude (see `geo`).
fn sky_rotation(unix: f64) -> Quat {
    Quat::from_rotation_y(-gmst(unix).rem_euclid(std::f64::consts::TAU) as f32)
}

struct Star { ra: f32, dec: f32, vmag: f32, bv: f32 }

fn stars() -> Vec<Star> {
    let b64: String = STARS.split_whitespace().collect();
    let z = base64::engine::general_purpose::STANDARD.decode(b64).expect("decode star catalog");
    let mut raw = Vec::new();
    flate2::read::ZlibDecoder::new(&z[..]).read_to_end(&mut raw).expect("inflate star catalog");
    let n = raw.len() / 6;
    let u16_at = |i: usize| u16::from_le_bytes([raw[2 * i], raw[2 * i + 1]]);
    let mut ra = 0u16;
    (0..n)
        .map(|i| {
            ra = ra.wrapping_add(u16_at(i));
            Star {
                ra: ra as f32 / 65536.0 * 360.0,
                dec: u16_at(n + i) as f32 / 65535.0 * 180.0 - 90.0,
                vmag: raw[4 * n + i] as f32 / 30.0 - 2.0,
                bv: raw[5 * n + i] as i8 as f32 / 50.0,
            }
        })
        .collect()
}

/// Linear color for a B−V index: Ballesteros' temperature, then a blackbody fit, normalized to
/// unit luminance and mostly desaturated (stars look far whiter than their blackbody colors).
fn star_color(bv: f32) -> [f32; 3] {
    let t = 46.0 * (1.0 / (0.92 * bv + 1.7) + 1.0 / (0.92 * bv + 0.62)); // kelvin / 100
    let r = if t <= 66.0 { 255.0 } else { 329.7 * (t - 60.0).powf(-0.1332) };
    let g = if t <= 66.0 { 99.47 * t.ln() - 161.12 } else { 288.12 * (t - 60.0).powf(-0.0755) };
    let b = if t >= 66.0 { 255.0 } else if t <= 19.0 { 0.0 } else { 138.52 * (t - 10.0).ln() - 305.04 };
    let c = [r, g, b].map(|x: f32| lin(x.clamp(0.0, 255.0) as u8));
    let y = 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2];
    c.map(|x| 0.45 * x / y + 0.55)
}

/// One small quad per star on a sphere around the planet, tangent to it (so it faces the
/// camera, which never strays far from the center). Brightness and color ride on vertex colors.
fn star_mesh() -> Mesh {
    let (mut pos, mut nrm, mut uv, mut col, mut idx) = (vec![], vec![], vec![], vec![], vec![]);
    for s in stars() {
        let d = geo(s.dec, s.ra);
        let e = Vec3::Y.cross(d).try_normalize().unwrap_or(Vec3::X);
        let n = d.cross(e);
        // Magnitudes compressed: a 6.5 star is ~1/35 as bright as a 0 star instead of 1/400,
        // or the faint ones would be invisible on a terminal.
        let flux = 10f32.powf(-0.22 * s.vmag) * STAR_GAIN;
        let size = SKY_RADIUS * 0.0045 * (1.0 + 0.3 * (2.5 - s.vmag).max(0.0));
        let c = star_color(s.bv).map(|x| x * flux);
        let base = pos.len() as u32;
        for (du, dv) in [(-1.0, -1.0), (1.0, -1.0), (1.0, 1.0), (-1.0, 1.0)] {
            pos.push((d * SKY_RADIUS + (e * du + n * dv) * size).to_array());
            nrm.push((-d).to_array());
            uv.push([(du + 1.0) * 0.5, (dv + 1.0) * 0.5]);
            col.push([c[0], c[1], c[2], 1.0]);
        }
        idx.extend([base, base + 1, base + 2, base, base + 2, base + 3]);
    }
    Mesh::new(PrimitiveTopology::TriangleList, default())
        .with_inserted_attribute(Mesh::ATTRIBUTE_POSITION, pos)
        .with_inserted_attribute(Mesh::ATTRIBUTE_NORMAL, nrm)
        .with_inserted_attribute(Mesh::ATTRIBUTE_UV_0, uv)
        .with_inserted_attribute(Mesh::ATTRIBUTE_COLOR, col)
        .with_inserted_indices(Indices::U32(idx))
}

/// A soft round point-spread sprite: Gaussian core plus a faint halo, white with alpha falloff.
fn star_sprite() -> Image {
    const S: usize = 64;
    let px = (0..S * S)
        .flat_map(|i| {
            let (x, y) = (((i % S) as f32 + 0.5) / S as f32 - 0.5, ((i / S) as f32 + 0.5) / S as f32 - 0.5);
            let r2 = (x * x + y * y) * 4.0; // 0 at the center, 1 at the edge
            let a = ((-r2 * 9.0).exp() + 0.06 * (-r2 * 2.5).exp()) * (1.0 - r2).max(0.0);
            [255, 255, 255, (a.min(1.0) * 255.0) as u8]
        })
        .collect();
    mipmapped(S, S, px, TextureFormat::Rgba8Unorm)
}

/// Value noise in [0, 1] on a 3D lattice.
fn vnoise(p: Vec3) -> f32 {
    let hash = |q: IVec3| {
        let h = (q.x as u32).wrapping_mul(0x8da6b343) ^ (q.y as u32).wrapping_mul(0xd8163841) ^ (q.z as u32).wrapping_mul(0xcb1ab31f);
        let h = (h ^ (h >> 15)).wrapping_mul(0x2c1b3c6d);
        (h ^ (h >> 12)) as f32 / u32::MAX as f32
    };
    let i = p.floor();
    let f = p - i;
    let u = f * f * (Vec3::splat(3.0) - 2.0 * f);
    let i = i.as_ivec3();
    let c = |x, y, z| hash(i + IVec3::new(x, y, z));
    let x0 = (c(0, 0, 0) * (1.0 - u.x) + c(1, 0, 0) * u.x) * (1.0 - u.y) + (c(0, 1, 0) * (1.0 - u.x) + c(1, 1, 0) * u.x) * u.y;
    let x1 = (c(0, 0, 1) * (1.0 - u.x) + c(1, 0, 1) * u.x) * (1.0 - u.y) + (c(0, 1, 1) * (1.0 - u.x) + c(1, 1, 1) * u.x) * u.y;
    x0 * (1.0 - u.z) + x1 * u.z
}

fn fbm(p: Vec3) -> f32 {
    (0..5).map(|o| vnoise(p * 2f32.powi(o)) * 0.5f32.powi(o + 1)).sum::<f32>() / (1.0 - 0.5f32.powi(5))
}

/// The Milky Way as a faint band, equirectangular in right ascension/declination (laid out like
/// the Earth maps): a thin disk by galactic latitude, a bulge toward Sagittarius, mottling,
/// and the dark Great Rift running from Cygnus to Sagittarius.
fn milky_way() -> Image {
    const W: usize = 1024;
    const H: usize = 512;
    // Equatorial (ICRS) -> galactic: rows are the galactic x, y, z axes.
    const M: [[f32; 3]; 3] = [
        [-0.054876, -0.873437, -0.483835],
        [0.494109, -0.444830, 0.746982],
        [-0.867666, -0.198076, 0.455984],
    ];
    let (blue, warm) = ([0.70, 0.78, 1.0], [1.0, 0.82, 0.60]);
    let px = (0..W * H)
        .flat_map(|i| {
            let ra = ((i % W) as f32 + 0.5) / W as f32 * std::f32::consts::TAU - PI;
            let dec = PI / 2.0 - ((i / W) as f32 + 0.5) / H as f32 * PI;
            let v = Vec3::new(dec.cos() * ra.cos(), dec.cos() * ra.sin(), dec.sin());
            let g = Vec3::from(M.map(|row| Vec3::from(row).dot(v)));
            let (b, l) = (g.z.asin(), g.y.atan2(g.x)); // galactic latitude, longitude (0 at center)
            let center = (-(l / 1.1).powi(2)).exp();
            let bulge = (-(l / 0.28).powi(2) - (b / 0.14).powi(2)).exp();
            let width = 0.05 + 0.035 * center;
            let disk = (-(b / width).powi(2)).exp() * (0.25 + 0.75 * center);
            let mottle = (0.2 + 1.6 * fbm(v * 9.0) * fbm(v * 23.0 + 3.0)).powf(1.6);
            let rift = (-((b - 0.035) / 0.03).powi(2)).exp() * smoothstep(1.35, 0.9, l) * smoothstep(-0.45, -0.15, l);
            let lane = 1.0 - 0.75 * rift * (0.5 + fbm(v * 11.0 + 7.0));
            let k = ((disk * mottle + 0.6 * bulge * mottle.sqrt()) * lane).max(0.0) * MILKY_WAY_GAIN;
            let t = bulge.min(1.0);
            let c: [u8; 3] = std::array::from_fn(|j| enc(k * (blue[j] + (warm[j] - blue[j]) * t)));
            [c[0], c[1], c[2], 255]
        })
        .collect();
    mipmapped(W, H, px, TextureFormat::Rgba8UnormSrgb)
}

/// Yale Bright Star Catalogue, 5th ed. (Hoffleit & Warren 1991, public domain): the 8,404 stars
/// to magnitude 6.5, sorted by right ascension and packed as zlib + base64 little-endian columns:
/// RA deltas (u16, 1/65536 turn), declination (u16, 0..65535 = −90°..90°), V magnitude (u8,
/// (V + 2) × 30) and B−V color index (i8, × 50).
const STARS: &str = "
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
k2XCeiToiJFwapKNz2RQ+VPCZKCFBrgCm7QAn/2mo2dVRG/FxIqAibNVHHySmYYyIuaaxQDzJIPVzzzLKIh1BKF7UtDnJGO+weHH
fBm4VhKf0yKeAqXxs3k28E8SUSJiso2MXREaxiUKVkri4EMpmJEqAN85/ClYKXglgFqhj9NtbOzTzkyScxCh+/9peh6lc/h5M40/
S0g8RaQPvkmEy3UOVpwz3UYKTNYTFcAcjEZ0fG6Sgc+IzUxLCOCTp1SclaUiVsbEKeiZ2p7wbMqACBL1AR2yHmI+QBHn/lTgGVQa
/1kVMvZ9iHirgx6SV4NKA74oCpKiYo2nz0cYiDpFCu2SCRWGOHRSDHB6hQ18EeRaFhlxR8KPSWJlKoxPBZIh0vC4rQS9fWIylsAj
rLAnwgErZoP1iMK0HA29LRmfy2HgJBxP+9VAwkzgARU5S+iDPmqKKM4B6YKtENSyMW4qYLeVBpokSaLYunQN3gg6WWMudW7NwpXi
4rdtjw1kJ2cUdR31Gy0XKyc/zI3sCSm857/68cOaO3nRYcuEkh4cXSVf/Mh94MUul/z5t59kCFUrXDc297jv1DM7zHF1WM6/Yd7e
RTkpKWE9pNUygws6XzTMm69yI/Tvef4fFokI3N1amll8SiGeFJPuz/LKHstZVV+jwgzvCh75FdgaaNb/PvVYs/jKyOSBHUFeZeV3
ey92sSWdliS+JR0/XGYbueE29ZDh2Mso9YlVhe+3eg9e6y1PdT5eaJeS8vbIsTm/9+4q+0fx0r7fQ0/Fzi9bF6lX3R7/c+JOzvvb
SZOnC1XFH9vetH+bvydI2Ce5IbJuzoncCslIC2fVhVmD0zFhWd57PG7qhsZZnHUsfVtn3vjwdH+6RoqG+uTmi89Lp5uDNBbuLrgr
funT813yX/3ePdxgQqt+luWcz5p31OL8tsGYDWHsi6e7Jm+Gz3E80VPzub9rSrO9Y97ZYP8DaUX9PUZnn+1d2Or7xc0mtzVJtzA6
+op66OV1yofTFjE7Og0kHt4693z21uvuOh6uTvqPT8eu+iv+VWKQq/iYkubesYMrvOyb5pdeilm3L27XX53RYZYXT3wPo9TWPx25
way607ShvbbUe1XyXwrhQS/DNxeWJElNbM45X2slU292rTdkeO3Z0LUjLnbTiaSTOaZh920nXty+UuQ/oaF0PyQs792tM8GmQzUa
7y9Upbg1CX5r3PnourKSxfib9vK0fP8DXT8Ssq/p3Ai4dWr47s0rTzx3Gp2y6Mmqdtmf1NqnHfLQetmVhIWldSc+Pe92eae//fys
JX/OtuijLro4srBsxRmVdZRl07f+Xr/3wvbb+nsENtnWXEra3FrS+rO4woqc/DgkbtuPK1JTj0LUtKSSfzvkteQdL+lTuMTaFGc0
fa0oqfefC38bntl94EvTx7lutX4pd48ad2ZtuPok4dJAb9fQ4vt/tUzuyZyeyln8d9ZJbbdTe07fPrv5a/u5zdW7/649mvqxtCVv
kbWA8oefsv27/k7KqVKdPjFnY+IZ3aGzXU75V6/5vqMlhmd/uf9od9ybkyeno4LzUwv3X1Ns+bVkcH/H0Nf3wanNqTrpI2t+Oey1
+Zidqpa40zL24/M9N58/njvg0HRpND4/pCk+7pDP8/2pI9Un8xKj7HzLCqyswuUb750+tmkkkPzw3TMT8+s1+tbvluYNOJlVuX++
FiBKSW/4z+rGl8HBNbaNnb7ec+9ujx2ZrJeLyfBzH58199mIQ1Uisy25Qf8/ttZ46jVBj8cvq04eD591wq9OwlDSsHlq6Ej1aEtn
gsjFkjHXo3ueJzQeK9NucZ91gOEbfn38cdX8680nsxKfB95OO6l0S/r8+b6F6/zW3Ljaesro6tZmxpbQ4DsZ8gEjpk/mNzlcvvdD
SMP9xCmlequNP4Zy9ymPXVpyMTHcdd+O/ywGt9YvnJ7wTIq/ZHneZOLNarE9b48ouiY1JTZtKtJYJH55q/2We3UtT49cULk4mKS9
TXTTzp2FtKHGBf1P/hn8GrZiQZPl8oay7k+zK3Z+9z5x+5/xBK2cqo8tL++bOXBmR0TQI1YXPU5Z6hdtc+f5uw3vNuRevOynU+05
feXdsn6LmOr7zFf6Bb9fPO3UzvrSUJQ//9j8Y37L/nxr82akTLDApK2iM3Tn7SHzEzLXh1cp2uXXt3563nl6YEVIv2311CHTo00b
DxUfetZpWD6YdKv359XVubJ7w9rrc3RaPZduL58dcbTmz+Mur9rOu17fdGaDSvPDFMculZaOvZ1J/b/PjC5Qu/ogvXf/nP3+1/IL
p656Nh/b/alNLkjmdMSZM9k7xrMdrq5LMHy/x/XMknOBypUFexOfrNpqN5q39vKs0EcjdjLLTP9YOXrJKkj53F+OMlvNdARyCq/E
q64/tzFePyYvUtMytsu87/W5icJXi7eoscrn7RlbUrVn+tGKnY1blPc/63gfZtkcXDC3wWxDrsin/3xiog+W5Bl5zBoIrznstSXy
7nI/02upbZvXHBYd8hv4XDKdOlnq6Pff5oNVn3qlDl3zEuoY2X9un6NJwQPd7L83b33ZPSTs991Vd/iPIosdGQVKCa+Uf9tVJA9s
ip3n45zTRcn3io3PXuN600r7SFqz09aTpipTnWNhlxqLgp2UVVd3p3f+Pu621sKEeta+4bjP2Zq0xxEVB6tqVx4sXqV+U8UsfO7B
ygP0FTc/1feQGq91sJ71abzyuVUvNWRwVTzEzn+8i+5pJZU/bOeZd9nEeVZESs30QOvp99f0lv54UqJxK25bcthkUp3EuJ/r3BXF
wwJmXabsSfHGvNuvy/Lu+6fsbJA4czjr5flVxZv9YvpEQ/tdXw+vbIkL7XPqc+LkRB+WTX6sxj7wbFlAa0CrcPCYT9BIXs7ecq0z
FsNpW19mp16QTxP0ry1p33Uz6Uz6qNyVjYbFq0LF0oysjHdzdA3TugrLa2WnrA4dOrLryujljx9ObVueIX8/rqFHxOVMrlKsv90F
65GRRsHyrWcnTwT2VHbbdO03twp9Wmmyxu/w9qyKbcLNDz9dfHV2mcOxM13XbR6fWVeape+R98SjaKzZ721L8rEngWl7R/Y5XE1N
+SBWk+E3kHsy6fx438/k6iPSluEPHh4iazYfvzpLYLm85s+wvry4c40r9+5fdG6ySDh8IOSEXUFX6IMt77x78ju1A803SrRGhO4Y
FbKcGLfvbgrKb/k1/lfq38XZPv8ofq3S7nh1trZloP/e/dvlkUqvPKbHzztoBNzeorjN1vNjwtlxiqfk/gM349uen7W+ueZsrsap
0z/ifNOPXQ+xrxJ9cCn+hraj8QuVSruxNWM7LM9nXtyUqLpq24Luf8ftzm4L8hg7/b3gVMDCpVsmTyQcWKhdnlx9/fhhg0ue1yzC
p5YEN0y27/H9ljSrNPKmZKLW6s1jTaK3CrYVHHb6WLP12PcrOWl2/idafmcceq2ZVFSnl+1fFJ3nH1ObyehMHlqQ8Ofdal9as9f+
UYbrzXduX88oJUsnfWvSc6KM35jzuu9Mi3/evYOX51WeKmvfZeHeXp2/pKPi2FT7LsvGTd3tr9u/n6x+JH3vaftEfG+pSLvTsveh
MdIu7ZsuC4RO9HV5yPrd3ap1fvHOPDfHiDw334Li4ybtS9ovPLe4WuRh+EC0n37vyM72HZ9PhHcm/7FlW/yTB/vdS5f0rsjsrD+/
0svKcLzR67/glGv+fVPZU9mNTqImF+I1e6XGRtWfD6i/kDuvmvxtR92mL21/3jp490L7y8MTa60OTej3aS3MfHFAKd7k0EDFnZCG
+valZ6oeN9RrNg3O1p7MXVjRml+0KSBypGR3WXQ0vcil/VKc6g1q5Oodnjt6/a9HrE7pe9J8zqb78pTBg0U9PWqVNT31u4fkhu+f
Ea5+1nQg+p+L82/O/zn+UTP9pmdqSs8uJ4ex/nslgpFO6dvqH+9Y++TH5uKKRqeQvO0v5mzT2/J76K79miQNTcuKcs3qI3fHDl9V
SpvatKv8Zc3ZBT7aPbrWU19vu11zaJlMZ2u8W/xa6N3RknOlEftbl4ZdMz63eO45jq1Y67fWlRVmtV+rk/piz6cd/aNLe6C7MaNG
OWNXROf04U3z0w5V/yMwnR8dpHp6xa2QK/fU6dubW1I6P9ZP3GgITvacrrvdsvxYb1bqlq3trYsv19/U37zfY79k059aRraDO7bt
yG/YWzvcm9y2oNa0/M32kyFfCv+4+vGjhdVg28etUponWjsLlzgYffu63aHu6/qDtc5NS6K21VZs09+bFHfHqvhrfYVV7d61zLqi
au19PrXunmI2Lw/Xry2r/ZDfOzVQkpDdk7hodI+fxssdDV0akVsUa2LSDxm9LnFPXZTilG7YszdSM3nT0pQKp+asuuksi+yo+/N2
9o8Ma3ovjV2fnXOx9kLV7tiYlgox767T8YULjMoyaztqt8c+6CjIy50UnAqo0g+hR6U7HNg9MJY0rOfe1Wa8sHdURWHRUrv2rhvi
5xocR/e9TElZSR4R1L23VUJjJDwsu3Enw+Xzm12VuxqnsoX8/Y78tdrL7/AVictno99lyG8kvRnq9d8Xs7a19kWp99D7aAvH5893
l3+b/32+z/j3ksnGIC+DCp97DtvnDfZ1Vx1blEmX05is2qCnGvgwc4NNpWjZnoKe40f1Eio6nIebai8ZRa+V6oqOrOkrMZz80Z54
cGH1rkzd/uSp7LyV9adjRdrbOu7lJBYOcfZtH4p+NtQwuTpJN75TlHF43SeR3KsZ2ZFTaRucH9xirF9y3LVwZ2Dbqyu+sSPV8tvD
qFmy5uxHg60fRr7erIz1DtnpELrXrrXUc6HnnzXLXvVl55rtmHcpsHe9wQp7fd3mh9dnyX64/t+tzpFlceET4etWj1rGFzXeVM/c
wm4Zy5Quf9ha2N6X0rOuPOWfLZxn+rVLpx90z8sXGrpwWiNoMictRz3hau269coJOq8iMj5Ff71dHydWdHRY6+5U4ZrU5FmTBaQF
ZrE3PfxST7/xK9k3mXPjv9x9Abn7BnZMmKhWTu0fK4w9ZTIV5uWQPr42vX/+n/ePMfaXHzFd9bufeWRgQ3vz2h09K5kL/fZLBHRf
s4v7lZsT774/fqTLS+FuaOZkuH7z6W6hPZqLo/P/LUvNHwtOPapjuO8DZ2PgCC2QmarZU+V866rR2qqSE3Xj+WN5f6Qerr+/ui7n
aJ7/huhet17dobbCehN528VJzNLRgl+RGpkn6/p3L9AbK321f3WRV3/cgdXKEgnjjl/3lDUcrGkIn7eDNVBdW1R/Z/26CEH31Gr3
7LEOuezCnuS8skIBq4G7sUxJ9X82xqXdqfm4o+Nw2qZvI0sitnjuK0pL718UJ9GSVp2f1GhXH371WO75vu5V5q7dahW5DK+ufUF5
oY2zNCMHlFteG/lvL877Mzdoo4pM3pb/tFIz0jNmVahWVFZ89vbLHFznkam8rj7DsP3CurDsFyKy65Z3D1nqLnfLmz7zvDP6YliG
+pEFW5apWtYPbHXrskmoELK6f+9hsP/R8i0ZYq3zlo/0a647srkrPWSvgpNnzmja/V3TG1tWlfd8ajVKfpe1efHIXzc6633qe39m
r+yzzLXMjcrLKthQJzL1viff+0n2gmjztm1L9VeIrT7glfBAttAvPfPKYC5pZ9PKz85XFsXfVlwhvmJFZOHsgxunzwr5vl03YnXp
cs/6gtrNW17HOCz/M3r/vMbt2cfCTO09FzTQk8aqrZPnlu5rmZv1oX3J3SOH/quaa7MqVtlwadi9WewKt2JVkc/G/tufFD43sZ9Q
9TzbLTzkFeGV9k5tf19UWN8h5WVqKfevD+trbrdt7ijMdnM5bLk//MnbxY7djhrCW8uW1Rbdao41s01YsV7NxOyyrrN0s95N6b5N
m43dE9YZrhtoLgrrnQhdcje2eIt2z8/QYt+Iypz2kXGa8VVP0sPR9a86a/OaC8NsJwpMt+1OXp2sYE86Z3zxzYk3g32Xqi8uPdWW
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
164zBfqmJsyljeXOzSEHOm1fa79dGl7cZfxKNy1sv/1su9Taf9TdyhvXO9g+s7i/1FJnrrXd5q9mZce1N9xYkFeXpz1gfTf0zcK3
C2/IKLrc3HZTO0xnLOvmylmvlpnXq+eZt9TrN/87T6lz80563ofif65nzFtdp2r0w23y5r6OvvKQA17uPhv+TR+5m3rV2vGGz2u7
km4F5xKfvyMFF7ZrTDWy/8403r3NwEqz287bIN+o7V7yDuvi0bGIhJCB1jXK9uo2E6eyo91WVXMiHyVc0doZddq82tP/2PPoPZZ9
lpaG1rbXLILsb19z6gxbe2n7VzcJi5a4b1u6nR/YfUztsZJr4P3MXxTxRNQtp27unrI1f3s0L9S1svN2vbLcw9ujxcnNd05DsWfF
tiuLNmrYLHx0k7b0g4folvJvt6Kbyw/fuKe71I90cbtn/2xWfKP4tPvmpD/uXPIafe0m37LRS36oazAvNnN9i8q1lWFGUzrtF8X+
eXFDrXzu4VxFj6TIX95dzr9WNcssyAjRZVuY34qPKwlcO+qY9tCk3FW8cf+k8tY3ghZf9mS5rRs9Kh6mZ38xZHJALCJ+wa/CeauT
sj6oLqpXURN0OL15LOYP46VZe7v14n9XeXV5dX329VbMN357UsQrPSU2Z1m7yfbZyTctjGyjbNYbKSwaehR4y943zOaNxe/BJJeO
edbtWlFHG3yN22I2T3pX9MqIt8xfUvtUbPi4l007OSTO9erBeVYnXM4U39v2IYdeXujW4dM1/X3h5EFNZ6O5+XNfbNiVei0gprTQ
9FyN419HtzRr/Mwke0/bKW7aHdi17+Pku8g845NFjpN/KIyHLbq5btpU59uFD+6/568q++J36M8yY9v4856pzTn3G42PGcf1HXP6
0TTVNGJN1u220tI3OLXWfNDygMiSNTHWP+PrLLKN+wzTjZ94HDzN2lYucrNoU+tFbzWz4bRfyjrF6wf97SNmX20wmresQtf9j3DJ
Tdl6njm79z4PeitctEg61z/x6NpCx4OLXu62N1AtPe1lVuWZG7So0+GmcW96k73npkcP5bO7nUQjKq2vyob7+LnILpvj4LG8zn9Z
/3Ursur5xhs1F9JY+obHjx1NOllfcsbHcPfcOIN9brsZHmYW0yZvXeINfl1XuaOjs84pxnLzgdy9jpm6c09qXzcSXvW3deqmnf6H
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
mlNVdq2/6bRZnObJDfdvB/+aHRy9NrbWK/naovmhrQc0r7A792ctG7LT6Mu4dM5nTuSbhyYiCu6zNKs1CtIfdLxYucD8eJmcKt3a
tfTTmV9aq5yULr/zeLv077kjZaeaf8zyS/Le/jmgLP/Idrk6Z/V9AyqKiWteaBgHFBamV8VknrLO6N8Tr77Ufs4n/bOLO4dmeYVM
nS8I0Pd2iw8ia1DKnQYLltvUbnHOu9K0Wsiq9Hart4Hmi76XBvlqmkGnCrIW6PafFJ23cfX+Xx//XqGWxImKLs3JNdW3O7hwdAFj
qXy9knjaZ/Uu+xTpolYdjcM/rinrSbhpx5aveFtw99xsS8+y7BDl8tkKalckL5p+Mj1hPm2arn0j+ItNsOOBQv2/Or3sNt0Ie1mn
5jbVZfI5PvSu1ucFG03Url7orNm9oCXiXaaGuWLG4naX+ooPi21Evy9aqfbfZGDErWfJen5JI/8qXo1y0H8ptNqw5voR4fYRWXr/
23/sorfN3jWp2eOvUlqzx2O+yA81+t4nec//qjb6t/N0m8DuPeNC+ekr/um8v2u4KGj26hVeDe7XhtbK6lwz+K5i0XFP+XRnWcmP
uVdU9ga3e8q79LisP7Z0QnlXRKea44kro/dK7XMSmO3pszf5f/HMoucdOtfl8cJc4/oCOw07jQTzxT7GuzW6nNXl9SwvLyr3j05Y
t3Vhnto6FyWtswb3Ol3bD7UURjcbiF7vdHCf2H7909qYpx6hOZMf2sf1r+pf2XwlM0d3n/q36KM+c2XXyLmt7ay4F2nzrLT9ZJxL
/9WRiuSsfprZkdAMm5pn+m2zG5V3CGrtdrwU4e7ceGMww7O+V+mr+eqAvUUdhQKrVEcSZ5m1HV36ueWyZFuq6kFV52jV3LjcuLBF
oeaGd29UfMj9kPsisqJCSXdfqatStXm8oY/Gj1sKhvedzPVO5Xp6HFq+++OR49OHFJTbTr7a7Kg9W6VqS49BdV2rd/omcpXrXXbG
r4eKupIbu4NP+k/cfDe2pENqe8fXnV8NulvlgoaK2iQtdi1+YzxPxz3Jv0i3u9L5R0CDhUt90vy3tXeMosw/Zi1ona9z3+m/dao6
PVW1lwf64xMSkvfpD+g/0VU5Y2L7gfHNTuzBjaL5MToGucP5wx+mlskZmPae6ghb9vp0/fas4Yfn9wZ4m2SrNupcCazPuFe7dZG8
v/xWs5GIaMf7L5+YvDoQflLCQqpVp83yzj0Hhplr9wOd7/MNu48kqsxZmKISZlORkGw2dHF4cdLXOpXMd/Xv6k8OW5m8t/e1swws
UdzV/V3d0u1rdH77OZ3kjwmVl1Ud7d/qtDc+NzVbKX9kl1135Ga9v3XjRZUqw8wdPRJVXijKj3REyja5PZnTHDxn9RajJXTVFNuU
anb+wSPnSnaf/bIyb7+IqUDYl4EtcvJHfulMuP80NijqMFxi5RL1rTDx+NKSCRNXbXvtKLkrFmdXvTef8v6dqWa2d1DpkuIlU7V9
Vd2Zb3fmSc1KNL7kqrZF4fvdNOfPLzzz0k+9jfvpcOe9gvkTp3EzlzXUyfrqt0dsb6qe/6FIU4vYKpJnYfos1GTzVPpn56dHaf7y
GSErI10/+Rktb2vXiClL2ie2e/ahS8YbdQ4NjftbGMdp5rd5PxlckrmhIvysT+A/XuSOhba+f9hpfbdqPTjr/Bu9L35XFAT1/2kI
lrSfdNma6cx2/jL/y0ItNfne4Kt3z/3VHd48dvE/+n87DKd3pKyeZ+odpfeubP8Xh6P096cHxkyVHe0NWBt1HVzaBC4km/6KPhqU
ebl6zf1Ass+S+ISR08MxF+8t2NKZ5MEqvTJslHy9vmFV6cLZZ+MXBvWSF2fUDjvU2Vu1yg2m3DZZ1bHMxvlqie11rSceA4tDBKcN
PDysPJT+3S/hI+HDXPLc2LPq+O463/UNzp4yxmumznr+sAxdrtM4nXtepTT1qskJy3jOr+qKvmNW1Pl56+fPk+u2DUu9vVZdxSEn
OHb2/dab251tQhZ+yooP3qplLnpS9VPXpFNX+bxCNeveJ+Knfvmf3ZJ3/oOvkKG04/KtRzfP0VFc8b3YP7Pi/lCMw4Zz4tbzEhyH
7YQCxXWdPE4lS/8VelxBY9nZcqnIG67v9OwO6HomnVjwe35/B0XxSvQdxXd979efeBq3ISDEPCAySSOwb373xOJ5U3nx2zZnCB5V
2JHvEFJxvOiyfuCyF/OVVv22dmnKyPijUWiiJr3sVPHh1OyW5gs6HqplYlUrv58fqnEYKzjgmHZBMHylS9DPtXnbwtzzF53LKSsw
qtM7dF/Lae9pu0sGym7HrIu9xITv6zlbXHIu8Wd3jq2/YEotX54QZnykzGlTfpkeZ3XC4WCqyvGJxuFnqpcD+q3Tra/Y+ze5OZPZ
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
Nj36f+tsb9nVjPZLv3Yx1dBTW+nqSyt/dN+/z6mTs93VOKD6reWoK7k5a8C9+vXcR033IjIXR48v/j8KzjuqqfP/4xEREREREXE0
jlq1ioARGYqIGxERcVu11WrrauvX2rrqqqOOOuveeyu4AGUKyB4hhEAGkL1zk9z53OeO/PI795z7T3LOfe5nvN+v9z+3aO5Uz8Gd
9TvrhRfy98+e1np68dqOMxvvBM27OP/hvnkr73wc9O7P/fhP6VV/tJcu3rOH/+j/v5TR9zedqLmXvOv+vknFFZNOHZounlOdsmXQ
keW9zm6Rty/8dWj/qJ0Xd15c9GDF+7kZ07eMWTlm5eC55ff8lww6PHr+XFneIU+/1QeEO+/x/y7smyW72+PDH6vvXa3f+G6hKPf3
s1OmcU8T019NGTi2Lh64i3+6tHPhw9fXyj4fL494/emX6m2t9+m1xqe1VxR5dO2tIdtXzRrsSJucev2v4HkHxt2M2pdIL5O+l76/
8u/VkZ05T+6On/bh29PvI6+Mv1y+4dDaj51P0o+u9hvfFPVTS++rj/dxcZMe15+8vVp3tHzX/fLlb87erE8a+J0wNuZXPu7oko9L
7kxctGPFyBPjdx18My9+7sWdxLl9+9fVpOUukAx/RKRmMRkv337beTgwyrZa0OvByj4Zx5J+ehqcYFTvbRjBUOd2Nkxd8PTT/2b9
eEO6U9U0eV7MlUGXdl25f/rZQp9tqvOe1iExujGqKYEfSlJVt/o97TW36sWAL25ttaanST5dNbc+/sL9AZsVm3bs2CfqOuOPbWdf
4xe0f//6+YeXrr/yEg68VN2/fGnmlLfV2b/A4zeNd4xZl7+Nd97fl7Jj3tsiPmPZ8mv3F1/8du3+Y8gf1VuP1KXE7r84d8CLw5Nn
jI5seIl9vfVJ3dyx13LKtixHZgdt8f9BfnjT0am37q+YOH7djW0P46ssmTV/73AsnLfGycx+96xkAneu8M62GC6v6+zfxnwztfbS
lP1LS1V5f6f3WqA8NGPn3gWzZorSl8w/sO3VcWOeaviN9O/TteJ/0v9L/zNdetZsZdKvrxqS9rPxemPgI/QOfI8f/HvTpOp+y53J
4/ccKHk1e9KJ8IND778/+6zv1WcvZi5NcT4fsOzGu1clF+cN2E4vHrF76JqckpAfJVcq3FVuw8HYY4U3SvYkZo09Yj2+89K1n3Nu
59xu8Pshy3uStGvf37t17e7O1at3rN7hKNffWLn609+97rvSnuYjSwYHnjlcfTt/sezVtTvf7lh9IGn3l7TS+CnTp0yfU7XzxduK
g2u3/Hv9dGOh6aloxPWfhzz66tGXd/8sMydlXPz9m+u3/r655MWro29yIrf+dsQ/QvVu58K0xb9ekYyKqf90BFnwS+K4WdaWh0mV
P/YJTV1zPuv5y4T+Rz6NyI2d5c2y6y4phWu3fLNHfHRdlx+rNH9sSCsh8jNHDpum2LP28Me9a+LiP2VGp/5cvix52ZDt+xfkziOF
V/47uaL6mnLGopPl97/+JvVd9HO/6r2bJt/ZYag/kpW68/nFJb2fbTPlVaj3jtuQ/8+5Vaov55d9da/b3EHnV16Tz9v5v/wrll9P
jf4zbVa/eb8Tt+tr7zaH55r2pJIDFkTlzZzm+qNkH/l4+uLqdeK0NSO3nvq4YO6lrc+T2s9PvpM052C2VLjy6pLFR7N+avuu8Ti6
4mRK7CTRypQtD6fpe7nvjds3F5mxpTUxOnL1BuXO67d+nNn3ar+Fv4x6tK15w7ukIdMv7LcnxRyN2HJ8zrAm5ebL93a8aAibMefK
TnsKklJ66mCEZIZ6s2T1HzU9F1bE7Dv747bZO3TXurxZte7CvRFXy5Z83U7/ey1r34ldhaNze1xJOmdvO3vg/Np+Wzfnnfv3j70X
1vRep5oc9+ni9L/+2Xlyco1tR+eLczlJ8muTqZdztwxcs/nNk55Dfw8e4fqDbfhv/eaBr/X63Ft1k3dw70QjDsyd/+fPryrnSWQL
5m/J25K31Hv9e2/vh50fflmF/B3ScGbO4G+HrRsYVfi15J837lsr4m+ttny13vbI9WnUDym2e/uvX19Ve+1/ymtTd2t31n45Pnta
nzGv/I999+V/97Z/fWqDetq+G/KkSdOjD4X/eGVnVPjz1/Neb88asP1PacreZbXOp9Q71X+KT2dG7bqdP2XAyril+olFU9Zuj588
IlZYVWW7+L606c7ax9+/efKTYc/7xk0xdzd23fdlTP6C7M/fX1t5sGjjiQ8bA74vvgaP0kenzdi27/DhRpUuNUGSNXLt0JrXWTtv
HC5su7OuQbJqDrN2a072VdWizuPE9x9i1o5JmDfypuJj5X/7Xk+v+v6/ijkVuQW/XN3w66X0R9vv5r6KGdZReWzV6MaQ7NR5f95Y
/6ikdMbmvO9lO8VZz+4sqtkw03zq2apDS8gbhXvurR82U7r+6tw44eW/t8W1LQpd66qdueebVx9eCCpz//u06fTzoN3GT2cnvj81
d97ceblP9923bUxIXTD50fKisys2LHuX8HrWMnBFdRtZdW79z7PP1lBXPkc/OK6190/9bs6AdS3tLT+uP5Al3DIzMOVYSsDSAx/9
HreL970UrZ2kfnL7ww5R/Kjvjv8643DbPy9z+0g+Ts2/Kbo9sfL3S5tfhK5aZL65OvfJlttLp07Oybp49Sv1sUUZraXG2vHDem4o
vqv7e9+5kJhThw5U7D346rRp07QPS+r7f7h2/s78n88xTWm7At7m7//6hz/aR0mS0h+tj3Xf/mnBJnJD0sylOx4eeJH1JXnAmRWP
rol2/zE3eWpW083E2e8Ly4St74Y+b5oWdnXNcvbcwqUjViduld789cHom7bVvx557MW1Sze7rz16AbSl3tx78O2STTUZF4kPhaIx
R0IfJDyo+HvFwdabpRdjp5+vvrNi5PhhR4xH7oz3/6vsyZcnx95lryX1L4UzGk9VKh55skN038Wcabk1tXfF/pPBczqqhtxcWGB6
xmy7MnnEkR//uPDryfdtq4bc3XkxesPWynPFN1eN3e9/rsufl3NCfsp9tunKsy0/7u5fcebWiXFRDY1HXv2jfX7+iqFg1ecbUxdl
v14zetjta6/X3BANuTWj8KsDzRuLShRXH/+H3Fk2XFnZVjn1o6Zh2fk+m5rOCV/nPrv34m+JZ9PN1KFNTx5uzL+UfeXx0A83tbYL
5o9RJYvfNZ+sfWPcezsz/KzhRyqr4vUSzXfXh5ffyRnwsDXq761O3cSz9edOZ1XFJNw4uS1omTa8Vy4cuv3p6sTR3za+Dskt/Liq
Vjz2zbab/9Z+eDtcfGbU3YN/vT29tix1jqb01IMT58aWW9eL3525/uuhpvGN47myyVsamy7snXrfJm343f9fbPXl+2k7UnaMOin4
9seDt94LFu6YOfhEq+RizdWVBTnZzU+vzA+ces7w5rb4zLv1Vd+taL81KWLTR/WVgQXUpu8U43OCX97/qq8+70aM8PziopWKu/41
4Z+JQ1/s0vmy/z1Jf/3ecnVtanBG1VBxQtX09PDWqWP/3fWk7P30ymff47OiVWfGznpQM/TG1p0Priz/R73get3lgNQjz9u/n311
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
ls+OEvb/P5N5IA==
";

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
    mut std_materials: ResMut<Assets<StandardMaterial>>,
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

    let with_lib = |src: &str| src.replace("// @cloud-lib", CLOUD_LIB);
    let _ = shaders.insert(&SURFACE_SHADER, Shader::from_wesl(with_lib(SURFACE_WESL), "plate_globe/surface.wesl"));
    let _ = shaders.insert(&CLOUDS_SHADER, Shader::from_wesl(with_lib(CLOUDS_WESL), "plate_globe/clouds.wesl"));

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

    // The sky: stars and the Milky Way on spheres around everything, unlit and additive so they
    // only ever add light, and turned to the real sidereal time each frame.
    let sky_material = |texture: Image, images: &mut Assets<Image>| StandardMaterial {
        base_color_texture: Some(images.add(texture)),
        unlit: true,
        alpha_mode: AlphaMode::Add,
        cull_mode: None,
        fog_enabled: false,
        ..default()
    };
    let star_mat = std_materials.add(sky_material(star_sprite(), &mut images));
    let band_mat = std_materials.add(sky_material(milky_way(), &mut images));
    commands.spawn((Mesh3d(meshes.add(star_mesh())), MeshMaterial3d(star_mat), Transform::default(), Sky, NotShadowCaster));
    commands.spawn((Mesh3d(meshes.add(globe_mesh(SKY_RADIUS * 1.02))), MeshMaterial3d(band_mat), Transform::default(), Sky, NotShadowCaster));

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
    mut sky: Query<&mut Transform, (With<Sky>, Without<Camera3d>, Without<DirectionalLight>)>,
    overlay: Res<Overlay>,
) {
    let t = clock.t;
    let (sun_lat, sun_lon) = subsolar(clock.unix);
    for mut tf in &mut sun {
        *tf = Transform::from_translation(geo(sun_lat, sun_lon) * 10.0).looking_at(Vec3::ZERO, Vec3::Y);
    }
    for mut tf in &mut sky {
        tf.rotation = sky_rotation(clock.unix);
    }
    // Orbit eastward from just past the terminator on the night side, so the first thing in
    // view is the day/night line, then sweep over the day side and back around.
    for mut tf in &mut camera {
        let lon = sun_lon - 75.0 + t * 4.0;
        let lat = 18.0 + 14.0 * (t * 0.07).sin();
        *tf = Transform::from_translation(geo(lat, lon) * 3.0).looking_at(Vec3::ZERO, Vec3::Y);
    }

    // Weather time: the clouds evolve in place in the shaders (see CLOUD_LIB).
    for (_, m) in surfaces.iter_mut() {
        m.extension.params = Vec4::new(overlay.relief, t, 2.5, 0.0);
    }
    for (_, m) in cloud_mats.iter_mut() {
        m.extension.params = Vec4::new(t, 0.0, 0.0, 0.0);
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
