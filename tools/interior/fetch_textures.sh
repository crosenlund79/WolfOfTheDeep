#!/bin/sh
# CC0 texture maps and crew base meshes used by control_room.py (sources recorded in docs/CONTROL_ROOM_PILOT.md).
set -e
OUT="${1:-./tex}"
mkdir -p "$OUT" && cd "$OUT"
for m in nor_gl_2k.jpg rough_2k.jpg; do
  curl -sSfL -o "metal_plate_$m" "https://dl.polyhaven.org/file/ph-assets/Textures/jpg/2k/metal_plate/metal_plate_$m"
done
for a in Rubber004 Leather037; do
  curl -sSfL -o "$a.zip" "https://ambientcg.com/get?file=${a}_1K-JPG.zip"
  mkdir -p "$a" && (cd "$a" && python3 -c "import zipfile; zipfile.ZipFile('../$a.zip').extractall('.')")
done
# Human Base Meshes bundle (Blender Foundation / Blender Studio, CC0): realistic bodies for the crew.
curl -sSfL -o hbm.zip "https://download.blender.org/demo/asset-bundles/human-base-meshes/human-base-meshes-bundle-v1.4.1.zip"
python3 -c "import zipfile; zipfile.ZipFile('hbm.zip').extractall('.')"
echo "textures in $OUT; crew bundle: $OUT/human-base-meshes-bundle-v1.4.1/human_base_meshes_bundle.blend"
