/* add transition time in minuts (as cost) */

ALTER TABLE roads_split ADD COLUMN cost DOUBLE PRECISION;

UPDATE roads_split SET cost = (ST_Length(ST_Transform(geom, 25832)) / 1000) / speed * 60;


/* create routable network topology */

ALTER TABLE roads_split ADD COLUMN source bigint;
ALTER TABLE roads_split ADD COLUMN target bigint;

SELECT pgr_createTopology('roads_split', 0.00002, 'geom', 'id');

