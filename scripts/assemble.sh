#!/usr/bin/env bash
# assemble.sh — stitch 2-3 AI-generated clips into one video with crossfades,
# then upscale to 4K (lanczos + mild sharpening) and encode with libx264.
#
# Usage:
#   assemble.sh OUTPUT.mp4 CLIP1 CLIP2 [CLIP3]
#
# Environment knobs:
#   TARGET_W / TARGET_H   output size        (default 3840x2160; use 1280 720 to skip upscale)
#   CRF                   x264 quality       (default 22)
#   PRESET                x264 preset        (default fast)
#   SLOW                  slowdown factor    (default 1; 0.75 stretches runtime by ~33%,
#                          useful when a planned segment is missing)
#   XFADE                 crossfade seconds  (default 0.5)
#
# Requires: ffmpeg, ffprobe (ffmpeg >= 4.4 for xfade).
set -euo pipefail

OUT="${1:?usage: assemble.sh OUTPUT CLIP1 CLIP2 [CLIP3]}"; shift
CLIPS=("$@")
N=${#CLIPS[@]}
if [ "$N" -lt 2 ] || [ "$N" -gt 3 ]; then
  echo "need 2 or 3 clips, got $N" >&2; exit 1
fi

TARGET_W="${TARGET_W:-3840}"; TARGET_H="${TARGET_H:-2160}"
CRF="${CRF:-22}"; PRESET="${PRESET:-fast}"
SLOW="${SLOW:-1}"; XFADE="${XFADE:-0.5}"
MAXRATE="${MAXRATE:-28M}"; BUFSIZE="${BUFSIZE:-56M}"

dur() { ffprobe -v error -show_entries format=duration -of csv=p=0 "$1"; }
fma() { awk -v a="$1" -v b="$2" -v op="$3" 'BEGIN{ if(op=="+") r=a+b; else if(op=="-") r=a-b; else if(op=="*") r=a*b; else r=a/b; printf "%.3f", r }'; }

# Per-input normalized labels + durations (after slowdown).
FC=""
INPUTS=()
DURS=()
for i in "${!CLIPS[@]}"; do
  INPUTS+=(-i "${CLIPS[$i]}")
  d=$(dur "${CLIPS[$i]}")
  DURS+=("$(fma "$d" "$SLOW" "/")")
  vpre="[$i:v]"
  if [ "$SLOW" != "1" ]; then
    FC+="[$i:v]setpts=PTS/$SLOW,fps=24,scale=1280:720:flags=lanczos,setsar=1,format=yuv420p[v$i];"
    FC+="[$i:a]atempo=$SLOW[a$i];"
  else
    FC+="[$i:v]scale=1280:720:flags=lanczos,setsar=1,fps=24,format=yuv420p[v$i];"
    FC+="[$i:a]anull[a$i];"
  fi
done

# Crossfade chains (video offsets are cumulative; audio uses plain acrossfade).
VLAST="v0"; ALAST="a0"; TOTAL="${DURS[0]}"
for k in $(seq 1 $((N-1))); do
  OFF=$(fma "$TOTAL" "$XFADE" "-")
  FC+="[$VLAST][v$k]xfade=transition=fade:duration=$XFADE:offset=$OFF[xv$k];"
  FC+="[$ALAST][a$k]acrossfade=d=$XFADE[xa$k];"
  VLAST="xv$k"; ALAST="xa$k"
  TOTAL=$(fma "$(fma "$TOTAL" "${DURS[$k]}" "+")" "$XFADE" "-")
done
FC+="[$VLAST]scale=$TARGET_W:$TARGET_H:flags=lanczos,unsharp=5:5:0.7:5:5:0.0,format=yuv420p[vout];"
FC+="[$ALAST]anull[aout]"

echo "clips: $N  expected runtime: ~${TOTAL}s  target: ${TARGET_W}x${TARGET_H} crf=$CRF preset=$PRESET slow=$SLOW" >&2
ffmpeg -y -hide_banner "${INPUTS[@]}" -filter_complex "$FC" \
  -map "[vout]" -map "[aout]" \
  -c:v libx264 -preset "$PRESET" -crf "$CRF" -maxrate "$MAXRATE" -bufsize "$BUFSIZE" \
  -c:a aac -b:a 128k "$OUT"
