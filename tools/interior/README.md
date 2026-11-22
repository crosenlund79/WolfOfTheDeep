# Interior plates (control room pilot)

Developer tools only. The game does not need any of this to run. The rendered plates are committed in `assets/interior/control_room/`.

## Regenerate

```bash
python3 -m venv /tmp/bvenv && /tmp/bvenv/bin/pip install bpy==5.3.0
sh tools/interior/fetch_textures.sh /tmp/tex
python3 tools/interior/make_screens.py /tmp/screens
/tmp/bvenv/bin/python tools/interior/control_room.py -- --out assets/interior/control_room \
    --tex /tmp/tex --screens /tmp/screens --quality final --views command,wide,sonar,nav --light normal,red
python3 tools/interior/compress_plates.py assets/interior/control_room
```

- **Preview:** `--quality preview` renders at 960×540 for quick checks. `--nomask` skips the occlusion masks.
- **Final quality:** 1920×1080 takes several minutes per plate on a 4-core CPU.
- **Outputs for each view:**
  - `<view>_normal.jpg` and `<view>_red.jpg`;
  - `<view>_maskA.png` and `<view>_maskB.png`, which mark where each live display is visible;
  - `views.json`, with the projected display grids, indicator lamps and station hotspots.

`.gdignore` in `tools/` keeps Godot from importing anything here.
