# wow-cinematic-video

A Muse skill for producing short cinematic AI videos of World of Warcraft
places and moments — city tours （暴风城 / 奥格瑞玛 / 达拉然 / 泰达希尔）,
boss fights （熔火之心）, and lore scenes （希尔瓦娜斯单挑巫妖王）.

**Pipeline:** 3 × 10s generated clips, chained for continuity → frame-by-frame
verification → crossfade assembly on a rented cloud VM (InstaBox) → lanczos
upscale to 4K → byte-verified delivery.

Born from six real productions in one night; the SKILL.md playbook includes
every operational lesson learned (snapshot-resume failures and fresh-call
recovery, tmpfiles rotating download links, catbox rejecting datacenter IPs,
InstaBox CLI timeout caps, the missing-segment slow-motion trick, and why you
must frame-check a "Teldrassil" prompt before it burns the tree down).

## Contents

- `SKILL.md` — the full playbook
- `scripts/assemble.sh` — parameterized ffmpeg assembly + 4K upscale
  (2–3 clips, crossfades, optional slowdown), tested end-to-end

## Usage

Install as a skill, then ask for a video, e.g.:

> 做一段达拉然的视频，30 秒，4K

Assembly script standalone:

```bash
scripts/assemble.sh out-4k.mp4 clip1.mp4 clip2.mp4 clip3.mp4
# env knobs: TARGET_W/TARGET_H, CRF, PRESET, SLOW, XFADE
```

## License

MIT
