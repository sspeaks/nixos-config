//usr/bin/env nix shell nixpkgs#rust-script nixpkgs#cargo nixpkgs#rustc --command rust-script -d rayon=1 -d flate2=1 -d base64=0.22 -d libc=0.2 -d ctrlc=3 "$0" "$@"; exit $?
//! plate-orb — real-time 3D rendering streamed into the terminal over the Kitty graphics protocol.
//!
//! The first line is a shell polyglot rather than a `#!` shebang: the kernel finds no
//! shebang, so your shell runs the file as a script, `//usr/bin/env` is a valid path,
//! and rustc sees the line as a comment. rust-script caches the compiled binary.
//! Crate dependencies are passed as `-d` flags there because rust-script only reads an
//! embedded manifest when it's the very first thing in the file.
//!
//! Pipeline (the same one you'd use for OpenGL: render offscreen -> read pixels -> ship):
//!   1. ray-trace a lit, spinning sphere over a grid floor, one row per rayon task;
//!      everything static (ray directions, vignette, floor grid, background) is
//!      precomputed per resize, so a frame only adds the sphere and the moving light,
//!      and it's drawn straight into the shared-memory buffer the terminal reads
//!   2. hand the raw RGB pixels to the terminal:
//!        shm    — draw them straight into a POSIX shared-memory object and send only its name
//!                 (no compression or base64 on either side; local terminals only)
//!        direct — zlib + base64 inline in the escape sequence (works over SSH)
//!   3. show it via a *virtual* placement and Unicode placeholder cells (U+10EEEE +
//!      row/column diacritics). Placeholders are plain text to tmux, so the image
//!      follows the pane through redraws and splits.
//!   Each frame is wrapped in synchronized output so the terminal never draws half of one.
//!
//! Usage: scripts/demo/plate-orb.rs [--fps N] [--width PX] [--direct] [--bench] [--dump F]
//!   --fps N     target frame rate (default 120; the terminal can't show more than the
//!               display's refresh rate)
//!   --width PX  fixed max render width; the terminal scales it to the cell grid.
//!               Default with shm: start at the terminal's native pixel width and step
//!               down automatically until the target fps holds. With --direct: 960.
//!   --direct    force inline zlib+base64 transmission instead of shared memory
//!   --bench     time rendering and both transmission modes without drawing
//!   --dump F    write one 960x540 frame to F as a PPM image and exit

use base64::Engine;
use flate2::{write::ZlibEncoder, Compression};
use rayon::prelude::*;
use std::ffi::CString;
use std::io::{Read, Write};
use std::ops::{Add, Mul, Sub};
use std::process::Command;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;
use std::time::{Duration, Instant};

const IMAGE_ID: u32 = 42; // also the 256-color index the placeholder cells are painted with

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

// ---------------------------------------------------------------- math

#[derive(Clone, Copy, Debug, Default)]
struct V(f32, f32, f32);

impl Add for V {
    type Output = V;
    fn add(self, o: V) -> V { V(self.0 + o.0, self.1 + o.1, self.2 + o.2) }
}
impl Sub for V {
    type Output = V;
    fn sub(self, o: V) -> V { V(self.0 - o.0, self.1 - o.1, self.2 - o.2) }
}
impl Mul<f32> for V {
    type Output = V;
    fn mul(self, s: f32) -> V { V(self.0 * s, self.1 * s, self.2 * s) }
}
impl V {
    fn dot(self, o: V) -> f32 { self.0 * o.0 + self.1 * o.1 + self.2 * o.2 }
    fn len(self) -> f32 { self.dot(self).sqrt() }
    fn norm(self) -> V { self * (1.0 / self.len()) }
    fn splat(s: f32) -> V { V(s, s, s) }
}

fn mix(a: V, b: V, t: f32) -> V { a + (b - a) * t }

fn smoothstep(a: f32, b: f32, x: f32) -> f32 {
    let t = ((x - a) / (b - a)).clamp(0.0, 1.0);
    t * t * (3.0 - 2.0 * t)
}

/// Plate hex token -> linear RGB.
fn lin(hex: u32) -> V {
    let c = |shift: u32| (((hex >> shift) & 0xff) as f32 / 255.0).powf(2.2);
    V(c(16), c(8), c(0))
}

/// Tone curve + linear -> sRGB as a lookup table indexed by sqrt(linear), so dark tones
/// (where sRGB is most sensitive) get fine steps. Covers linear [0, 4].
const LUT_N: usize = 4096;
const LUT_SCALE: f32 = (LUT_N - 1) as f32 / 2.0;

fn srgb_lut() -> Vec<u8> {
    (0..LUT_N)
        .map(|i| {
            let s = i as f32 / LUT_SCALE;
            let x = s * s;
            let y = (x / (1.0 + x * 0.25)).min(1.0);
            (y.powf(1.0 / 2.2) * 255.0 + 0.5) as u8
        })
        .collect()
}

// ---------------------------------------------------------------- scene

struct Palette { void: V, panel: V, rule: V, vermilion: V, deep: V, bright: V }

const R: f32 = 0.8;
const FLOOR_Y: f32 = -0.8;
const EYE: V = V(0.0, 0.45, 3.6);
const FOV: f32 = 0.62;

/// Everything about a pixel that doesn't change between frames.
#[derive(Clone, Copy, Default)]
struct Px {
    d: V,       // ray direction
    vign: f32,  // vignette factor
    tp: f32,    // distance to the floor (inf if the ray misses it)
    hx: f32,    // floor hit position (x, z)
    hz: f32,
    base: V,    // static color, vignette applied: floor grid or background gradient
}

struct Frame { c: V, l: V, ca: f32, sa: f32 }

struct Scene { w: usize, h: usize, pal: Palette, px: Vec<Px>, lut: Vec<u8> }

impl Scene {
    fn new(w: usize, h: usize) -> Self {
        let pal = Palette {
            void: lin(0x0a0a0a), panel: lin(0x1a1a1a), rule: lin(0x404040),
            vermilion: lin(0xe03c28), deep: lin(0x6a1a10), bright: lin(0xe6e6e6),
        };
        let aspect = w as f32 / h as f32;
        let mut px = vec![Px::default(); w * h];
        px.par_chunks_mut(w).enumerate().for_each(|(y, row)| {
            for (x, p) in row.iter_mut().enumerate() {
                let u = (x as f32 + 0.5) / w as f32 * 2.0 - 1.0;
                let v = 1.0 - (y as f32 + 0.5) / h as f32 * 2.0;
                let d = V(u * aspect * FOV, v * FOV - 0.12, -1.0).norm();
                let vign = (1.0 - 0.35 * (u * u + v * v).powf(1.5)).clamp(0.0, 1.0);
                let tp = if d.1 < -1e-4 { (FLOOR_Y - EYE.1) / d.1 } else { f32::INFINITY };
                let (hx, hz, base);
                if tp.is_finite() {
                    let hit = EYE + d * tp;
                    hx = hit.0;
                    hz = hit.2;
                    // Anti-aliased grid lines whose width grows with distance.
                    let gx = ((hx * 2.0 + 0.5).rem_euclid(1.0) - 0.5).abs();
                    let gz = ((hz * 2.0 + 0.5).rem_euclid(1.0) - 0.5).abs();
                    let line = (1.0 - gx.min(gz) / (0.006 * tp + 0.01)).clamp(0.0, 1.0);
                    let fade = (-tp * 0.18).exp();
                    base = mix(pal.void, pal.rule * 1.6, line * fade);
                } else {
                    hx = 0.0;
                    hz = 0.0;
                    base = mix(pal.void, pal.panel, (v * 0.6 + 0.3).clamp(0.0, 1.0));
                }
                *p = Px { d, vign, tp, hx, hz, base: base * vign };
            }
        });
        Scene { w, h, pal, px, lut: srgb_lut() }
    }

    fn frame(t: f32) -> Frame {
        Frame {
            c: V(0.0, 0.08 + 0.10 * (t * 1.7).sin(), 0.0),
            l: V((t * 0.6).cos() * 1.3, 1.5, (t * 0.6).sin() * 1.3 + 0.9).norm(),
            ca: (t * 0.9).cos(),
            sa: (t * 0.9).sin(),
        }
    }

    /// Render frame t into `buf` (w*h*3 sRGB bytes). RGB rather than RGBA: the terminal
    /// converts to RGBA itself in one fast pass, which costs it about what copying a
    /// third more bytes would, and RGBA makes rendering ~20% slower here.
    fn render(&self, t: f32, buf: &mut [u8]) {
        let f = Self::frame(t);
        let lut = &self.lut;
        let enc = |x: f32| lut[((x.max(0.0).sqrt() * LUT_SCALE) as usize).min(LUT_N - 1)];
        buf.par_chunks_mut(self.w * 3)
            .zip(self.px.par_chunks(self.w))
            .for_each(|(row, pxs)| {
                for (out, p) in row.chunks_exact_mut(3).zip(pxs) {
                    let c = self.shade(p, &f);
                    out[0] = enc(c.0);
                    out[1] = enc(c.1);
                    out[2] = enc(c.2);
                }
            });
    }

    #[inline(always)]
    fn shade(&self, px: &Px, f: &Frame) -> V {
        let pal = &self.pal;
        let d = px.d;

        let oc = EYE - f.c;
        let b = d.dot(oc);
        let disc = b * b - (oc.dot(oc) - R * R);
        if disc > 0.0 {
            let ts = -b - disc.sqrt();
            if ts < px.tp {
                let hit = EYE + d * ts;
                let n = (hit - f.c) * (1.0 / R);
                // Spin a striped texture around Y so rotation reads clearly.
                let nx = n.0 * f.ca - n.2 * f.sa;
                let nz = n.0 * f.sa + n.2 * f.ca;
                let lon = nz.atan2(nx);
                let lat = n.1.clamp(-1.0, 1.0).asin();
                let stripe = smoothstep(-0.08, 0.08, (lon * 5.0).sin() * lat.cos());
                let band = smoothstep(0.035, 0.0, lat.abs()); // thin bright equator
                let base = mix(mix(pal.deep, pal.vermilion, stripe), pal.bright, band);
                let diff = n.dot(f.l).max(0.0);
                let half = (f.l - d).norm();
                let spec = n.dot(half).max(0.0).powi(80);
                let rim = (1.0 - (-n.dot(d)).max(0.0)).powi(3);
                let bounce = (-n.1).max(0.0) * 0.06;
                let col = base * (0.05 + 0.95 * diff + bounce) + V::splat(spec * 1.2) + pal.vermilion * (rim * 0.35);
                return col * px.vign;
            }
        }
        if !px.tp.is_finite() {
            return px.base; // background
        }

        // Floor: static grid color plus the moving shadow and bounce glow.
        let w = V(f.c.0 - px.hx, f.c.1 - FLOOR_Y, f.c.2 - px.hz);
        let proj = w.dot(f.l).max(0.0);
        let reach = R + 0.25 + 0.15 * proj;
        // Soft shadow: how close the ray toward the light passes the sphere center.
        let closest2 = (w - f.l * proj).dot(w - f.l * proj);
        let shadow = if closest2 >= reach * reach {
            1.0
        } else {
            0.25 + 0.75 * smoothstep(R - 0.15, reach, closest2.sqrt())
        };
        // Vermilion bounce light pooling under the orb (negligible beyond r2 ≈ 4.3).
        let r2 = (px.hx - f.c.0).powi(2) + (px.hz - f.c.2).powi(2);
        let glow = if r2 < 4.5 { pal.vermilion * (0.22 * (-r2 * 1.6).exp() * px.vign) } else { V::default() };
        (px.base + glow) * shadow
    }
}

// ---------------------------------------------------------------- terminal plumbing

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

/// Create a POSIX shared-memory object of `len` bytes and let `fill` write straight into the
/// mapping (no intermediate copy). The terminal unlinks it after reading.
fn shm_create(name: &str, len: usize, fill: impl FnOnce(&mut [u8])) -> std::io::Result<()> {
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
        if libc::ftruncate(fd, len as libc::off_t) != 0 {
            return fail(fd);
        }
        let map = libc::mmap(std::ptr::null_mut(), len, libc::PROT_READ | libc::PROT_WRITE, libc::MAP_SHARED, fd, 0);
        if map == libc::MAP_FAILED {
            return fail(fd);
        }
        fill(std::slice::from_raw_parts_mut(map as *mut u8, len));
        libc::munmap(map, len);
        libc::close(fd);
    }
    Ok(())
}

fn shm_write(name: &str, data: &[u8]) -> std::io::Result<()> {
    shm_create(name, data.len(), |m| m.copy_from_slice(data))
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
    scratch: Vec<u8>,                          // frame buffer for direct mode
}

impl Transmitter {
    fn new(mode: Mode, in_tmux: bool) -> Self {
        Transmitter { mode, in_tmux, seq: 0, recent: Default::default(), scratch: Vec::new() }
    }

    /// Have `fill` draw a w x h RGB frame, upload it, and (re)create its virtual placement
    /// spanning cols x rows cells. In shm mode `fill` draws directly into shared memory.
    fn send(&mut self, w: usize, h: usize, cols: usize, rows: usize, fill: impl Fn(&mut [u8]), out: &mut Vec<u8>) {
        let len = w * h * 3;
        let head = format!("a=T,U=1,f=24,s={w},v={h},i={IMAGE_ID},c={cols},r={rows},q=2");
        let b64 = &base64::engine::general_purpose::STANDARD;
        if self.mode == Mode::Shm {
            // macOS caps shm names at 31 bytes.
            let name = format!("/porb{}-{}", std::process::id(), self.seq);
            self.seq += 1;
            if shm_create(&name, len, &fill).is_ok() {
                let seq = format!("\x1b_G{head},t=s,S={len};{}\x1b\\", b64.encode(&name));
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
        self.scratch.resize(len, 0);
        fill(&mut self.scratch);
        let mut z = ZlibEncoder::new(Vec::with_capacity(len / 4), Compression::fast());
        z.write_all(&self.scratch).unwrap();
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
    let name = format!("/porb{}-probe", std::process::id());
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

fn bench(max_w: usize) {
    let threads = rayon::current_num_threads();
    println!("{threads} render threads; times are per frame");
    for &(w, h) in &[(960usize, 540usize), (1920, 1080), (max_w, max_w * 9 / 16)] {
        let scene = Scene::new(w, h);
        let mut buf = vec![0u8; w * h * 3];
        let n = 240;
        let time = |f: &mut dyn FnMut(f32)| {
            let t0 = Instant::now();
            for i in 0..n {
                f(i as f32 / 120.0);
            }
            (Instant::now() - t0).as_secs_f64() / n as f64 * 1e3
        };
        let render_ms = time(&mut |t| scene.render(t, &mut buf));
        let e2e = |mode| {
            let mut tx = Transmitter::new(mode, false);
            let mut out = Vec::new();
            let ms = time(&mut |t| {
                out.clear();
                tx.send(w, h, 120, 32, |b| scene.render(t, b), &mut out);
            });
            tx.cleanup(); // nobody reads these shm objects in a benchmark
            ms
        };
        let (shm, direct) = (e2e(Mode::Shm), e2e(Mode::Direct));
        println!(
            "{w:>4}x{h:<4}  render {render_ms:5.2} ms | render+send: shm {shm:5.2} ms = {:4.0} fps max, direct {direct:5.2} ms = {:4.0} fps max",
            1e3 / shm, 1e3 / direct
        );
    }
}

fn main() {
    let args: Vec<String> = std::env::args().collect();
    let target_fps: f64 = arg(&args, "--fps", 120.0);
    let width_arg: Option<usize> = args.iter().position(|a| a == "--width")
        .and_then(|i| args.get(i + 1)).and_then(|v| v.parse().ok());
    if args.iter().any(|a| a == "--bench") {
        return bench(width_arg.unwrap_or(2880));
    }
    if let Some(path) = args.iter().position(|a| a == "--dump").and_then(|i| args.get(i + 1)) {
        let scene = Scene::new(960, 540);
        let mut buf = vec![0u8; 960 * 540 * 3];
        scene.render(2.0, &mut buf);
        let mut ppm = b"P6 960 540 255\n".to_vec();
        ppm.extend_from_slice(&buf);
        std::fs::write(path, ppm).expect("write frame");
        return;
    }

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
    // Shared memory makes full-resolution frames cheap, so start at one pixel per device pixel
    // and let auto-resolution back off if the machine can't hold the target. Inline
    // transmission has to zlib + base64 every byte, so keep it modest there.
    let max_w = width_arg.unwrap_or(if mode == Mode::Shm { usize::MAX } else { 960 });
    let auto_res = width_arg.is_none() && mode == Mode::Shm;
    const MIN_AUTO_W: f32 = 960.0;

    let running = Arc::new(AtomicBool::new(true));
    {
        let r = running.clone();
        ctrlc::set_handler(move || r.store(false, Ordering::SeqCst)).expect("install Ctrl-C handler");
    }

    let stdout = std::io::stdout();
    let mut tty = stdout.lock();
    let _ = tty.write_all(b"\x1b[?1049h\x1b[?25l");

    let frame_dt = Duration::from_secs_f64(1.0 / target_fps);
    let start = Instant::now();
    let mut last = start;
    let mut fps = 0.0f64;
    let mut geom: Option<Geometry> = None;
    let mut scene = Scene::new(16, 16);
    let (mut img_cols, mut img_rows) = (0, 0);
    let mut out: Vec<u8> = Vec::with_capacity(1 << 20);
    let mut res_scale = 1.0f32; // auto-resolution factor on top of max_w
    let mut rebuild = false;
    let (mut win_start, mut win_frames, mut win_busy) = (Instant::now(), 0u32, Duration::ZERO);
    let (mut render_ms, mut tty_ms) = (0.0f64, 0.0f64);
    let mut next_frame = Instant::now();

    while running.load(Ordering::SeqCst) {
        let frame_start = Instant::now();
        out.clear();

        // Re-layout on resize (polling the ioctl each frame is cheaper than a signal handler).
        let g = geometry(in_tmux, geom);
        let resized = geom != Some(g);
        if resized || rebuild {
            geom = Some(g);
            img_rows = g.rows.saturating_sub(2).max(4).min(DIACRITICS.len());
            img_cols = g.cols.min(DIACRITICS.len());
            let (px_w, px_h) = (img_cols as f32 * g.cell_w, img_rows as f32 * g.cell_h);
            let scale = (max_w as f32 / px_w).min(1.0) * res_scale;
            let (w, h) = (((px_w * scale) as usize).max(16), ((px_h * scale) as usize).max(16));
            scene = Scene::new(w, h);
            if resized {
                out.extend_from_slice(b"\x1b[2J");
                out.extend_from_slice(placeholders(img_cols, img_rows).as_bytes());
            }
            rebuild = false;
            (win_start, win_frames, win_busy) = (Instant::now(), 0, Duration::ZERO);
        }

        let t = (frame_start - start).as_secs_f32();
        // Synchronized output: the terminal holds rendering until the whole frame has arrived.
        graphics(b"\x1b[?2026h", in_tmux, &mut out);
        let r0 = Instant::now();
        tx.send(scene.w, scene.h, img_cols, img_rows, |b| scene.render(t, b), &mut out);
        render_ms = render_ms * 0.9 + 0.1 * r0.elapsed().as_secs_f64() * 1e3;
        // Overwrite the caption in place and clear only to its right (no blank-line gap).
        let _ = write!(
            out,
            "\x1b[{};1H \x1b[38;5;9m●\x1b[0m plate-orb  \x1b[38;5;8m{}×{}px → {}×{} cells · {:5.1}/{} fps · render {:4.1} ms · tty wait {:4.1} ms · {}{}{} · ctrl-c to quit\x1b[0m  {}\x1b[K",
            img_rows + 1, scene.w, scene.h, img_cols, img_rows, fps, target_fps, render_ms, tty_ms,
            if tx.mode == Mode::Shm { "shm" } else { "direct" },
            if auto_res { " · auto-res" } else { "" },
            if in_tmux { " · via tmux" } else { "" }, palette_strip()
        );
        graphics(b"\x1b[?2026l", in_tmux, &mut out);

        // Time blocked writing: when the terminal can't keep up, the pty fills and this grows.
        let w0 = Instant::now();
        if tty.write_all(&out).and_then(|_| tty.flush()).is_err() {
            break;
        }
        tty_ms = tty_ms * 0.9 + 0.1 * w0.elapsed().as_secs_f64() * 1e3;

        let now = Instant::now();
        fps = fps * 0.95 + 0.05 / (now - last).as_secs_f64().max(1e-6);
        last = now;

        // Auto-resolution: once a second, if the frame's work (render, send, terminal
        // back-pressure; not the sleep) used up the budget, shrink the render so the pixel
        // count (which both rendering and the terminal's upload scale with) fits. Judge by
        // load, not delivered fps: pacing caps fps at the target, so jitter would read as a miss.
        win_frames += 1;
        win_busy += now - frame_start;
        if (now - win_start).as_secs_f64() >= 1.0 {
            let load = win_busy.as_secs_f64() / (win_frames as f64 * frame_dt.as_secs_f64());
            if auto_res && load > 0.95 && scene.w as f32 > MIN_AUTO_W {
                let shrink = ((1.0 / load).sqrt() * 0.95) as f32;
                res_scale = (res_scale * shrink).max(MIN_AUTO_W / scene.w as f32 * res_scale);
                rebuild = true;
            }
            (win_start, win_frames, win_busy) = (now, 0, Duration::ZERO);
        }
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
