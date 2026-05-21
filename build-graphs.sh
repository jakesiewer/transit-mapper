#!/usr/bin/env bash
set -euo pipefail

# Build OTP graphs for individual regions.
# Usage:
#   ./build-graphs.sh              # build all regions
#   ./build-graphs.sh ireland      # build only ireland
#   ./build-graphs.sh catalonia    # build only catalonia

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
OTP_DATA="$SCRIPT_DIR/otp-data"
GRAPHS_DIR="$SCRIPT_DIR/graphs"

build_region() {
  local region="$1"
  local region_dir="$GRAPHS_DIR/$region"

  if [ ! -d "$region_dir" ]; then
    echo "ERROR: Region directory not found: $region_dir"
    exit 1
  fi

  if [ ! -f "$region_dir/build-config.json" ]; then
    echo "ERROR: No build-config.json in $region_dir"
    exit 1
  fi

  echo "=== Preparing $region ==="

  # Copy OSM files referenced in build-config.json into the region dir
  for osm_file in $(grep -oP '"source":\s*"\K[^"]+' "$region_dir/build-config.json" | grep '\.osm\.pbf'); do
    src="$OTP_DATA/$osm_file"
    if [ -f "$src" ]; then
      cp -v "$src" "$region_dir/"
    else
      echo "WARNING: OSM file not found: $src"
    fi
  done

  # Copy GTFS files
  for gtfs_file in $(grep -oP '"source":\s*"\K[^"]+' "$region_dir/build-config.json" | grep '\.gtfs'); do
    src="$OTP_DATA/$gtfs_file"
    if [ -f "$src" ]; then
      cp -v "$src" "$region_dir/"
    else
      echo "WARNING: GTFS file not found: $src"
    fi
  done

  echo "=== Building graph for $region ==="
  docker compose run --rm \
    -v "$region_dir:/var/opentripplanner/graphs/$region" \
    otp-graph-builder-service \
    --build "/var/opentripplanner/graphs/$region"

  echo "=== Done: $region ==="
}

# Determine which regions to build
if [ $# -gt 0 ]; then
  REGIONS=("$@")
else
  REGIONS=()
  for dir in "$GRAPHS_DIR"/*/; do
    region="$(basename "$dir")"
    REGIONS+=("$region")
  done
fi

for region in "${REGIONS[@]}"; do
  build_region "$region"
done

echo ""
echo "All requested graphs built. Available regions:"
for dir in "$GRAPHS_DIR"/*/; do
  region="$(basename "$dir")"
  if [ -f "$dir/graph.obj" ]; then
    echo "  ✓ $region"
  else
    echo "  ✗ $region (no graph.obj)"
  fi
done