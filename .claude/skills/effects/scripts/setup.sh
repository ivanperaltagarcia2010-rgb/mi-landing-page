#!/usr/bin/env bash
# One-time setup for the effects skill. Safe to run again.
# Works in two places:
#   - Claude Code on a computer: makes a .venv inside the skill folder.
#   - Claude.ai chat (skill folder is read-only): uses the sandbox's own python, installing only what is missing.
# On success the last line is:  READY <path-to-python>   -> use that python for every script.
cd "$(dirname "$0")/.."
SKILL="$(pwd)"

ok() { "$1" -c "import numpy, PIL, cv2; assert hasattr(cv2.dnn, 'readNetFromTFLite') and hasattr(cv2, 'FaceDetectorYN')" >/dev/null 2>&1; }
has_ffmpeg() { command -v ffmpeg >/dev/null 2>&1 || "$1" -c "import imageio_ffmpeg; imageio_ffmpeg.get_ffmpeg_exe()" >/dev/null 2>&1; }
done_with() { if has_ffmpeg "$1"; then echo "READY $1"; exit 0; fi; }

# 1. Already set up?
for p in "$SKILL/.venv/bin/python" "$SKILL/.venv/Scripts/python.exe" "$HOME/.cache/claude-effects-venv/bin/python"; do
  [ -x "$p" ] && ok "$p" && done_with "$p"
done

# 2. Find a python 3.10+
PY=""
for v in python3.12 python3.11 python3.13 python3.10 python3 python; do
  if command -v "$v" >/dev/null 2>&1 && "$v" -c 'import sys; sys.exit(0 if sys.version_info[:2] >= (3, 10) else 1)' 2>/dev/null; then PY="$(command -v "$v")"; break; fi
done
if [ -z "$PY" ]; then echo "NEED_PYTHON: install Python 3.10 or newer (python.org/downloads), then run this again"; exit 1; fi

pipi() {  # pip install into a given python, trying the variants different sandboxes accept
  "$1" -m pip install -q "${@:2}" 2>/dev/null || "$1" -m pip install -q --user "${@:2}" 2>/dev/null || "$1" -m pip install -q --break-system-packages "${@:2}"
}

# 3. Claude.ai sandbox / a python that already has everything: use it directly
if ok "$PY"; then
  done_with "$PY"
  pipi "$PY" imageio-ffmpeg && done_with "$PY"
fi

# 4. Make a venv (inside the skill folder if writable, otherwise in ~/.cache)
VENV="$SKILL/.venv"; [ -w "$SKILL" ] || VENV="$HOME/.cache/claude-effects-venv"
if "$PY" -m venv "$VENV" 2>/dev/null; then
  VP="$VENV/bin/python"; [ -x "$VP" ] || VP="$VENV/Scripts/python.exe"
  "$VP" -m pip install -q --upgrade pip >/dev/null 2>&1
  "$VP" -m pip install -q -r requirements.txt
  command -v ffmpeg >/dev/null 2>&1 || "$VP" -m pip install -q imageio-ffmpeg
  ok "$VP" && done_with "$VP"
fi

# 5. Last resort: install straight into the system python
pipi "$PY" -r requirements.txt
command -v ffmpeg >/dev/null 2>&1 || pipi "$PY" imageio-ffmpeg
ok "$PY" && done_with "$PY"

if ! has_ffmpeg "$PY"; then echo "NEED_FFMPEG: install ffmpeg (Mac: brew install ffmpeg, Windows: winget install ffmpeg)"; exit 1; fi
echo "SETUP_FAILED: could not install numpy, pillow and opencv (no internet access to PyPI?)"; exit 1
