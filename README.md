# ciut-inundaciones

Limpieza y procesamiento de salidas del modelo FLO-2D para evaluación de riesgo de inundación en La Plata, Argentina.

## Descripción

Este repositorio contiene código para vectorizar y suavizar efectivamente las salidas de un modelo FLO-2D utilizado para evaluar el riesgo de inundación en La Plata, Argentina. Los datos originales fueron creados con DEMs derivados de satélite de resolución y calidad mixta. Los datos resultantes resultaron difíciles de "suavizar" limpiamente según lo solicitado por la UNLP para su uso en la designación de zonas de riesgo de inundación en el código municipal. Aquí utilizo el suavizado Chaiken de GRASS GIS para lograr resultados satisfactorios.

## Metodología de procesamiento

Los datos originales de riesgo de inundación fueron creados por la Facultad de Ingeniería Hídrica de la UNLP y proporcionados por el CIUT. Los detalles sobre cómo fueron creados están disponibles en el [Plan de Reducción del Riesgo de Inundaciones en la región de La Plata](https://sedici.unlp.edu.ar/handle/10915/165109).

Los datos originales del modelo FLO-2D fueron proporcionados en formato vectorial. Aunque esto parece conveniente, el formato vectorial es en realidad más difícil de suavizar porque carece de las relaciones espaciales implícitas entre píxeles que proporcionan los rásters. Por lo tanto, todo fue convertido de vuelta a ráster para que el suavizado funcionara correctamente.

El primer paso fue convertir los datos vectoriales proporcionados de vuelta a formato ráster. Se filtró la categoría "Muy Baja/Nula" ya que está implícitamente definida como todas las áreas donde las otras tres categorías no están presentes. Esto redujo significativamente los costos de procesamiento ya que Muy Baja/Nula es la clase más grande y estaba ralentizando todo el proceso.

Luego se creó un ráster objetivo con resolución de 2.5m en lugar de los 10m originales. La misma cobertura espacial, solo que con mayor resolución. Esto permitió agregar ruido aleatorio a los bordes—solo 2.5m de variación, no 10m—para crear límites más naturales y fluidos en lugar de bordes blocosos típicos de rásters. Esto es algo arbitrario y se hizo específicamente para propósitos de visualización, no para análisis espacial.

Después de eso se aplicó suavizado Chaiken usando GRASS GIS, que es un algoritmo de suavizado de polígonos. Se corrieron seis iteraciones, lo cual tomó bastante tiempo porque es computacionalmente costoso para áreas grandes. Los parámetros exactos surgieron de prueba y error, así que no son necesariamente óptimos pero funcionaron suficientemente bien para los propósitos del proyecto.

Finalmente, se convirtió todo a multi-polígonos por tipo de amenaza y se disolvieron las geometrías para crear una sola geometría por nivel de prioridad. Para las áreas superpuestas, se priorizaron los niveles de amenaza más altos—entonces si alto y medio se superponen, se clasificó como alto. También se creó una versión en EPSG:4326 para PMTiles.

El notebook de procesamiento crudo está disponible en `src/main.ipynb`. Para trabajo futuro, se recomienda usar [Smoothify](https://github.com/DPIRD-DMA/Smoothify) en lugar de GDAL/GRASS ya que es una biblioteca de Python diseñada específicamente para este tipo de suavizado de polígonos.

## Datos de salida

Los datos procesados están disponibles en el repositorio hermano con la interfaz de usuario: [ciut-inundaciones-mapeo/public/data](https://github.com/nlebovits/ciut-inundaciones-mapeo/tree/main/public/data)

## Configuración

Instala el repositorio usando `git clone`. Navega al directorio raíz e instala el entorno virtual y las dependencias usando `uv sync`. Una vez hecho esto, ejecuta `uv run pre-commit install` en el directorio raíz para configurar los hooks de precommit (configurados en `.pre-commit-config.yaml`).

