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
FINAL_DIR="$OUTPUT_DIR/${INPUT_BASENAME}_multi_pass_smooth_2.5m_buffer"
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
LOCATION="$HOME/grassdata/${INPUT_BASENAME}_multi_pass_smooth"
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
# Multi-pass smoothing - run v.generalize multiple times in sequence
echo "Pass 1: First smoothing pass..."
v.generalize input=raw output=smooth_pass1 \
    method=chaiken \
    iterations=2 \
    threshold=8 \
    --overwrite

echo "Pass 2: Second smoothing pass..."
v.generalize input=smooth_pass1 output=smooth_pass2 \
    method=chaiken \
    iterations=2 \
    threshold=8 \
    --overwrite

echo "Pass 3: Third smoothing pass..."
v.generalize input=smooth_pass2 output=smooth_pass3 \
    method=chaiken \
    iterations=2 \
    threshold=8 \
    --overwrite

echo "Pass 4: Fourth smoothing pass..."
v.generalize input=smooth_pass3 output=multi_pass_smooth \
    method=chaiken \
    iterations=2 \
    threshold=8 \
    --overwrite

# Copy attributes from original to final smoothed version
echo "Copying attributes..."
v.db.connect map=multi_pass_smooth table=raw --overwrite

# Apply permanent 2.5m buffer
echo "Applying permanent 2.5m buffer..."
v.buffer input=multi_pass_smooth output=multi_pass_buffered_final distance=2.5 --overwrite

# Copy attributes after buffer
v.db.connect map=multi_pass_buffered_final table=raw --overwrite

# Clean version (remove small artifacts)
echo "Cleaning result..."
v.clean input=multi_pass_buffered_final output=multi_pass_smooth_buffer_clean \
    tool=rmarea \
    threshold=10 \
    --overwrite

# Copy attributes after cleaning
v.db.connect map=multi_pass_smooth_buffer_clean table=raw --overwrite

# Verify attributes before export
echo "Checking final attributes..."
v.info -c multi_pass_smooth_buffer_clean

# Export final result
echo "Exporting final result..."
v.out.ogr input=multi_pass_smooth_buffer_clean \
    output="$FINAL_DIR/${INPUT_BASENAME}_multi_pass_smooth_2.5m_buffer_clean.geojson" \
    format=GeoJSON \
    --overwrite

# Export intermediate results for comparison
echo "Exporting intermediate results for comparison..."
v.out.ogr input=smooth_pass1 \
    output="$FINAL_DIR/${INPUT_BASENAME}_pass1.geojson" \
    format=GeoJSON \
    --overwrite

v.out.ogr input=smooth_pass2 \
    output="$FINAL_DIR/${INPUT_BASENAME}_pass2.geojson" \
    format=GeoJSON \
    --overwrite

v.out.ogr input=smooth_pass3 \
    output="$FINAL_DIR/${INPUT_BASENAME}_pass3.geojson" \
    format=GeoJSON \
    --overwrite

v.out.ogr input=multi_pass_smooth \
    output="$FINAL_DIR/${INPUT_BASENAME}_pass4_final.geojson" \
    format=GeoJSON \
    --overwrite

EOF

echo ""
echo "=== MULTI-PASS SMOOTH + 2.5M BUFFER COMPLETE ==="
echo "Final file created: $FINAL_DIR/${INPUT_BASENAME}_multi_pass_smooth_2.5m_buffer_clean.geojson"
echo ""
echo "Intermediate files for comparison:"
echo "  - Pass 1: $FINAL_DIR/${INPUT_BASENAME}_pass1.geojson"
echo "  - Pass 2: $FINAL_DIR/${INPUT_BASENAME}_pass2.geojson"
echo "  - Pass 3: $FINAL_DIR/${INPUT_BASENAME}_pass3.geojson"
echo "  - Pass 4: $FINAL_DIR/${INPUT_BASENAME}_pass4_final.geojson"
echo ""
ls -lh "$FINAL_DIR"/*.geojson