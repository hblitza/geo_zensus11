#!/bin/bash

###################################################################################################
# script to create 100m raster cells of Zensus 2011 data using the BKG 100m geogitter
# required: postgres db, psql, shp2pgsql, GrassGIS (e.g. 7.6)
# author: Hannes Blitza, blitza@terrestris.de
###################################################################################################

#zensus2011 datasource "Bevölkerung im 100 Meter-Gitter"
#https://www.zensus2011.de/SharedDocs/Downloads/DE/Pressemitteilung/DemografischeGrunddaten/csv_Bevoelkerung_100m_Gitter.zip?__blob=publicationFile&v=3

grass=grass78

#download and unzip csv
zensus='https://www.zensus2011.de/SharedDocs/Downloads/DE/Pressemitteilung/DemografischeGrunddaten/csv_Bevoelkerung_100m_Gitter.zip?__blob=publicationFile&v=3'
TMPFILE='zensus.zip'
wget -c $zensus -O $TMPFILE
unzip zensus.zip
# first row to lowercase
sed -i '1s/.*/\L&/' Zensus_Bevoelkerung_100m-Gitter.csv

rm zensus.zip

#download and unzip geogitter100m LAEA from BKG
geogitter='https://daten.gdz.bkg.bund.de/produkte/sonstige/geogitter/aktuell/DE_Grid_ETRS89-LAEA_100m.gpkg.zip'
TMPFILE=geogitter.zip
wget -c $geogitter -O $TMPFILE
unzip geogitter.zip -d .



# perform attribute join
sudo -u postgres psql -f "join.sql";

# grass
# create location
$grass -c epsg:3035 -e ~/grassdata/3035_zensus/
$grass ~/grassdata/3035_zensus/PERMANENT/
# link postgres layer to grass
# limited to 10000 polygons using where clause
v.external input=/home/hannes/geodata/geogitter/DE_Grid_ETRS89-LAEA_100m.gpkg layer=de_grid_laea_100m output=geogitter2 where="id LIKE '%N307%E411%'"

# set region to layer
g.region vector=gegitter -p
# rasterize
v.to.rast input=geogitter type=area output=zensusraster use=attr attribute_column=einwohner where="einwohner > 20" memory=4000 --verbose
# export as GeoTiff
r.out.gdal -m -v input=zensusraster output=zensusraster.tif format=GTiff createopt="COMPRESS=LZW" overviews=4
