# Attribution

Every bundled non-code asset in this repository, with its author, source and license. The rule:
**each asset gets a row here in the same change that adds it.** TextureCraft's own code and
original assets are MIT OR Apache-2.0 (see [`LICENSE-MIT`](LICENSE-MIT),
[`LICENSE-APACHE`](LICENSE-APACHE) and [`NOTICE`](NOTICE)); third-party assets must be permissively
licensed and keep their license file next to them.

| Path | Title | Author | Source | License |
|---|---|---|---|---|
| `assets/app-icon/texturecraft.svg` | App icon (engraved zebra), master vector traced at 2048 px | Project owner (ArtCraft team) | Original artwork drawn in ArtCraft for TextureCraft, vectorised with craftrules `vectorize_tile.py` | MIT OR Apache-2.0 (`assets/app-icon/LICENSE.txt`) |
| `assets/app-icon/texturecraft-small.svg` | App icon (engraved zebra), lighter vector traced at 1024 px | Project owner (ArtCraft team) | Original artwork drawn in ArtCraft for TextureCraft, vectorised with craftrules `vectorize_tile.py` | MIT OR Apache-2.0 (`assets/app-icon/LICENSE.txt`) |
| `assets/app-icon/texturecraft-1024.png` | App icon (engraved zebra), 1024 px | Project owner (ArtCraft team) | Original artwork drawn in ArtCraft for TextureCraft, rendered by `packaging/icons.sh` | MIT OR Apache-2.0 (`assets/app-icon/LICENSE.txt`) |
| `assets/app-icon/texturecraft.ico` | App icon (engraved zebra), Windows (16-256 px) | Project owner (ArtCraft team) | Original artwork drawn in ArtCraft for TextureCraft, rendered by `packaging/icons.sh` | MIT OR Apache-2.0 (`assets/app-icon/LICENSE.txt`) |
| `assets/app-icon/texturecraft.icns` | App icon (engraved zebra), macOS (16-1024 px) | Project owner (ArtCraft team) | Original artwork drawn in ArtCraft for TextureCraft, rendered by `packaging/icons.sh` | MIT OR Apache-2.0 (`assets/app-icon/LICENSE.txt`) |
| `assets/app-icon/hicolor/{16x16,24x24,32x32,48x48,64x64,128x128,256x256,512x512}/apps/ai.storyteller.texturecraft.png` | App icon (engraved zebra), hicolor theme PNGs | Project owner (ArtCraft team) | Original artwork drawn in ArtCraft for TextureCraft, rendered by `packaging/icons.sh` | MIT OR Apache-2.0 (`assets/app-icon/LICENSE.txt`) |
| `assets/app-icon/hicolor/scalable/apps/ai.storyteller.texturecraft.svg` | App icon (engraved zebra), hicolor scalable (copy of `texturecraft-small.svg`) | Project owner (ArtCraft team) | Original artwork drawn in ArtCraft for TextureCraft, vectorised with craftrules `vectorize_tile.py` | MIT OR Apache-2.0 (`assets/app-icon/LICENSE.txt`) |
| `assets/app-icon/LICENSE.txt`, `assets/app-icon/README.md` | App icon licence and notes | TextureCraft contributors | original | MIT OR Apache-2.0 |
| `docs/images/texturecraft-workspace.png` | README screenshot: the TextureCraft workspace (a 1970s portable TV in aged cream plastic with a crayon doodle) | TextureCraft contributors | original screenshot of TextureCraft | MIT OR Apache-2.0 |
| `docs/images/texturecraft-bake.png` | README screenshot: bake mode | TextureCraft contributors | original screenshot of TextureCraft | MIT OR Apache-2.0 |
| `docs/images/texturecraft-export.png` | README screenshot: the Export textures dialog | TextureCraft contributors | original screenshot of TextureCraft | MIT OR Apache-2.0 |
| `docs/images/texturecraft-rendering.png` | README screenshot: Rendering mode, path traced on the GPU | TextureCraft contributors | original screenshot of TextureCraft | MIT OR Apache-2.0 |
| `docs/images/texturecraft-light.png` | README screenshot: the light brightness level with the blue accent | TextureCraft contributors | original screenshot of TextureCraft | MIT OR Apache-2.0 |
| `docs/images/texturecraft-lantern.png` | README render: a storm lantern (original procedural mesh of lathes and swept wires, eight texture sets) in chipped red enamel, rust, soot, tarnished brass and glass with an emissive flame (`texturecraft-cli render --camera Hero --samples 2048`, 1200×900) | TextureCraft contributors | original model and render by TextureCraft | MIT OR Apache-2.0 |
| `docs/images/texturecraft-camera.png` | README render: a rangefinder camera (original procedural mesh) in black enamel worn to brass, leatherette, chrome and coated glass; the lens distance scale is an original image drawn in code (`texturecraft-cli render --camera Hero --samples 2048`, 1200×900) | TextureCraft contributors | original model and render by TextureCraft | MIT OR Apache-2.0 |
| `docs/brand/artcraft-*.svg`, `docs/brand/artcraft-*.png` | ArtCraft logo and mark | ArtCraft Team | storytold/craftrules `assets/brand/` | ArtCraft brand terms, not open source ([`docs/brand/LICENSE-brand.txt`](docs/brand/LICENSE-brand.txt)) |

## Third-party assets compiled into the binary

These come from Rust crate dependencies (not files in this repository) and keep their licenses.

| Asset | Used for | Author | Source | License |
|---|---|---|---|---|
| Phosphor Icons (regular), via the `egui-phosphor` crate (vendored in `vendor/egui-phosphor` for egui 0.37) | Every UI icon (tools, layers, panels) | Phosphor Icons (Helena Zhang, Tobias Fried) | https://phosphoricons.com, https://github.com/amPerl/egui-phosphor | MIT (icons); crate MIT OR Apache-2.0 |
| egui default fonts (Ubuntu-Light, Hack, Noto Emoji, emoji-icon-font), via `epaint_default_fonts` | UI text; Ubuntu Light and Hack also as the built-in fonts for text alphas and decals | Canonical / Source Foundry / Google / Jessie Jung | https://github.com/emilk/egui | Ubuntu Font Licence 1.0, MIT + Bitstream Vera License, OFL 1.1, MIT |
| Only in builds made with `CRAFT_FONTS_DIR`: Inter Regular and SemiBold (desktop and web), from storytold/craft-fonts' Latin catalog (`crates/ui-egui/build.rs`) | Interface text | The Inter Project Authors | https://github.com/storytold/craft-fonts (pinned sources in its `fonts/latin-manifest.txt` and `ATTRIBUTION.md`) | OFL 1.1 |
| Only in builds made with `CRAFT_FONTS_DIR`: BIZ UDPGothic Regular (desktop and web), Noto Sans CJK SC Regular (desktop) and Noto Sans Arabic Regular (desktop and web), from storytold/craft-fonts (`crates/ui-egui/build.rs`) | Japanese, Chinese and Arabic UI text | The BIZ UDGothic Project Authors (Morisawa Inc.); The Noto Project Authors | https://github.com/storytold/craft-fonts (pinned sources in its `fonts/manifest.txt` and `ATTRIBUTION.md`) | OFL 1.1 |

Without craft-fonts, Chinese, Japanese, Korean and Arabic UI text uses the operating system's fonts at run
time (nothing is bundled); see [docs/localization-parity.md](docs/localization-parity.md).

## Procedural content (no asset files)

Built-in environments (`crates/render/src/ibl.rs`), smart materials and procedurals
(`crates/engine/src/materials.rs`, `crates/compose/src/pattern.rs`), brush alphas
(`crates/paint/src/brush.rs`), meshes (`crates/geom/src/primitives.rs`) and shelf thumbnails
(`crates/ui-egui/src/thumbs.rs`) are generated in code by TextureCraft contributors (MIT OR
Apache-2.0). None of them is derived from another product's presets, shaders, materials or images.
