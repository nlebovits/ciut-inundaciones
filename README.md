# ciut-inundaciones
Cleaning FLO-2D outputs using FABDEM-derived terrain data

This repo contains code to attempt to effectively vectorize outputs from a FLO-2D model used to assess flood hazard in La Plata, Argentina. The original outputs were created with satellite-derived DEMs of mixed resolution and quality. The resulting data proved difficult to cleanly "smooth" as requested by the UNLP for use in designating flood hazard zones in the municipal code. Here, I attempt to established a baseline smoothing approach using GRASS GIS (stored in .sh scripts) and a more sophisticated approach using Fathom's 30m resolution FABDEM product and impervious surface cover.

## Setup
Install the repo using `git clone`. Navigate to the root directory and install the virutal environment and dependencies using `uv sync`. Run the main script with `uv run main.py`

### Repo structure
Currently, the draft processing is carried out in `main.ipynb`. We use `pystac-client` and `rioxarray` to retrieve FABDEM data efficeintly and then `whitebox` for terrain modeling. Data are stored locally in the `data` subdirectory. While we are currently testing on Cuenca el Gato, the goal is to eventually scale the analysis to the entire Partido de La Plata, at which point we will switch to using `main.py` to run the full processing script.

## Data sources
The original flood hazard data were created by the Facultad de Ingeniería Hídrica at the UNLP and provided to me by the CIUT. Details on how they were created are available in the [Plan de Reducción del Riesgo de Inundaciones en la región de La Plata](https://sedici.unlp.edu.ar/handle/10915/165109).

FABDEM is a 30-meter resolution satellite-derived DEM that uses machine learning to correct for the presence of trees and buildings and produce something approximating a LiDAR-derived DEM. It was developed by Fathom specifically for the purpose of developing global flood hazard models. More information is available here.

Impervious surface cover at 30-meter resolution is available from various datasets; I am considering using [GISA](https://gee-community-catalog.org/projects/gisa/) for this project, although I will need to look into it more.

## Roadmap
1. Create a basic, smoothed version of the FLO-2D outputs for Cuenca El Gato using smoothing algorithms available in GRASS GIS ✅

2. Use FABDEM and Whitebox to develop local terrain models (slope, hillshade, TRI, TWI) ☐

3. Evaluate the success of a DEM-corrected smoothing of the original polygons ☐

4. Explore incorporating impervious surface cover into the model ☐

5. Compare all outputs, decide on a preferred version ☐

6. Scale to the entire Partido de La Plata ☐