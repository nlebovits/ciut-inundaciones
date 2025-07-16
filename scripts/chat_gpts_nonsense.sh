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
FINAL_DIR="$OUTPUT_DIR/${INPUT_BASENAME}_chaiken_smooth"

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

# Define the GRASS location based on input filename
LOCATION="$HOME/grassdata/${INPUT_BASENAME}_chaiken_smooth"

# If location doesn't exist, create a new one
if [ ! -d "$LOCATION" ]; then
    echo "Creating GRASS GIS project (location)..."
    grass -c "$INPUT_FILE" "$LOCATION" -e
else
    echo "Using existing GRASS GIS project (location): $LOCATION"
fi

# Start GRASS GIS session with the current location
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

# Clean topology: remove duplicates, dangles, small artifacts
v.clean input=raw output=cleaned_polygons tool=rmdupl,rmdangle,rmbridge,rmarea --overwrite

# Snap vertices to avoid misalignment and precision issues (Threshold: 0.01)
v.clean input=cleaned_polygons output=cleaned_polygons_snapped tool=snap threshold=0.01 --overwrite

# Step 2: Apply Chaiken smoothing
echo "Performing Chaiken Smoothing..."

# Run Chaiken smoothing (Threshold: 5, iterations: 2)
v.generalize input=cleaned_polygons_snapped output=chaiken_smooth \
    method=chaiken \
    iterations=2 \
    threshold=5 \
    --overwrite

# After smoothing, identify unmodified boundaries by comparing original and smoothed polygons
echo "Identifying unmodified boundaries..."

# Use v.overlay to find features in the original layer (cleaned_polygons_snapped) that are NOT modified in chaiken_smooth
# This will extract boundaries that did not change, i.e., boundaries that are still the same.
v.overlay ainput=cleaned_polygons_snapped binput=chaiken_smooth output=unmodified_boundaries operator=not --overwrite

# Export the unmodified boundaries to GeoJSON
echo "Exporting unmodified boundaries..."
v.out.ogr input=unmodified_boundaries output="../data/smoothing_tests/el_gato_baja_chaiken_smooth/el_gato_baja_unmodified_boundaries.geojson" format=GeoJSON --overwrite

# Step 3: Clean overlapping polygons and artifacts
echo "Cleaning overlapping polygons..."

# Apply some cleanup on the smooth polygons
v.clean input=chaiken_smooth output=cleaned_smooth tool=rmdupl,rmdangle,rmarea --overwrite

# Step 4: Buffer polygons to remove small artifacts
echo "Applying buffer to smooth polygons..."

v.buffer input=cleaned_smooth output=buffered_smooth distance=2.5 --overwrite

# Final cleaning of buffered polygons
echo "Cleaning buffered polygons..."

v.clean input=buffered_smooth output=final_cleaned tool=rmarea threshold=10 --overwrite

# Export final result
echo "Exporting final result..."
v.out.ogr input=final_cleaned output="$FINAL_DIR/${INPUT_BASENAME}_final.geojson" format=GeoJSON --overwrite

# Export intermediate results for comparison
echo "Exporting intermediate results..."
v.out.ogr input=chaiken_smooth output="$FINAL_DIR/${INPUT_BASENAME}_chaiken_smooth.geojson" format=GeoJSON --overwrite
v.out.ogr input=buffered_smooth output="$FINAL_DIR/${INPUT_BASENAME}_buffered_smooth.geojson" format=GeoJSON --overwrite

EOF

echo ""
echo "=== SMOOTHING COMPLETE ==="
echo "Final file created: $FINAL_DIR/${INPUT_BASENAME}_final.geojson"
echo ""
echo "Intermediate files for comparison:"
echo "  - Chaiken Smooth: $FINAL_DIR/${INPUT_BASENAME}_chaiken_smooth.geojson"
echo "  - Buffered Smooth: $FINAL_DIR/${INPUT_BASENAME}_buffered_smooth.geojson"
echo ""
ls -lh "$FINAL_DIR"/*.geojson
