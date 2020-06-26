ALTER TABLE de_grid_laea_100m ADD einwohner integer;

UPDATE de_grid_laea_100m
SET
    einwohner = (SELECT zensusdata.einwohner
                                FROM zensusdata
                                WHERE zensusdata.gitter_id_100m = de_grid_laea_100m.id )
WHERE
    EXISTS (
       SELECT *
       FROM zensusdata
       WHERE zensusdata.gitter_id_100m = de_grid_laea_100m.id
   )

