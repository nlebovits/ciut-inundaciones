#!/bin/bash
set -ex

# Configuration: input file and output directory
INPUT_FILE="$1"
OUTPUT_DIR="../data/smoothing_diagnostic"
DIAGNOSTIC_DIR="$OUTPUT_DIR/$(basename "$INPUT_FILE" .geojson)_diagnostic"

mkdir -p "$DIAGNOSTIC_DIR"

echo "=== ANALYZING POLYGON SMOOTHING ==="
echo "Processing: $INPUT_FILE"

# GRASS setup
LOCATION="$HOME/grassdata/$(basename "$INPUT_FILE" .geojson)_diagnostic"
rm -rf "$LOCATION" 2>/dev/null || true
grass -c "$INPUT_FILE" "$LOCATION" -e

# Run GRASS operations
grass "$LOCATION/PERMANENT" --exec bash << EOF
set -ex

# Import vector data (polygons)
v.in.ogr input="$INPUT_FILE" output=raw snap=0.001 min_area=1 -w --overwrite

# Calculate Perimeter and Area
v.db.addcolumn map=raw 'columns=perimeter_m DOUBLE PRECISION, area_m2 DOUBLE PRECISION' --overwrite
v.to.db map=raw option=perimeter columns=perimeter_m units=meters --overwrite
v.to.db map=raw option=area columns=area_m2 units=meters --overwrite

# Convert polygons to lines (to analyze edges)
v.to.lines input=raw output=polygon_edges --overwrite

# Run smoothing on the polygons
v.generalize input=raw output=smooth_polygons method=chaiken threshold=0.5 --overwrite

# Convert smoothed polygons to lines
v.to.lines input=smooth_polygons output=smooth_edges --overwrite

# Export the before and after lines (edges) for inspection
v.out.ogr input=polygon_edges output="$DIAGNOSTIC_DIR/polygon_edges.geojson" format=GeoJSON --overwrite
v.out.ogr input=smooth_edges output="$DIAGNOSTIC_DIR/smooth_edges.geojson" format=GeoJSON --overwrite

# Create a map of angles between adjacent lines
# We will manually inspect the angles of the line segments by analyzing nodes and segments
v.to.points input=polygon_edges output=polygon_edge_points --overwrite
v.to.points input=smooth_edges output=smooth_edge_points --overwrite

# Use the points to create vector maps of adjacent line segments
v.connectivity input=polygon_edge_points output=polygon_segments --overwrite
v.connectivity input=smooth_edge_points output=smooth_segments --overwrite

# Export connectivity analysis for further examination
v.out.ogr input=polygon_segments output="$DIAGNOSTIC_DIR/polygon_segments.geojson" format=GeoJSON --overwrite
v.out.ogr input=smooth_segments output="$DIAGNOSTIC_DIR/smooth_segments.geojson" format=GeoJSON --overwrite

EOF

echo ""
echo "=== ANALYSIS COMPLETE ==="
echo "Edges before smoothing saved to: $DIAGNOSTIC_DIR/polygon_edges.geojson"
echo "Edges after smoothing saved to: $DIAGNOSTIC_DIR/smooth_edges.geojson"
echo "Segments analysis before smoothing saved to: $DIAGNOSTIC_DIR/polygon_segments.geojson"
echo "Segments analysis after smoothing saved to: $DIAGNOSTIC_DIR/smooth_segments.geojson"
echo ""
