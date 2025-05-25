/* extract road intersections */

DROP TABLE IF EXISTS road_intersections;
CREATE TABLE road_intersections AS
SELECT
  a.ogc_fid AS a_id,
  b.ogc_fid AS b_id,
  (ST_Dump(ST_Intersection(a.geom, b.geom))).geom AS intersection_geom
FROM
  roads a
  JOIN roads b ON a.ogc_fid < b.ogc_fid
WHERE
  ST_Intersects(a.geom, b.geom);

/* create point for each road at every intersection */

DROP TABLE IF EXISTS road_split_points;
CREATE TABLE road_split_points AS
SELECT
  id,
  ST_Collect((intersection_geom)::geometry(Point, 4326)) AS split_points
FROM (
  SELECT a_id AS id, intersection_geom
  FROM road_intersections
  WHERE GeometryType(intersection_geom) = 'POINT'
  UNION ALL
  SELECT b_id AS id, intersection_geom
  FROM road_intersections
  WHERE GeometryType(intersection_geom) = 'POINT'
) sub
GROUP BY id;

/* split roads at intersections */

DROP TABLE IF EXISTS roads_split;
CREATE TABLE roads_split AS
SELECT
  r.ogc_fid AS road_id,
  r.layer,
  r.speed,
  r.fclass,
  (ST_Dump(
      CASE
        WHEN s.split_points IS NOT NULL
        THEN ST_Split(r.geom, s.split_points)
        ELSE r.geom
      END
    )).geom AS geom
FROM
  roads r
  LEFT JOIN road_split_points s ON r.ogc_fid = s.id;

/* add primary key */

ALTER TABLE roads_split ADD COLUMN id SERIAL PRIMARY KEY;

