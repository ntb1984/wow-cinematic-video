---
name: wow-cinematic-video
description: Produce short cinematic AI videos of World of Warcraft places and moments (city tours, boss fights, lore scenes) — generate chained 10s clips, verify frames, assemble with crossfades on a cloud VM, upscale to 4K, deliver. Use when the user asks for a Warcraft / WoW video, a game-city tour video, or names a place/scene （暴风城， 奥格瑞玛， 达拉然， 泰达希尔， 熔火之心， 冰封王座， 希尔瓦娜斯， 巫妖王…), or asks to extend/remake one of these videos.
---

# WoW Cinematic Video

Battle-tested pipeline (six productions: Stormwind, Orgrimmar POV, Dalaran,
Teldrassil, Molten Core, Sylvanas vs the Lich King). Three 10-second generated
clips → crossfade assembly on a rented cloud VM → 4K upscale → verified delivery.

## Pipeline at a glance

1. Generate 3 clips (~10s each), chained for visual continuity.
2. Verify every clip: probe specs, extract a mid-frame, look at it.
3. Pack clips, ship to the cloud VM, assemble + upscale with `scripts/assemble.sh`.
4. Ship the result back, verify bytes/specs/frame, deliver in chat.

## Step 1 — Generate the clips

- Use the video generation tool with the user's request **verbatim** as the
  prompt. Do not prettify it — the generator expands short prompts itself.
- Chain for continuity: pass clip 1's `snapshot_id` as
  `resume_from_snapshot_id` for clip 2, and clip 2's for clip 3.
- Failure modes (all observed):
  - `resume` calls intermittently die with upstream 503. Recovery: make a
    **fresh, independent** generation (optionally a shorter prompt — just the
    place name worked well, e.g. "达拉然"). Fresh calls succeed far more often.
  - A combat-finale segment may be refused outright. Do not retry it or route
    around it. Ship the segments you have (see the SLOW trick below) and offer
    the user a different, gentler closing direction for them to approve.
- The generator takes meta-words literally. If the user's sentence contains a
  brand or instruction ("render it in 4K on InstaBox"), expect it **inside the
  picture** (a neon "InstaBox" shop appeared in Dalaran). Sometimes that is a
  delightful easter egg; if the user wants a clean cut, regenerate that segment
  with a minimal prompt.
- Famous moments attract famous imagery: a plain "Teldrassil" prompt produced
  the **Burning** of Teldrassil. Always frame-check (Step 2) and keep off-brief
  takes as labeled outtakes — users often want them as a bonus version.

## Step 2 — Verify before you assemble

For each clip:

- `ffprobe`: expect ~10.0s, 24 fps, H.264 + AAC. **Resolutions vary**
  (1280×720, 1248×704, 1216×672 all seen) — the assemble script normalizes.
- Extract a frame at ~4–5s (`ffmpeg -ss 5 -frames:v 1`) and actually look:
  right place? right characters? any garbled text or off-brief content?
- Nameplates reading the prompt text back （联盟勇士们 over the raid's heads)
  are charming, not a defect.

## Step 3 — Assemble on the cloud VM (InstaBox)

Why not locally: the orchestrator sandbox is small (2 cores, ~400 MB free RAM).
The VM (4 vCPU AMD EPYC / 8 GB) renders a 29s 4K upscale in ~100s.

Operational rules (each one cost time once):

- CLI: `npm i -g --prefix ~/workspace/tools instabox` (a plain global install
  vanishes when the host VM is redeployed; a home-dir prefix persists).
  Authenticate via `INSTABOX_API_KEY` in the environment; set
  `INSTABOX_NO_TELEMETRY=1`. Never write the key to disk or logs.
- **Address machines by ID, not name.** Name lookups intermittently time out;
  ID lookups are instant. `instabox wake <machine-id>` resumes an
  idle-suspended box in seconds (boxes auto-suspend after 30 min idle;
  files on the persistent disk survive).
- `instabox exec` caps `--timeout` at 600. For long renders, launch with
  `nohup ffmpeg ... > render.log 2>&1 &`, then poll `pgrep ffmpeg` +
  the output file size. Note the exec call may block until the background
  job finishes anyway — that is normal, not a hang.
- The box ships without ffmpeg: `sudo apt-get install -y ffmpeg`
  (passwordless sudo, ~12s).
- Assembly: `scripts/assemble.sh OUTPUT c1.mp4 c2.mp4 c3.mp4`
  (defaults: 0.5s xfades, lanczos upscale to 3840×2160, unsharp 0.7,
  x264 preset fast, CRF 22, maxrate 28M — a 29s result lands at 85–105 MB).
  Total runtime = sum of clips − 0.5s per joint (3×10s → ~29s).
- **Missing-segment trick:** with only 2 clips, `SLOW=0.75` stretches them to
  ~26s and battle footage honestly looks better in slight slow motion.

## Step 4 — File transfer (the minefield)

- catbox.moe rejects datacenter IPs ("Invalid uploader"). Use **tmpfiles.org**:
  upload with `curl -F "file=@..." https://tmpfiles.org/api/v1/upload`.
- The returned page URL is a landing page, **not** the file. Fetch it and
  extract the fresh `https://tmpfiles.org/dl/<rotating-token>/...` href,
  then download immediately — tokens rotate per page load.
- Verify the downloaded size matches the VM-side size byte-for-byte.

## Step 5 — Deliver honestly

- `ffprobe` the final file (expect 3840×2160, ~29s) and view one frame from
  the last segment before attaching it in chat.
- Say plainly that the source is 720p generation: the 4K is a high-quality
  lanczos upscale, not native detail. Users respect the honesty; the result
  still looks far better on a TV than raw 720p.
- Report content structure shot-by-shot, plus any outtakes you kept.

## Prompt seeds that worked

| Request | Result |
|---|---|
| 暴风城 | gate + trade district, lion banners, cathedral |
| 奥格瑞玛进城的第一视角 | axe visible lower-left frame, forge, main street |
| 达拉然 | floating-city panorama, portals, Kirin Tor street |
| 泰达希尔 / 达纳苏斯 | World Tree plaza, bridges, Temple of the Moon |
| 联盟勇士们 围攻熔火之心 火焰领主 | raid vs Ragnaros, nameplates included |
| 希尔瓦娜斯在冰封王座上，单挑巫妖王 | close-quarters duel on the Frozen Throne |

## License

MIT — see LICENSE.
