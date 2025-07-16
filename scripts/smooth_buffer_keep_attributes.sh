#!/bin/bash
set -ex

# Check if file path argument is provided
if [ $# -eq 0 ]; then
    echo "Usage: $0 <path_to_geojson_file>"
    echo "Example: $0 data/el_gato_alta.geojson"
    exit 1
fi

# Configuration - PROPERLY HANDLED SPACES IN PATH
INPUT_FILE="$(realpath "$1")"
INPUT_BASENAME=$(basename "$INPUT_FILE" .geojson)
OUTPUT_DIR="../data/smoothing_tests"
FINAL_DIR="$OUTPUT_DIR/${INPUT_BASENAME}_smooth_2.5m_buffer"

# Check if input file exists
if [ ! -f "$INPUT_FILE" ]; then
    echo "Error: Input file '$INPUT_FILE' does not exist"
    exit 1
fi

echo "Processing: $INPUT_FILE"
echo "Output directory: $FINAL_DIR"

# Create directories with existence check
mkdir -p "$OUTPUT_DIR"
if [ ! -d "$FINAL_DIR" ]; then
    mkdir -p "$FINAL_DIR"
    echo "Created final directory: $FINAL_DIR"
else
    echo "Final directory already exists: $FINAL_DIR"
fi

# Initialize GRASS
LOCATION="$HOME/grassdata/${INPUT_BASENAME}_smooth"
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

# Check what attributes we have
echo "Checking attributes in imported data..."
v.info -c raw

# Step 1: Light smoothing (2 iterations, threshold 8)
echo "Step 1: Applying light smoothing..."
v.generalize input=raw output=light_smooth \
    method=chaiken \
    iterations=2 \
    threshold=8 \
    --overwrite

# Copy attributes from original to smoothed
echo "Copying attributes..."
v.db.connect map=light_smooth table=raw --overwrite

# Step 2: Apply permanent 2.5m buffer (no negative buffer)
echo "Step 2: Applying permanent 2.5m buffer..."
v.buffer input=light_smooth output=light_buffered_final distance=2.5 --overwrite
# Copy attributes after buffer
v.db.connect map=light_buffered_final table=raw --overwrite

# Step 3: Clean version (remove small artifacts)
echo "Step 3: Cleaning result..."
v.clean input=light_buffered_final output=light_smooth_buffer_clean \
    tool=rmarea \
    threshold=10 \
    --overwrite

# Copy attributes after cleaning
v.db.connect map=light_smooth_buffer_clean table=raw --overwrite

# Verify attributes before export
echo "Checking final attributes..."
v.info -c light_smooth_buffer_clean

# Export final result
echo "Step 4: Exporting final result..."
v.out.ogr input=light_smooth_buffer_clean \
    output="$FINAL_DIR/${INPUT_BASENAME}_smooth_2.5m_buffer_clean.geojson" \
    format=GeoJSON \
    --overwrite
EOF

echo ""
echo "=== SMOOTH + 2.5M BUFFER COMPLETE ==="
echo "Final file created: $FINAL_DIR/${INPUT_BASENAME}_smooth_2.5m_buffer_clean.geojson"
echo ""
ls -lh "$FINAL_DIR"/*.geojson