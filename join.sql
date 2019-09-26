ALTER TABLE geogitter
ADD COLUMN "einwohner" integer;

UPDATE geogitter a
SET einwohner = b.einwohner
FROM zensusdata b
WHERE a.id = b.gitter_id_100m;