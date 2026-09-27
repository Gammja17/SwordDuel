# Asset Credits

All third-party assets in this folder are either CC0 1.0 (public domain dedication, no attribution
required) or, for fonts, the SIL Open Font License 1.1. Credit is given here anyway, as the authors ask.

- CC0 1.0: https://creativecommons.org/publicdomain/zero/1.0/
- SIL OFL 1.1: see `fonts/OFL.txt`

Changes made: textures and the HDRI are unmodified and only renamed. Every sound was mixed down to
mono and re-encoded as Ogg Vorbis. The one-shot sounds also had leading and trailing silence trimmed,
got a 20 ms fade-out, and were peak-normalized to -1 dBFS. `wind_loop.ogg` was only mixed to mono and
re-encoded; it was not trimmed.

## Textures (`textures/`, 1K JPG, OpenGL normal maps)

| Files | Original asset | Author | Source | License |
|---|---|---|---|---|
| `floor_albedo.jpg`, `floor_normal.jpg`, `floor_rough.jpg` | Cobblestone Floor 01 (`cobblestone_floor_01`: diff, nor_gl, rough) | Rob Tuytel | https://polyhaven.com/a/cobblestone_floor_01 | CC0 |
| `wall_albedo.jpg`, `wall_normal.jpg`, `wall_rough.jpg` | Castle Wall Slates (`castle_wall_slates`: diff, nor_gl, rough) | Rob Tuytel | https://polyhaven.com/a/castle_wall_slates | CC0 |
| `steel_albedo.jpg`, `steel_normal.jpg`, `steel_rough.jpg`, `steel_metal.jpg` | Metal 009, brushed/scratched steel (`Metal009_1K-JPG`: Color, NormalGL, Roughness, Metalness) | ambientCG | https://ambientcg.com/view?id=Metal009 | CC0 |
| `cloth_albedo.jpg`, `cloth_normal.jpg`, `cloth_rough.jpg` | Fabric 036, light grey plain-weave fabric (`Fabric036_1K-JPG`: Color, NormalGL, Roughness) | ambientCG | https://ambientcg.com/view?id=Fabric036 | CC0 |
| `leather_albedo.jpg`, `leather_normal.jpg`, `leather_rough.jpg` | Brown Leather (`brown_leather`: albedo, nor_gl, rough) | Rob Tuytel | https://polyhaven.com/a/brown_leather | CC0 |
| `wood_albedo.jpg`, `wood_normal.jpg`, `wood_rough.jpg` | Weathered Planks (`weathered_planks`: diff, nor_gl, rough) | Dimitrios Savva (photography), Dario Barresi (processing) | https://polyhaven.com/a/weathered_planks | CC0 |
| `mail_albedo.jpg`, `mail_normal.jpg`, `mail_rough.jpg`, `mail_metal.jpg`, `mail_opacity.jpg` | Chainmail 001, small interlinked steel rings, intact (no torn rings) (`Chainmail001_1K-JPG`: Color, NormalGL, Roughness, Metalness, Opacity) | ambientCG | https://ambientcg.com/view?id=Chainmail001 | CC0 |

Notes: `cloth_albedo.jpg` is a single-channel (greyscale) JPG, which makes it easy to tint.
`steel_metal.jpg` is a uniform white (fully metallic) map.
The `mail_*` maps are the one exception to "unmodified": ambientCG ships them as quality-100 JPGs
(5.7 MB for the set), so they were re-encoded at JPEG quality 90 with no chroma subsampling
(2.7 MB). Resolution (1024 x 1024) and channels are unchanged. `mail_opacity.jpg` is the
see-through mask for the gaps between rings (white = ring, dark = gap), for alpha scissor.

## HDRI (`hdri/`)

| File | Original asset | Author | Source | License |
|---|---|---|---|---|
| `sky_1k.hdr` | Belfast Sunset (`belfast_sunset_1k.hdr`), a sunset over dry grass fields and hills with a partly cloudy sky | Dimitrios Savva (photography), Greg Zaal (processing) | https://polyhaven.com/a/belfast_sunset | CC0 |

## Sound effects (`sfx/`, mono Ogg Vorbis)

| File | What it is | Original file (pack) | Author | Source | License |
|---|---|---|---|---|---|
| `clash_1.ogg` | Steel-on-steel clash | `sword_clash.1.ogg` (20 Sword Sound Effects) | StarNinjas | https://opengameart.org/content/20-sword-sound-effects-attacks-and-clashes | CC0 |
| `clash_2.ogg` | Steel-on-steel clash | `sword_clash.2.ogg` (same pack) | StarNinjas | same as above | CC0 |
| `clash_3.ogg` | Steel-on-steel clash | `sword_clash.5.ogg` (same pack) | StarNinjas | same as above | CC0 |
| `clash_4.ogg` | Steel-on-steel clash with a longer ring | `sword_clash.9.ogg` (same pack) | StarNinjas | same as above | CC0 |
| `clash_5.ogg` | Fuller, lower real blade-on-blade clash (sabre against katana), short ring | `Sabre Katana Blade on Blade.wav`, the take at 1.23 to 1.76 s (Medieval sound effects, Weapon Impacts) | Ben Jaszczak & Brian Nelson (Still North Media; submitted to OGA by MedicineStorm) | https://opengameart.org/content/medieval-sound-effects-weapon-impacts | CC0 |
| `clash_6.ogg` | Fuller, lower real blade-on-blade clash (Norse sword against katana) with a double contact | `Norse Sword Katana Blade on Blade.wav`, the take at 18.10 to 18.79 s (same pack) | same as above | same as above | CC0 |
| `scrape_1.ogg` | Steel blade grinding along another steel blade, two strokes (for a bind) | `sword-knife-clash-35.wav` (Fantasy Weapons and Apparel SFX Library) | Vehicle (Jan Schupke) | https://opengameart.org/content/fantasy-weapons-and-apparel-sfx-library | CC0 |
| `scrape_2.ogg` | Steel blade grinding along another steel blade, two strokes | `sword-knife-clash-36.wav` (same pack) | Vehicle (Jan Schupke) | same as above | CC0 |
| `armor_1.ogg` | Short chainmail rattle | `inventory/chainmail1.wav` (RPG Sound Pack) | artisticdude | https://opengameart.org/content/rpg-sound-pack | CC0 |
| `armor_2.ogg` | Short chainmail rattle | `inventory/chainmail2.wav` (RPG Sound Pack) | artisticdude | same as above | CC0 |
| `parry_1.ogg` | Bright ringing metal | `inventory/metal-ringing.wav` (RPG Sound Pack) | artisticdude | https://opengameart.org/content/rpg-sound-pack | CC0 |
| `parry_2.ogg` | Bright, sharp blade clash | `sword_clash.3.ogg` (20 Sword Sound Effects) | StarNinjas | https://opengameart.org/content/20-sword-sound-effects-attacks-and-clashes | CC0 |
| `block_1.ogg` | Dull, heavy metal impact | `impactMetal_heavy_001.ogg` (Impact Sounds) | Kenney | https://kenney.nl/assets/impact-sounds | CC0 |
| `block_2.ogg` | Heavy, low plate impact | `impactPlate_heavy_004.ogg` (Impact Sounds) | Kenney | https://kenney.nl/assets/impact-sounds | CC0 |
| `swing_1.ogg` | Weapon swing whoosh | `battle/swing.wav` (RPG Sound Pack) | artisticdude | https://opengameart.org/content/rpg-sound-pack | CC0 |
| `swing_2.ogg` | Weapon swing whoosh | `battle/swing2.wav` (RPG Sound Pack) | artisticdude | same as above | CC0 |
| `swing_3.ogg` | Weapon swing whoosh | `battle/swing3.wav` (RPG Sound Pack) | artisticdude | same as above | CC0 |
| `swing_4.ogg` | Longer swish | `swish_3.wav` (Battle Sound Effects) | artisticdude | https://opengameart.org/content/battle-sound-effects | Multi-licensed (CC-BY 3.0 / CC-BY-SA 3.0 / GPL 2.0 / GPL 3.0 / CC0); used here under **CC0** |
| `cut_1.ogg` | Blade slice | `knifeSlice.ogg` (RPG Audio) | Kenney | https://kenney.nl/assets/rpg-audio | CC0 |
| `cut_2.ogg` | Blade slice | `knifeSlice2.ogg` (RPG Audio) | Kenney | https://kenney.nl/assets/rpg-audio | CC0 |
| `hurt_1.ogg` | Short male grunt | `3grunt4.wav` (Male Grunt/Yelling sounds) | HaelDB | https://opengameart.org/content/male-gruntyelling-sounds | Dual-licensed (OGA-BY 3.0 / CC0); used here under **CC0** |
| `hurt_2.ogg` | Short male pain/strain vocal | `slightscream-08.flac` (15 vocal male strain/hurt/pain/jump sounds) | qubodup | https://opengameart.org/content/15-vocal-male-strainhurtpainjump-sounds | CC0 (the page says it has been CC0 since 2024-08-30) |
| `step_1.ogg` | Footstep on stone | `Fantozzi-StoneL1.flac` (Fantozzi's Footsteps) | Fantozzi (submitted to OGA by qubodup; originally from freesound.org, pack 10338) | https://opengameart.org/content/fantozzis-footsteps-grasssand-stone | CC0 |
| `step_2.ogg` | Footstep on stone | `Fantozzi-StoneR1.flac` (same pack) | Fantozzi | same as above | CC0 |
| `step_3.ogg` | Footstep on stone | `Fantozzi-StoneL2.flac` (same pack) | Fantozzi | same as above | CC0 |
| `step_4.ogg` | Footstep on stone | `Fantozzi-StoneR2.flac` (same pack) | Fantozzi | same as above | CC0 |
| `draw_1.ogg` | Sword unsheathe | `battle/sword-unsheathe.wav` (RPG Sound Pack) | artisticdude | https://opengameart.org/content/rpg-sound-pack | CC0 |
| `wind_loop.ogg` | Gentle wind ambience loop (about 6 s) | `wind woosh loop.ogg` (wind whoosh loop, cut from "Loopable Dungeon Ambience") | SketchMan3 | https://opengameart.org/content/wind-whoosh-loop | CC0 |

Notes on the later additions (`clash_5`, `clash_6`, `scrape_1`, `scrape_2`, `armor_1`, `armor_2`): they got
the same processing as the other one-shots (mono, trim, 20 ms fade-out, peak -1 dBFS before Ogg encoding).
The Still North files are long 192 kHz recordings with many hits each, so one hit was cut out by time
(given in the table), downsampled to 48 kHz, and trimmed at -60 dB instead of -50 dB to keep a little
more of the ring. The Still North pack says its sounds are CC0 ("NO RIGHTS RESERVED"); the OGA page is
also marked CC0. The Vehicle pack's readme says "Distributed under Creative Commons Zero", and its page says
the sounds are organic recordings, unprocessed apart from normalization. The scrape recordings are a sword
blade sliding along a knife blade, both steel.

## 3D props (`props/`, glTF 2.0 with 1K JPG textures, OpenGL normal maps)

Each folder holds the `.gltf`, its `.bin` and a `textures/` folder, exactly as Poly Haven ships the 1K glTF
download; nothing was changed or renamed inside a folder. Textures use Poly Haven's packed `arm` map
(R = ambient occlusion, G = roughness, B = metalness), except the stool, which has a plain roughness map.
Sizes are Poly Haven's listed real-world dimensions (width x depth x height; the models are in metres).

| Folder | Original asset | Size (W x D x H) | Triangles | Author | Source | License |
|---|---|---|---|---|---|---|
| `barrel/` | Wine Barrel 01 (`wine_barrel_01_1k.gltf`), oak staves, iron hoops, bung hole, separate lid | 0.74 x 0.76 x 0.87 m | 10,820 | James Ray Cock | https://polyhaven.com/a/wine_barrel_01 | CC0 |
| `crate/` | Wooden Crate 01 (`wooden_crate_01_1k.gltf`), old plank chest with rope handles and a latch, separate lid | 0.83 x 0.41 x 0.35 m | 6,576 | James Ray Cock | https://polyhaven.com/a/wooden_crate_01 | CC0 |
| `bucket/` | Wooden Bucket 01 (`wooden_bucket_01_1k.gltf`), iron bands and an iron handle | 0.37 x 0.34 x 0.55 m (with handle up) | 5,116 | James Ray Cock | https://polyhaven.com/a/wooden_bucket_01 | CC0 |
| `lantern/` | Wooden Lantern 01 (`wooden_lantern_01_1k.gltf`), wooden frame with glass panes (the glass material is alpha BLEND), door and handle | 0.22 x 0.24 x 0.53 m | 8,321 | James Ray Cock | https://polyhaven.com/a/wooden_lantern_01 | CC0 |
| `stool/` | Wooden Stool 01 (`wooden_stool_01_1k.gltf`), worn round-seat stool | 0.43 x 0.44 x 0.44 m | 10,946 | Kuutti Siitonen | https://polyhaven.com/a/wooden_stool_01 | CC0 |
| `kite_shield/` | Kite Shield (`kite_shield_1k.gltf`), painted wooden kite shield with an iron rim, two materials | 0.54 x 0.14 x 1.39 m | 10,306 | Ulan Cabanilla | https://polyhaven.com/a/kite_shield | CC0 |
| `castle_door/` | Large Castle Door (`large_castle_door_1k.gltf`), arched double wooden door with iron straps; frame and each leaf are separate nodes | 2.01 x 0.34 x 2.97 m | 12,640 | Tina | https://polyhaven.com/a/large_castle_door | CC0 |
| `fire_pit/` | Stone Fire Pit (`stone_fire_pit_1k.gltf`), a ring of rough stones around a sooty basin | 1.45 x 1.43 x 0.39 m | 3,887 | Sebastian Platen | https://polyhaven.com/a/stone_fire_pit | CC0 |

## Fonts (`fonts/`)

| File | Original asset | Author | Source | License |
|---|---|---|---|---|
| `NanumMyeongjo-Regular.ttf` | Nanum Myeongjo Regular (weight 400), full font, not subset | NHN Corporation (Naver); designed by Sandoll Communication / FONTRIX | https://github.com/google/fonts/tree/main/ofl/nanummyeongjo | SIL OFL 1.1 |
| `NanumMyeongjo-ExtraBold.ttf` | Nanum Myeongjo ExtraBold (weight 800), full font, not subset | same as above | same as above | SIL OFL 1.1 |
| `OFL.txt` | The license text that ships with the font (Copyright (c) 2010 NHN Corporation; its Reserved Font Names include "Nanum" and "NanumMyeongjo") | — | same as above | — |

## Characters (`characters/`)

Files are unmodified and keep the pack's own names. `Knight.glb` already embeds `knight_texture.png`; the
loose copy in `weapons/` is there because the weapon `.gltf` files load it from their own folder.
See `characters/knight/INSPECT.md` and `characters/body/INSPECT.md` for the rigs, animations and sizes.

| Files | Original asset | Author | Source | License |
|---|---|---|---|---|
| `knight/Knight.glb`, `knight/knight_texture.png`, `knight/LICENSE.txt` | KayKit Character Pack: Adventurers 1.0, Knight (`Characters/gltf/Knight.glb`: rigged low-poly knight with 76 animations, swords, shields, helmet and cape as bone-attached nodes) | Kay Lousberg (KayKit) | https://github.com/KayKit-Game-Assets/KayKit-Character-Pack-Adventures-1.0 (also https://kaylousberg.itch.io/kaykit-adventurers) | CC0 |
| `knight/weapons/sword_1handed.gltf` + `.bin`, `sword_2handed.gltf` + `.bin`, `sword_2handed_color.gltf` + `.bin`, `knight/weapons/knight_texture.png` | Same pack (`Assets/gltf/`: one-handed sword, two-handed sword, coloured two-handed sword) | Kay Lousberg (KayKit) | same as above | CC0 |
| `body/UAL1_Standard.glb`, `body/LICENSE.txt` | Universal Animation Library, free Standard version v3.0 (`Unreal-Godot/UAL1_Standard.glb`, no root motion build: realistic-proportion 1.83 m mannequin on a 65-joint humanoid rig with 43 animations; `License.txt` renamed) | Quaternius | https://quaternius.itch.io/universal-animation-library (also https://quaternius.com) | CC0 |
| `body/UAL2_Standard.glb` | Universal Animation Library 2, free Standard version v2.1 (`Unreal-Godot/UAL2_Standard.glb`, no root motion build: same mannequin and rig with 43 more animations, including sword combos and block) | Quaternius | https://quaternius.itch.io/universal-animation-library-2 (also https://quaternius.com) | CC0 |
