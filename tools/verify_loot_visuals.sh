#!/usr/bin/env bash
set -euo pipefail

loot_project_root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$loot_project_root"

godot --path . --rendering-method gl_compatibility \
	--script tools/render_loot_socket_review.gd

mkdir -p artifacts/loot_socket_review_sheets

ffmpeg -y -loglevel error -pattern_type glob \
	-i 'artifacts/loot_socket_review/*fridge*.png' \
	-vf 'scale=480:360,tile=2x1' -frames:v 1 \
	artifacts/loot_socket_review_sheets/fridge.png

ffmpeg -y -loglevel error -pattern_type glob \
	-i 'artifacts/loot_socket_review/*drawer*.png' \
	-vf 'scale=320:240,tile=6x3' -frames:v 1 \
	artifacts/loot_socket_review_sheets/drawers.png

ffmpeg -y -loglevel error -pattern_type glob \
	-i 'artifacts/loot_socket_review/*cabinet*.png' \
	-vf 'scale=320:240,tile=4x2' -frames:v 1 \
	artifacts/loot_socket_review_sheets/cabinets.png

ffmpeg -y -loglevel error -pattern_type glob \
	-i 'artifacts/loot_socket_review/*wardrobe*.png' \
	-vf 'scale=480:360,tile=3x1' -frames:v 1 \
	artifacts/loot_socket_review_sheets/wardrobes.png

ffmpeg -y -loglevel error -pattern_type glob \
	-i 'artifacts/loot_socket_review/*shelf*.png' \
	-vf 'scale=240:180,tile=5x4' -frames:v 1 \
	artifacts/loot_socket_review_sheets/shelves.png

ffmpeg -y -loglevel error -pattern_type glob \
	-i 'artifacts/loot_socket_review/*table*.png' \
	-vf 'scale=320:240,tile=6x3' -frames:v 1 \
	artifacts/loot_socket_review_sheets/tables.png

godot --headless --path . --script tools/verify_house_loot_sockets.gd

echo "Visual proof: $loot_project_root/artifacts/loot_socket_review_sheets"
echo "Detailed views: $loot_project_root/artifacts/loot_socket_review"
