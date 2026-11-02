#!/usr/bin/env python3
"""Find when each word is said, so effects can land on the right word.

usage: python words.py input.mp4 [out.json] -> prints "12.34  word" lines and saves input.words.json
                                                (in the current folder if the video's folder is read-only)
Uses faster-whisper (installed into the skill's .venv on first run). On a Mac with mlx-whisper installed, that is used instead.
"""
import json, os, subprocess, sys

src = sys.argv[1]
out = sys.argv[2] if len(sys.argv) > 2 else os.path.splitext(src)[0] + '.words.json'
if len(sys.argv) <= 2 and not os.access(os.path.dirname(os.path.abspath(src)), os.W_OK):
    out = os.path.splitext(os.path.basename(src))[0] + '.words.json'
words = []
try:
    import mlx_whisper
    r = mlx_whisper.transcribe(src, path_or_hf_repo='mlx-community/whisper-large-v3-turbo', word_timestamps=True)
    words = [{'w': w['word'].strip(), 's': round(w['start'], 2), 'e': round(w['end'], 2)} for seg in r['segments'] for w in seg.get('words', [])]
except ImportError:
    try:
        from faster_whisper import WhisperModel
    except ImportError:
        print('Installing the transcriber (one time, about 1 minute)...', flush=True)
        r = subprocess.run([sys.executable, '-m', 'pip', 'install', '-q', 'faster-whisper'])
        if r.returncode: r = subprocess.run([sys.executable, '-m', 'pip', 'install', '-q', '--user', 'faster-whisper'])
        try:
            from faster_whisper import WhisperModel
        except ImportError:
            sys.exit('NO_TRANSCRIBER: could not install faster-whisper (no internet?). Ask the user for the timings instead.')
    try:
        model = WhisperModel(os.environ.get('WHISPER_MODEL', 'base'), device='cpu', compute_type='int8')
    except Exception as e:
        sys.exit(f'NO_TRANSCRIBER: could not download the speech model ({e.__class__.__name__}). Ask the user for the timings instead.')
    segs, _ = model.transcribe(src, word_timestamps=True, vad_filter=True)
    words = [{'w': w.word.strip(), 's': round(w.start, 2), 'e': round(w.end, 2)} for s in segs for w in (s.words or [])]

json.dump(words, open(out, 'w'), indent=0)
for w in words: print(f"{w['s']:7.2f}  {w['w']}")
print(f'\nSaved {len(words)} words to {out}')
