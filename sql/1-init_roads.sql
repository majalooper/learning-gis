/* rename geometry colum to 'geom' which is preferred for this project */
ALTER TABLE roads RENAME COLUMN wkb_geometry TO geom;

/* add realistic speed on roads */
ALTER TABLE roads ADD COLUMN speed INTEGER;
UPDATE roads
  SET speed = CASE
    WHEN fclass IN ('motorway') THEN 120
    WHEN fclass IN ('motorway_link') THEN 80
    WHEN fclass IN ('trunk') THEN 100
    WHEN fclass IN ('trunk_link') THEN 70
    WHEN fclass IN ('primary') THEN 80
    WHEN fclass IN ('primary_link') THEN 70
    WHEN fclass IN ('secondary') THEN 70
    WHEN fclass IN ('secondary_link') THEN 60
    WHEN fclass IN ('tertiary') THEN 55
    WHEN fclass IN ('tertiary_link') THEN 50
    WHEN fclass IN ('residential') THEN 45
    WHEN fclass IN ('living_street') THEN 25
    WHEN fclass IN ('service') THEN 20
    WHEN fclass IN ('unclassified') THEN 50
    WHEN fclass IN ('track', 'track_grade1', 'track_grade2', 'track_grade3') THEN 15
    ELSE 10
  END;

UPDATE roads SET speed = maxspeed WHERE maxspeed > 0 and maxspeed < speed;
