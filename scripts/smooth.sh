#!/bin/bash
set -ex

# Configuration - PROPERLY HANDLED SPACES IN PATH
INPUT_FILE="$(pwd)/data/la_plata_pelig_2023.geojson"
OUTPUT_DIR="data/smoothing_tests"
FINAL_DIR="$OUTPUT_DIR/light_smooth_2m_buffer"

# Create directories with existence check
mkdir -p "$OUTPUT_DIR"
if [ ! -d "$FINAL_DIR" ]; then
    mkdir -p "$FINAL_DIR"
    echo "Created final directory: $FINAL_DIR"
else
    echo "Final directory already exists: $FINAL_DIR"
fi

# Initialize GRASS
LOCATION="$HOME/grassdata/la_plata_light_smooth"
rm -rf "$LOCATION" 2>/dev/null || true
grass -c "$INPUT_FILE" "$LOCATION" -e

# Process in GRASS
grass "$LOCATION/PERMANENT" --exec bash << EOF
set -ex

# Import GeoJSON with proper path handling
v.in.ogr input="$INPUT_FILE" output=raw \
    snap=0.01 \
    min_area=1 \
    -w \
    --overwrite

# Step 1: Light smoothing (2 iterations, threshold 8)
echo "Step 1: Applying light smoothing..."
v.generalize input=raw output=light_smooth \
    method=chaiken \
    iterations=2 \
    threshold=8 \
    --overwrite

# Step 2: Dissolve by PELIGROSID first to maintain proper grouping
echo "Step 2: Dissolving by PELIGROSID..."
v.dissolve input=light_smooth output=light_dissolved column=peligrosid --overwrite

# Step 3: Buffer operations on the dissolved data (2m buffer)
echo "Step 3: Buffering dissolved data with 2m buffer..."
v.buffer input=light_dissolved output=light_buffered_out distance=2.0 --overwrite
v.buffer input=light_buffered_out output=light_smooth_buffer_final distance=-2.0 --overwrite

# Step 3: Clean version (remove small artifacts)
echo "Step 3: Cleaning result..."
v.clean input=light_smooth_buffer_final output=light_smooth_buffer_clean \
    tool=rmarea \
    threshold=10 \
    --overwrite

# Export final result only
echo "Step 4: Exporting final result..."

# Export only the cleaned version
v.out.ogr input=light_smooth_buffer_clean \
    output="$FINAL_DIR/light_smooth_2m_buffer_clean.geojson" \
    format=GeoJSON \
    --overwrite

EOF

echo ""
echo "=== LIGHT SMOOTH + 2M BUFFER COMPLETE ==="
echo "Final file created: $FINAL_DIR/light_smooth_2m_buffer_clean.geojson"
echo ""
ls -lh "$FINAL_DIR"/*.geojson