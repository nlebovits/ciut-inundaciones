#!/bin/bash
set -ex

# Check if file path and smoothing passes arguments are provided
if [ $# -lt 2 ]; then
    echo "Usage: $0 <path_to_geojson_file> <smoothing_passes>"
    echo "Example: $0 data/el_gato_alta.geojson 3"
    exit 1
fi

# Configuration - PROPERLY HANDLED SPACES IN PATH
INPUT_FILE="$(realpath "$1")"
INPUT_BASENAME=$(basename "$INPUT_FILE" .geojson)
OUTPUT_DIR="../data/smoothing_tests"
FINAL_DIR="$OUTPUT_DIR/${INPUT_BASENAME}_smooth_2.5m_buffer"
SMOOTHING_PASSES="$2"

# Check if input file exists
if [ ! -f "$INPUT_FILE" ]; then
    echo "Error: Input file '$INPUT_FILE' does not exist"
    exit 1
fi

# Check if smoothing passes is a valid number
if ! [[ "$SMOOTHING_PASSES" =~ ^[0-9]+$ ]]; then
    echo "Error: Smoothing passes must be a positive integer."
    exit 1
fi

echo "Processing: $INPUT_FILE"
echo "Output directory: $FINAL_DIR"
echo "Smoothing passes: $SMOOTHING_PASSES"

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

# Step 1: Clean and Snap the Polygons before Smoothing
echo "Cleaning and snapping polygons before smoothing..."
v.clean input=raw output=cleaned_polygons tool=rmdupl,rmdangle,rmbridge,rmarea --overwrite

# Snap vertices to avoid misalignment and precision issues (Threshold: 0.1)
v.clean input=cleaned_polygons output=cleaned_polygons_snapped tool=snap threshold=0.1 --overwrite

# Check for validity of cleaned and snapped polygons
v.info -c cleaned_polygons_snapped

# Pre-smoothing with Douglas to eliminate stair-stepping
echo "Pre-smoothing with Douglas..."
v.generalize input=cleaned_polygons_snapped output=douglas_pre \
    method=douglas \
    threshold=1.0 \
    --overwrite

# Step 2: Apply smoothing passes dynamically
current_map="douglas_pre"
for i in \$(seq 1 $SMOOTHING_PASSES); do
    echo "Pass \$i: Smoothing..."
    output_map="smooth_pass\$i"
    v.generalize input=\$current_map output=\$output_map \
        method=chaiken \
        iterations=2 \
        threshold=5 \
        --overwrite
    current_map=\$output_map
done

# Copy attributes from original to final smoothed version
echo "Copying attributes..."
v.db.connect map=\$current_map table=raw --overwrite

# Apply permanent 2.5m buffer
echo "Applying permanent 2.5m buffer..."
v.buffer input=\$current_map output=smooth_buffered_final distance=2.5 --overwrite

# Copy attributes after buffer
v.db.connect map=smooth_buffered_final table=raw --overwrite

# Clean version (remove small artifacts)
echo "Cleaning result..."
v.clean input=smooth_buffered_final output=smooth_buffer_clean \
    tool=rmarea \
    threshold=10 \
    --overwrite

# Copy attributes after cleaning
v.db.connect map=smooth_buffer_clean table=raw --overwrite

# Export final result
echo "Exporting final result..."
v.out.ogr input=smooth_buffer_clean \
    output="$FINAL_DIR/${INPUT_BASENAME}_smooth_2.5m_buffer_clean.geojson" \
    format=GeoJSON \
    --overwrite

# Export intermediate results for comparison
echo "Exporting intermediate results for comparison..."
for i in \$(seq 1 $SMOOTHING_PASSES); do
    v.out.ogr input="smooth_pass\$i" \
        output="$FINAL_DIR/${INPUT_BASENAME}_pass\$i.geojson" \
        format=GeoJSON \
        --overwrite
done

EOF

echo ""
echo "=== SMOOTH + 2.5M BUFFER COMPLETE ==="
echo "Final file created: $FINAL_DIR/${INPUT_BASENAME}_smooth_2.5m_buffer_clean.geojson"
echo ""
echo "Intermediate files for comparison:"
for i in $(seq 1 $SMOOTHING_PASSES); do
    echo "  - Pass $i: $FINAL_DIR/${INPUT_BASENAME}_pass$i.geojson"
done
echo ""
ls -lh "$FINAL_DIR"/*.geojson