#!/bin/bash

###################################################################################################
# script to create 100m raster cells of Zensus 2011 data using the BKG 100m geogitter
# required: postgres db, psql, shp2pgsql, GrassGIS (e.g. 7.6)
# author: Hannes Blitza, blitza@terrestris.de
###################################################################################################

#zensus2011 datasource "Bevölkerung im 100 Meter-Gitter"
#https://www.zensus2011.de/SharedDocs/Downloads/DE/Pressemitteilung/DemografischeGrunddaten/csv_Bevoelkerung_100m_Gitter.zip?__blob=publicationFile&v=3

#download and unzip csv
zensus='https://www.zensus2011.de/SharedDocs/Downloads/DE/Pressemitteilung/DemografischeGrunddaten/csv_Bevoelkerung_100m_Gitter.zip?__blob=publicationFile&v=3'
TMPFILE='zensus.zip'
wget $zensus -O $TMPFILE
unzip zensus.zip
# first row to lowercase
sed -i '1s/.*/\L&/' Zensus_Bevoelkerung_100m-Gitter.csv

#rm zensus.zip

#download and unzip geogitter100m LAEA from BKG
geogitter='https://daten.gdz.bkg.bund.de/produkte/sonstige/geogitter/aktuell/DE_Grid_ETRS89-LAEA_100m.shape.zip'
TMPFILE=geogitter.zip
wget $geogitter -O $TMPFILE
mkdir geogitter_shp_LAEA
unzip geogitter.zip -d geogitter_shp_LAEA

# create postgres table for zensus data
sudo -u postgres psql -d postgres -c 'CREATE TABLE zensusdata (gitter_id_100m text,x_mp_100m integer,y_mp_100m integer,einwohner integer);'
sudo -u postgres psql
# inside psql command prompt
# Install PostGIS Extension if necessary
 CREATE EXTENSION POTSGIS;
\copy zensusdata FROM 'Zensus_Bevoelkerung_100m-Gitter.csv' DELIMITER ';' csv header;
\q

# create table for geogitter100m and fill it via shp2pgsql
# create pgpass file to avoid password promt
# takes a while
shp2pgsql -c -D -s 3035 -I "geogitter_shp_LAEA/100kmN26E43_DE_Grid_ETRS89-LAEA_100m.shp" public.geogitter | psql -h localhost -d postgres -U postgres
for f in geogitter_shp_LAEA/*.shp
    do shp2pgsql -a -D -s 3035 -I $f public.geogitter | psql -h localhost -d postgres -U postgres
done

# perform attribute join
sudo -u postgres psql -f "join.sql";

# grass
# create location
grass76 -c epsg:3035 -e ~/grassdata/3035_zensus/
grass76 ~/grassdata/3035_zensus/PERMANENT/
db.connect driver=pg database=postgres
# saves password to file
db.login user=postgres password=*** host=localhost #port=5432
# link postgres layer to grass
v.external input="PG:host=localhost user=postgres dbname=postgres layer=geogitter"
# set region to layer
g.region vector=gegitter
# rasterize
v.to.rast input=geogitter type=area output=zensusraster use=attr attribute_column=einwohner where="einwohner > 20" memory=4000 --verbose
# export as GeoTiff
r.out.gdal -m -v input=zensusraster output=zensusraster.tif format=GTiff createopt="COMPRESS=LZW"
