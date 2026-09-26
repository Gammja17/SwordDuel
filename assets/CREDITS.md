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

Notes: `cloth_albedo.jpg` is a single-channel (greyscale) JPG, which makes it easy to tint.
`steel_metal.jpg` is a uniform white (fully metallic) map.

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

## Fonts (`fonts/`)

| File | Original asset | Author | Source | License |
|---|---|---|---|---|
| `NanumMyeongjo-Regular.ttf` | Nanum Myeongjo Regular (weight 400), full font, not subset | NHN Corporation (Naver); designed by Sandoll Communication / FONTRIX | https://github.com/google/fonts/tree/main/ofl/nanummyeongjo | SIL OFL 1.1 |
| `NanumMyeongjo-ExtraBold.ttf` | Nanum Myeongjo ExtraBold (weight 800), full font, not subset | same as above | same as above | SIL OFL 1.1 |
| `OFL.txt` | The license text that ships with the font (Copyright (c) 2010 NHN Corporation; its Reserved Font Names include "Nanum" and "NanumMyeongjo") | — | same as above | — |
