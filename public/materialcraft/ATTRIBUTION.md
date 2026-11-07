# Attribution

Every bundled non-code asset in this repository, with its author, source and license. The rule:
**each asset gets a row here in the same change that adds it.** MaterialCraft's own code and
original assets are MIT OR Apache-2.0 (see [`LICENSE-MIT`](LICENSE-MIT),
[`LICENSE-APACHE`](LICENSE-APACHE) and [`NOTICE`](NOTICE)); third-party assets must be permissively
licensed and keep their license file next to them. No asset from any commercial product (icons,
images, materials, sample graphs, presets, environments) may ever be added.

| Path | Title | Author | Source | License |
|---|---|---|---|---|
| `assets/app-icon/materialcraft.svg` | App icon (engraved rhino), master vector traced at 2048 px | Project owner (ArtCraft team) | Original artwork made for MaterialCraft, vectorised with craftrules `vectorize_tile.py` | MIT OR Apache-2.0 (`assets/app-icon/LICENSE.txt`) |
| `assets/app-icon/materialcraft-small.svg` | App icon (engraved rhino), lighter vector traced at 1024 px | Project owner (ArtCraft team) | Original artwork made for MaterialCraft, vectorised with craftrules `vectorize_tile.py` | MIT OR Apache-2.0 (`assets/app-icon/LICENSE.txt`) |
| `assets/app-icon/materialcraft-1024.png` | App icon (engraved rhino), 1024 px | Project owner (ArtCraft team) | Original artwork made for MaterialCraft, rendered by `packaging/icons.sh` | MIT OR Apache-2.0 (`assets/app-icon/LICENSE.txt`) |
| `assets/app-icon/materialcraft.ico` | App icon (engraved rhino), Windows (16-256 px) | Project owner (ArtCraft team) | Original artwork made for MaterialCraft, rendered by `packaging/icons.sh` | MIT OR Apache-2.0 (`assets/app-icon/LICENSE.txt`) |
| `assets/app-icon/materialcraft.icns` | App icon (engraved rhino), macOS (16-1024 px) | Project owner (ArtCraft team) | Original artwork made for MaterialCraft, rendered by `packaging/icons.sh` | MIT OR Apache-2.0 (`assets/app-icon/LICENSE.txt`) |
| `assets/app-icon/hicolor/{16x16,24x24,32x32,48x48,64x64,128x128,256x256,512x512}/apps/ai.storyteller.materialcraft.png` | App icon (engraved rhino), hicolor theme PNGs | Project owner (ArtCraft team) | Original artwork made for MaterialCraft, rendered by `packaging/icons.sh` | MIT OR Apache-2.0 (`assets/app-icon/LICENSE.txt`) |
| `assets/app-icon/hicolor/scalable/apps/ai.storyteller.materialcraft.svg` | App icon (engraved rhino), hicolor scalable (copy of `materialcraft-small.svg`) | Project owner (ArtCraft team) | Original artwork made for MaterialCraft, vectorised with craftrules `vectorize_tile.py` | MIT OR Apache-2.0 (`assets/app-icon/LICENSE.txt`) |
| `assets/app-icon/LICENSE.txt`, `assets/app-icon/README.md` | App icon licence and notes | MaterialCraft contributors | original | MIT OR Apache-2.0 |
| `assets/hdr/spiaggia_di_mondello_1k.exr` | Spiaggia di Mondello (1K EXR HDRI) | Andreas Mischok | [Poly Haven](https://polyhaven.com/a/spiaggia_di_mondello) | CC0-1.0 ([license](assets/hdr/LICENSE.txt)) |
| `assets/hdr/monochrome_studio_02_1k.exr` | Monochrome Studio 02 (1K EXR HDRI) | Grzegorz Wronkowski | [Poly Haven](https://polyhaven.com/a/monochrome_studio_02) | CC0-1.0 ([license](assets/hdr/LICENSE.txt)) |
| `assets/hdr/metro_noord_1k.exr` | Metro: Noord (1K EXR HDRI) | Greg Zaal | [Poly Haven](https://polyhaven.com/a/metro_noord) | CC0-1.0 ([license](assets/hdr/LICENSE.txt)) |
| `assets/hdr/brown_photostudio_02_1k.exr` | Brown Photostudio 02 (1K EXR HDRI) | Sergej Majboroda | [Poly Haven](https://polyhaven.com/a/brown_photostudio_02) | CC0-1.0 ([license](assets/hdr/LICENSE.txt)) |
| `docs/images/materialcraft-workspace.png` | README screenshot: the workspace with the brick wall sample | MaterialCraft contributors | Offscreen render of MaterialCraft's UI (`crates/ui-egui/tests/snapshot.rs`) | MIT OR Apache-2.0 |
| `docs/images/materialcraft-wood.png` | README screenshot: the wood planks template | MaterialCraft contributors | Offscreen render of MaterialCraft's UI | MIT OR Apache-2.0 |
| `docs/images/materialcraft-lava.png` | README screenshot: the lava rock template | MaterialCraft contributors | Offscreen render of MaterialCraft's UI | MIT OR Apache-2.0 |
| `docs/images/materialcraft-ground.png` | README screenshot: the mossy ground template | MaterialCraft contributors | Offscreen render of MaterialCraft's UI | MIT OR Apache-2.0 |
| `docs/images/materialcraft-new-graph.png` | README screenshot: the New graph dialog | MaterialCraft contributors | Offscreen render of MaterialCraft's UI | MIT OR Apache-2.0 |
| `docs/images/materialcraft-alpha-transparency.png` | Docs screenshot: a cut-out material in the 3D view and a reroute dot on a wire | MaterialCraft contributors | Offscreen render of MaterialCraft's UI (`crates/ui-egui/tests/snapshot.rs`) | MIT OR Apache-2.0 |
| `docs/images/materialcraft-alpha-channel.png` | Docs screenshot: the 3D view's alpha channel view | MaterialCraft contributors | Offscreen render of MaterialCraft's UI (`crates/ui-egui/tests/snapshot.rs`) | MIT OR Apache-2.0 |
| `docs/images/materialcraft-materials.png` | README render: eight sample materials on spheres | MaterialCraft contributors | `materialcraft-cli render --scene sphere --full --hq` of the templates, eight renders in a grid | MIT OR Apache-2.0 |
| `docs/images/materialcraft-levels-editor.png` | Docs screenshot: the Levels editor with the input histogram | MaterialCraft contributors | Offscreen render of MaterialCraft's UI (`crates/ui-egui/tests/snapshot.rs`) | MIT OR Apache-2.0 |
| `docs/brand/artcraft-*.svg`, `docs/brand/artcraft-*.png` | ArtCraft logo and mark | ArtCraft Team | storytold/craftrules `assets/brand/` | ArtCraft brand terms, not open source ([`docs/brand/LICENSE-brand.txt`](docs/brand/LICENSE-brand.txt)) |
| `crates/nodes/src/atomic/text.rs` (`GLYPHS`) | Single-stroke vector font of the Text node (A–Z, a–z, 0–9, punctuation) | MaterialCraft contributors | Original, designed as stroke data in code | MIT OR Apache-2.0 |
| `examples/atomic_sample.sbs` | Atomic sample graph | MaterialCraft contributors | Original graph built by `crates/engine/src/atomic_sample.rs` | MIT OR Apache-2.0 |

## Third-party assets compiled into the binary

These come from Rust crate dependencies (not files in this repository) and keep their licenses.

| Asset | Used for | Author | Source | License |
|---|---|---|---|---|
| Phosphor Icons (regular), via the `egui-phosphor` crate (vendored in `vendor/egui-phosphor` for egui 0.37) | Every UI icon (toolbars, panels, node quick-insert buttons) | Phosphor Icons (Helena Zhang, Tobias Fried) | https://phosphoricons.com, https://github.com/amPerl/egui-phosphor | MIT (icons); crate MIT OR Apache-2.0 |
| egui default fonts (Ubuntu-Light, Hack, Noto Emoji, emoji-icon-font), via `epaint_default_fonts` | UI text | Canonical / Source Foundry / Google / Jessie Jung | https://github.com/emilk/egui | Ubuntu Font Licence 1.0, MIT + Bitstream Vera License, OFL 1.1, MIT |

## Procedural content (no asset files)

The node library's primitives (`crates/nodes`), the sample materials and graph templates
(`crates/engine/src/samples.rs`), the 3D view's environments (`crates/render/src/ibl.rs`, procedural
HDR skies and soft boxes), the built-in meshes (`crates/geom/src/primitives.rs`), the library's node
previews (`crates/ui-egui/src/thumbs.rs`, each node cooked on sample waves) and the New graph
dialog's template spheres (`crates/ui-egui/src/windows.rs`) are generated in code by MaterialCraft
contributors (MIT OR Apache-2.0). None of them is derived from another product's presets,
shaders, materials, sample graphs or images.
