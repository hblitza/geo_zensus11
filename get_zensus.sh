#!/bin/bash

###################################################################################################
# script to create 100m raster cells of Zensus 2011 data using the BKG 100m geogitter (GPKG)
# required: gdal, awk, sqlite3 (cmd tools), GrassGIS (e.g. 7.8)
# author: Hannes Blitza, blitza@terrestris.de
###################################################################################################

grass=grass78
cwd=$(pwd)

# #download and unzip csv
zensus='https://www.zensus2011.de/SharedDocs/Downloads/DE/Pressemitteilung/DemografischeGrunddaten/csv_Bevoelkerung_100m_Gitter.zip?__blob=publicationFile&v=3'
TMPFILE='zensus.zip'
wget -c $zensus -O $TMPFILE
unzip zensus.zip
# first row to lowercase
sed -i '1s/.*/\L&/' Zensus_Bevoelkerung_100m-Gitter.csv

rm zensus.zip

# extract entries for the grid N307E411 (Bonn) (10000 rows)
awk -F ";" '$1 ~ /N307/' Zensus_Bevoelkerung_100m-Gitter.csv | awk -F ";" '$1 ~ /E411/' > zensus_subset_bonn.csv

# download and unzip geogitter100m LAEA from BKG
geogitter='https://daten.gdz.bkg.bund.de/produkte/sonstige/geogitter/aktuell/DE_Grid_ETRS89-LAEA_100m.gpkg.zip'
TMPFILE=geogitter.zip
wget -c $geogitter -O $TMPFILE
unzip geogitter.zip -d .
rm geogitter.zip

# create new gpkg with filtered features
ogr2ogr \
    where id LIKE '%N307%E411%' \
    -f geogitter_subset \
    DE_Grid_ETRS89-LAEA_100m.gpkg

# import csv to gpkg using sqlite3 https://sqlite.org/cli.html
sqlite3
# in sqlite 3
.open geogitter_subset
.separator ";"
.import zensus_subset_Bonn.csv zensusdata
.quit

# perform table join
ogrinfo geogitter_subset.gpkg -sql @join.sql

# grass
# create location
$grass -c epsg:3035 -e ~/grassdata/3035_zensus/
$grass ~/grassdata/3035_zensus/PERMANENT/
# link postgres layer to grass
v.external input=$pwd/geogitter_subset.gpkg layer=de_grid_laea_100m output=geogitter_subset --overwrite
# set region to layer
g.region vector=gegitter_subset -p
# rasterize
v.to.rast input=geogitter_subset type=area output=zensusraster use=attr attribute_column=einwohner memory=4000 --verbose
# export as GeoTiff
r.out.gdal -m -v input=zensusraster output=zensusraster.tif format=GTiff createopt="COMPRESS=LZW" overviews=4
