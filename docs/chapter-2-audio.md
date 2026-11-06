# 第二章音效来源

2026-11-06 由检索代理整理。授权都在素材页面上核对过，但**没有下载试听**：“合适”只是根据页面描述判断。Kenney 包内的文件名凭记忆列出，未核实。Freesound 的素材要登录才能下载；OpenGameArt、Kenney、BigSoundBank 可以直接下载。

取舍顺序：

1. 先复用一代已有的声音。
2. 其次用 CC0 素材，不需要署名。
3. 再次用 CC-BY 素材，要在制作名单里署名，署名文字见下方原报告。
4. 已排除 CC-BY-SA、GPL、NC 授权的素材，也排除了 Pixabay。

## 需要生成的音效

统一要求：单声道、44.1 kHz、干声、短促有力的游戏音效。除非特别说明，不要混响尾巴。

- **必做**：检索没有找到可用素材。
- **备选**：已有候选或可复用一代的声音，试听后觉得不够好再生成。

| 级别 | 编号 | 用途 | 英文生成提示词 |
| --- | --- | --- | --- |
| 必做 | 5 | 火铳装填 | Musket reload: ramrod scrape in barrel, powder pour hiss, match-cord click, ~1.6 s, one-shot, dry foley. |
| 必做 | 6 | 开花弹（延迟爆） | Delayed explosive shell: wooden thunk, then 0.4 s later a small pop/blast, 1 s total, one-shot. |
| 必做 | 6 | 霰子弹 | Scatter shot: shotgun-like spread burst with pellet rattle, 0.7 s, one-shot. |
| 必做 | 13 | 木铃 | Small wooden hand bell, two quick knocks with a woody ring, 0.6 s, one-shot. |
| 必做 | 14 | 绳索：甩出、崩断 | Lasso: fast rope whirl then whip throw, 0.8 s. Rope snap: taut rope twang then a sharp crack, 0.5 s. Two one-shots. |
| 必做 | 15 | 拖尸 | Heavy body dragged on dirt: low scrape with cloth rustle, 2 s seamless loop. |
| 必做 | 16 | 尸车：车轮、火罐碎裂 | Wooden cart rolling over dirt, creaky wheels, 2 s seamless loop. Clay fire-pot shatter: ceramic crash plus whoomph of flame, 1 s one-shot. |
| 必做 | 18 | 骨弩床上弦 | Ballista wind-up: ratcheting wooden crank with rope tension, 1.5 s, one-shot. |
| 必做 | 20 | 掘地钻出 | Burrowing creature emerging: dirt crumble and gravel burst from below with a low rumble, 1.2 s, one-shot. |
| 必做 | 23 | 雾灯：哀嚎、嗡鸣 | Ghostly wail: thin eerie hollow wail with slow pitch drop, 1.5 s one-shot. Fog lantern hum: faint sinister hum with flicker, 2 s seamless loop. |
| 必做 | 24 | 蛛网：射出、粘住 | Spider web shot: wet sticky fwip of a thread launch, 0.4 s. Web snag: sticky stretch and snap, 0.5 s. Two one-shots. |
| 必做 | 25 | 飞僵起跳 | Jiangshi hop launch: stiff cloth flap and a quick spring thump, 0.4 s, one-shot. |
| 必做 | 26 | 瘴囊破裂 | Gas sac pop: wet puff, then a toxic hiss that fades, 1.2 s, one-shot. |
| 必做 | 27 | 魂锚连线 | Magical tether hum: low pulsing dark arcane drone, 2 s seamless loop. |
| 必做 | 29 | 船钟、水车 | Ship bell: two strikes of a small brass ship bell with a short ring, 1.5 s one-shot. Watermill: slow wooden wheel creak with water splash, 3 s seamless loop. |
| 备选 | 1 | 火铳单发 | Matchlock musket single shot: sharp black-powder crack with a short smoke-puff hiss, 0.6 s, one-shot, 3 variants with slightly different pitch. |
| 备选 | 2 | 五雷连射 | Five matchlock cracks in a rapid burst, about 0.12 s apart, slightly different pitch each, 1.0 s total, one-shot. |
| 备选 | 9 | 重骑冲锋 | Cavalry charge: 5-6 horses galloping on dirt, rising rumble, 3 s seamless loop, no neighs. |
| 备选 | 10 | 裂风刃 | Wind blade slash: airy high-pitched cut with a short whistle, 0.35 s, one-shot. |
| 备选 | 11 | 沉砂 | Sand and gravel slithering, soft, 1.5 s seamless loop. |
| 备选 | 12 | 回流缚 | Water whip: tight liquid lash with a swirl, 0.7 s, one-shot. |
| 备选 | 13 | 莲灯 | Lotus lantern: small soft fire whoosh with a warm shimmer, 0.7 s, one-shot. |
| 备选 | 17 | 蛾群振翅 | Moth wings: soft papery fast flapping, 0.6 s, loopable. |
| 备选 | 28 | 战鼓滚奏 | War drum roll that builds over 2.5 s and ends on one heavy hit, deep, one-shot. |

## 检索原报告（英文）


Method: licences were read from the actual asset/pack pages (WebFetch, or fetching the OpenGameArt/Freesound HTML directly). Nothing was downloaded or auditioned. "Fit" notes come from page descriptions only. Kenney file names are from memory of the packs and NOT verified (marked "names unverified").
Existing game sounds come from `game/service/sound_library.gd` (LIB_CLASSES). The remake is mono-friendly; BigSoundBank files are mostly mono or stereo 48 kHz and may need trimming/down-mixing.

### 1. Reuse from the existing game

| # | Existing sound name | Why it fits |
|---|---|---|
| 7 | HEAVY_SWORD1-3 (sHeavySword), AXE1-3, SWORD_SWOOSH1-7 | Heavy cleave = whoosh + heavy hit; spear/lance thrust = SWORD_SWOOSH + IMPACT_FLESH/ARROW_IMPACT. Pitch-shift if a different feel is wanted. |
| 8 | BLOCK1-2 (sBlock), IMPACT_ARMOR1-3 (sArmorHit) | Shield bash = block thud + armor hit. |
| 22 | BONEBREAK (sBoneBreaked), OGRE_PUNCH | Bone smash / heavy club. |
| 9 (impact part) | IMPACT_ARMOR1-3, CREATURE_ATTACK1-3, BIG_CREATURE_ATTACK1-2 | Mounted collision. |
| 10 (blade part) | SWORD_SWOOSH1-7 | Airy wind-blade cut (high-pass / pitch up). |
| 11 (sand slow) | SLOW (sRealSlow), SUPPRESS (sSlow) | Slowing patch already has a slow sound. |
| 14 (throw part) | SWORD_SWOOSH variants | Lasso throw whoosh, pitched down. |
| 18 (bolt parts) | CROSSB_SHOOT1-3 (release), ARROW_IMPACT1-7 / ARROW_GROUND (impact) | Ballista release and impact. |
| 19 (roar part) | MONSTER1-5 (sMonster), OGRE_DEAD, OGRE_PUNCH | Beast roar/groan and heavy hit. |
| 28 (wave warning) | NEW_WAVE (sNewWave), UNIT_KILLED (sUnitKilledDrum) | Wave alarm already exists; arrow-volley warning could use ARROW_SWARM. |
| 30 (failed) | CLICKFAIL (sFail), BTN_DENY | Short denial/danger cue; also usable: HAS_UPGRADE / HIRE for a positive cue. |

Needs 7, 8, 22 are fully covered by reuse. The rest above cover sub-parts only; the remaining parts are in section 2 or 4.

### 2. Found

All licences read on the page. "Account" column: direct = a download link with no login (OpenGameArt, Kenney, BigSoundBank; BigSoundBank pages block scripted fetching with 403 but opened fine in WebFetch). Freesound = needs account.

| # | Candidate | URL | Licence (exact) | Download | Notes |
|---|---|---|---|---|---|
| 1, 2 | OpenGameArt "Gunshots" (LarkPay), file `Black Powder.wav` | https://opengameart.org/content/gunshots | CC0 | direct | Multiple shots per file with some echo (page's own warning). Cut single shots for #1 variants; the multi-shot take can be cut into a 5-shot burst for #2. Not auditioned. |
| 1 | Freesound "44_black_powder.wav" (Jon285), black-powder revolver, 6 shots | https://freesound.org/s/34708 | CC0 (creativecommons.org/publicdomain/zero/1.0) | needs account | Revolver, not musket; pitch down and add tail. |
| 3, 4, 6 | OpenGameArt "25 CC0 bang / firework SFX" (Snabisch) | https://opengameart.org/content/25-cc0-bang-firework-sfx | CC0 | direct | Bangs/cannon/explosions, "a few short bangs usable for gun shots", one loopable. Covers heavy barrel (#3), hand cannon (#4), concussion burst (#6). |
| 3, 4 | OpenGameArt "The Free Firearm Sound Library" (`Prepared SFX Library.7z`) | https://opengameart.org/content/the-free-firearm-sound-library | CC0 | direct | Real firearm recordings; archive contents not enumerated by me (7z not opened). Possible source of deeper booms. |
| 6 (armor-piercing ping) | OpenGameArt "100 CC0 metal and wood SFX" (Barina) | https://opengameart.org/content/100-cc0-metal-and-wood-sfx | CC0 | direct | Metal hit/slam sounds; also wood hit/slam for #21. Pick a metal hit and high-pass it. |
| 6 (ping alt) | Kenney Impact Sounds (130 files, e.g. impactMetal_*, impactPlate_*; names unverified) | https://kenney.nl/assets/impact-sounds | CC0 (page: "Creative Commons CC0") | direct | Also source for #25 landing thud (impactSoft_heavy / footstep_*, unverified names). |
| 9 gallop loop | BigSoundBank "Horse gallop" #611 | https://bigsoundbank.com/horse-gallop-s0611.html | CC0 (public domain, no attribution) | direct | 13 s, mono, 48 kHz, dirt/concrete foley. Needs loop trim. |
| 9 gallop loop (alt) | OpenGameArt "Horse Gallop Loop" (Alan McKinney / alanmcki) | https://opengameart.org/node/132682 | CC-BY 3.0 | direct | Ready-made loop, mono OGG. Attribution: "Horse Gallop Loop by Alan McKinney (alanmcki), via OpenGameArt.org, CC BY 3.0". |
| 9 charge rumble | OpenGameArt "Horse gallop on different surfaces" (MedicineStorm) | https://opengameart.org/node/167525 | CC-BY 4.0 | direct | Attribution: "Horse gallop on different surfaces by MedicineStorm, OpenGameArt.org, CC BY 4.0 (adapted from various sounds)". Rumble for several horses = layer 3-4 copies of #611 with offsets (CC0 route). |
| 9 neigh | Freesound "G38-07-Horse Whinnies.wav" (craigsmith) | https://freesound.org/s/437100 | CC0 (zero/1.0) | needs account | Several whinnies in one file; cut one. |
| 9 neigh (alt) | Freesound "Horse Whinny, Close, A.wav" (InspectorJ) | https://freesound.org/people/InspectorJ/sounds/419231/ | CC-BY 4.0 | needs account | Attribution: "Horse Whinny, Close, A by InspectorJ, freesound.org, CC BY 4.0". |
| 10 wind barrier | OpenGameArt "wind whoosh loop" | https://opengameart.org/content/wind-whoosh-loop | CC0 | direct | OGG loop, EQ'd to bring out highs. |
| 11 stone spikes | OpenGameArt "Earth Impact - Magic Effect" (Puffolotti) | https://opengameart.org/content/earth-impact-magic-effect | CC0 | direct | 5 earth-magic effects in one zip. |
| 12 water wave / whip | OpenGameArt "40 CC0 water / splash / slime SFX" (rockseller) | https://opengameart.org/content/40-cc0-water-splash-slime-sfx | CC0 | direct | 15 splashes + 16 slime (slime = usable for water bind/whip when pitched), 6 loops. |
| 12 alt | OpenGameArt "6 Short water splashes" | https://opengameart.org/content/6-short-water-splashes | CC0 | direct | Short splashes. |
| 13 hand bell | BigSoundBank "Bell" #897, medium garden-entrance bell | https://bigsoundbank.com/bell-s0897.html | CC0 | direct | 19 s, mono, UCS "Handbell"; trim to the strike. Wooden-bell timbre not guaranteed. |
| 13 hand bell (alt) | Freesound "Hand Bells, B/D/E/G, Single.wav" (InspectorJ) | https://freesound.org/people/InspectorJ/sounds/339809/ | CC-BY 4.0 | needs account | Several pitched single hits. Attribution: "Hand Bells, Single by InspectorJ, freesound.org, CC BY 4.0". |
| 13 temple bell | Freesound "temple_bell_002.wav" (tec_studio) | https://freesound.org/people/tec_studio/sounds/668647/ | CC0 (zero/1.0) | needs account | Single strike; decay length not checked. |
| 13 chime | OpenGameArt "Bell dings/chimes" (4 wavs) | https://opengameart.org/node/53288 | CC0 | direct | Thin short chimes; also "Pleasing Bell Sound Effect" https://opengameart.org/node/86163 (CC0). |
| 13 singing bowl | BigSoundBank "Tibetan bowl struck #1" | https://bigsoundbank.com/tibetan-bowl-struck-s1110.html | CC0 | direct | 31 s, mono, 48 kHz/16-bit; cut to 2-3 s for a sealing chime. |
| 13 lantern whoosh | OpenGameArt "Fire Staff Sound Effects" (LEGIT Audio) | https://opengameart.org/content/fire-staff-sound-effects | CC0 | direct | 25 fire-staff sounds; page footnote refers to Gumroad. Use a short whoosh. |
| 14 rope creak (only) | BigSoundBank "Rope" #3417 | https://bigsoundbank.com/rope-s3417.html | CC0 | direct | 2:05 stereo creaking rope nets; only helps the tension/creak, not snap. |
| 16 fire burst / loop | OpenGameArt "Fireplace Sound loop" and "Synthesized Fire Sound Effect" | https://opengameart.org/content/fireplace-sound-loop , https://opengameart.org/content/synthesized-fire-sound-effect | CC0 both | direct | Burning loop. Fire burst: use #3/#4 bang pack + whoosh. |
| 16 pot shatter | OpenGameArt "100 CC0 SFX" (aijikl): lists 5x glass, 2x pot, 1x explosion | https://opengameart.org/content/100-cc0-sfx | CC0 | direct | Phone recordings, check quality. Cart rolling loop NOT found. |
| 17 insect swarm | BigSoundBank "Many flies" #822 | https://bigsoundbank.com/many-flies-s0822.html | CC0 | direct | 1:13 stereo buzz, loop candidate. Also "Solitary bees or flies" #101 (https://bigsoundbank.com/solitary-bees-or-flies-s0101.html, 5 s; I did not open the licence line on that page, treat as unverified). Wing flutter not found. |
| 18 crank / windup | none verified; the crossbow bolt release/impact is reused (section 1). Optional: OGA "Crossbow Shot" https://opengameart.org/content/crossbow-shot (CC-BY 3.0, ElTronic, attribution "Crossbow Shot by ElTronic, OpenGameArt.org, CC BY 3.0") | | | direct | Crank still needs generation (section 4). |
| 19 footstep thud | OpenGameArt "80 CC0 creture SFX #2" (Dread Knight): lists 4x stomp, 8x roar, 3x monster, 5x die | https://opengameart.org/content/80-cc0-creture-sfx-2 | CC0 | direct | Also "80 CC0 creature SFX" (https://opengameart.org/content/80-cc0-creature-sfx, CC0; 3x roar, 5x troll, 7x monster). |
| 21 ram on gate | OpenGameArt "100 CC0 metal and wood SFX" (wood hit, slam, breaking) | https://opengameart.org/content/100-cc0-metal-and-wood-sfx | CC0 | direct | Heavy wood slam; also Kenney impactWood_* (names unverified). |
| 25 landing thud | Kenney Impact Sounds | https://kenney.nl/assets/impact-sounds | CC0 | direct | See #6. Jump launch not found. |
| 27 chain clank | Freesound "Big Metal Chain" (qubodup) | https://freesound.org/s/199282 | CC0 (zero/1.0) | needs account | Heavy chain drag. Also OGA "80 CC0 RPG SFX" lists 3x chain (https://opengameart.org/content/80-cc0-rpg-sfx, CC0, direct). Magical tether hum not found. |
| 28 gong | BigSoundBank "Gong, strong #2" | https://bigsoundbank.com/gong-strong-2-s1484.html | CC0 | direct | 15 s, 24-bit studio mallet on small gong; use first 1-2 s with a fade. |
| 28 war horn | OpenGameArt "War Horns" (HyperLegend) | https://opengameart.org/node/153572 | CC0 | direct | wav + mp3; "suspenseful war horns", length not stated. |
| 28 drums (not a roll) | OpenGameArt "Horde War Drums loop" (William Hector) | https://opengameart.org/node/176112 | CC0 | direct | 130 BPM music-style loop, not a short drum roll; cut a section if wanted. |
| 29 gate creak | BigSoundBank "Door squeaks and rubs #1" | https://bigsoundbank.com/door-squeaks-and-rubs-1-s1159.html | CC0 | direct | 7 s mono. Also OGA "Creaky Door Hinge Spooky" https://opengameart.org/content/creaky-door-hinge-spooky (CC0). |
| 29 sea waves | BigSoundBank "Small waves and beach #2" | https://bigsoundbank.com/small-waves-and-beach-2-s1448.html | CC0 | direct | 6:14 stereo ORTF, 24-bit. Crossfade-loop a section. |
| 29 river | BigSoundBank "Small dam" #871 | https://bigsoundbank.com/small-dam-s0871.html | CC0 | direct | 1:10 stereo mill-dam river. Alt: OGA "Sea and river wave sounds" (Snabisch, CC0) https://opengameart.org/content/sea-and-river-wave-sounds. Ship bell and watermill creak not found. |
| 30 complete | Kenney Interface Sounds (100 files) and Kenney Music Jingles (85 files) | https://kenney.nl/assets/interface-sounds , https://kenney.nl/assets/music-jingles | CC0 (both) | direct | Use a confirmation sound or short jingle; names unverified. |

### 3. Packs that cover many needs

- OpenGameArt/BigSoundBank-style CC0 sets, grouped by source:
  - **BigSoundBank** (https://bigsoundbank.com , every file I opened is CC0, no attribution): #9 gallop, #13 bell + singing bowl, #14 rope, #17 flies, #28 gong, #29 gate creak + sea + river.
  - **OpenGameArt "100 CC0 metal and wood SFX" + "100 CC0 SFX" + "100 CC0 SFX #2"** (CC0): #6, #16, #21, #29 (door).
  - **OpenGameArt creature packs (80 CC0 creature SFX, #2, 80 CC0 RPG SFX)** (CC0): #19, #27 chain, partially #23/#26.
  - **Kenney Impact Sounds / Interface Sounds / Music Jingles** (CC0): #6, #21, #25, #30.
- **Sonniss GDC Game Audio Bundle**: licence page says games/film/TV use only, no attribution, no AI/ML training, no account for download, but the latest (2024) is 23.5 GB and I did not browse contents. A tag search at sonniss.com/sound-effects-tag/ may fill #14, #15, #20, #23, #24, #26 if you accept the size. Not verified item by item.
- Not used: Pixabay Content License forbids redistributing files in unmodified standalone form (fine inside a game build) and I could not confirm account requirements, so nothing from Pixabay is listed.
- Rejected: CC-BY-SA/GPL items (Church Bell, Death Bell, Spell Sounds Starter Pack, Whoosh 1), CC-BY-NC (richardemoore ChainWrapping, arnaud coutancier horse in forest), mixed-licence "Wierd Whooshes".

### 4. Not found - needs generation

Write these into an audio generator (all mono, 44.1 kHz, game-SFX punchy, dry, no reverb tail unless stated).

| # | What to generate |
|---|---|
| 1 | (If the Black Powder.wav cuts sound weak) Matchlock musket single shot: sharp black-powder crack with short smoke puff hiss, 0.6 s, one-shot, 3 pitch variants. |
| 2 | Five-barrel volley: five matchlock cracks in a rapid burst, ~0.12 s apart, slightly different pitch each, 1.0 s total, one-shot. |
| 5 | Musket reload: ramrod scrape in barrel, powder pour hiss, match-cord click, ~1.6 s, one-shot, dry foley. |
| 6 (delayed shell) | Delayed explosive shell: wooden "thunk" then 0.4 s later a small pop/blast, 1 s, one-shot. |
| 6 (scatter) | Scatter shot: shotgun-like spread burst with pellet rattle, 0.7 s. |
| 9 (rumble) | Cavalry charge: 5-6 galloping horses on dirt, rising rumble, 3 s loop, no neighs. |
| 10 | Wind blade slash: airy high-pitched cut with short whistle, 0.35 s, one-shot. |
| 11 (sand patch) | Sand and gravel slithering underfoot, 1.5 s loop, soft. |
| 13 (wooden bell) | Small wooden hand bell, two quick knocks with a woody ring, 0.6 s. |
| 13 (lamp) | Lotus lantern: small soft fire whoosh with a warm shimmer, 0.7 s. |
| 14 | Rope snap: taut rope twang then a sharp crack, 0.5 s one-shot. Lasso: fast rope whirl then whip throw, 0.8 s. |
| 15 | Heavy body dragged on dirt: low scrape with cloth rustle, 2 s loop. |
| 16 | Wooden cart rolling over dirt: creaky wheels rumble, 2 s loop. Clay fire-pot shatter: ceramic crash plus whoomph of flame, 1 s. |
| 17 (wing) | Moth wing flutter: soft papery fast flapping, 0.6 s, loopable. |
| 18 | Ballista wind-up: ratcheting wooden crank with rope tension, 1.5 s; heavy bolt release: deep twang plus whoosh, 0.5 s. |
| 20 | Burrowing emerge: dirt crumble and gravel burst from below with a low rumble, 1.2 s one-shot. |
| 23 | Ghostly wail: thin eerie hollow wail with slow pitch drop, 1.5 s one-shot; fog lantern hum: faint sinister hum with flicker, 2 s loop. |
| 24 | Spider web shot: wet sticky "fwip" thread launch, 0.4 s; web snag: sticky stretch snap, 0.5 s. |
| 25 | Jiangshi hop launch: stiff cloth flap and quick spring thump, 0.4 s one-shot. |
| 26 | Gas sac pop: wet puff, then toxic hiss that fades, 1.2 s one-shot. |
| 27 | Magical tether hum: low pulsing arcane drone, 2 s loop, dark. |
| 28 (drum roll) | Taiko war drum roll that builds, 2.5 s one-shot, deep, then a final hit. |
| 29 | Ship bell: two strikes of a small brass ship bell with a short ring, 1.5 s. Watermill creak: slow wooden wheel creak with splash, 3 s loop. |
| 12 (water whip) | Water whip/bind: tight liquid lash with swirl, 0.7 s one-shot (the splash pack may do if pitched). |
