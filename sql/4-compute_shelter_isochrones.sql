/* create table for isochrones */
CREATE TABLE shelter_isochrones (
    id SERIAL PRIMARY KEY,
    shelter_id INTEGER NOT NULL,
    iso_minutes INTEGER NOT NULL,
    geom geometry(Polygon, 4326) NOT NULL
);



/* create isochrones for all shelters - VERY SLOW! */
WITH 
nearest AS (
	/* get nearest start node for each shelter */
	SELECT 
	    s.fid AS shelter_id,
	    v.id AS vertex_id,
	    v.the_geom,
	    ST_Distance(
	        v.the_geom, 
	        ST_SetSRID(ST_Point(ST_X(ST_GeometryN(s.geom, 1)), ST_Y(ST_GeometryN(s.geom, 1))), 4326)
	    ) AS dist
	FROM shelters s
	CROSS JOIN LATERAL (
	    SELECT 
	        id, 
	        the_geom
	    FROM roads_split_vertices_pgr
	    ORDER BY the_geom <-> ST_SetSRID(
	        ST_Point(
	            ST_X(ST_GeometryN(s.geom, 1)), 
	            ST_Y(ST_GeometryN(s.geom, 1))
	        ), 4326)
	    LIMIT 1
	) v
	/* consider running only a few at a time */
	/* WHERE s.fid BETWEEN 0 AND 9 */
),
cost_buckets AS (
  SELECT unnest(array[3, 6, 9, 12, 15]) AS iso_minutes
),
/* get all possible roads with a travel time up to 15 minutes */
drive AS (
  SELECT start_vid, node, agg_cost as cost
  FROM pgr_drivingDistance(
    'SELECT id, source, target, cost FROM roads_split',
    ARRAY(SELECT vertex_id FROM nearest),
    15,
    false
  )
),
/* get geometry for all related roads */
edges AS (
  SELECT d.start_vid, r.geom, d.cost
  FROM roads_split r
  JOIN drive d ON r.source = d.node OR r.target = d.node
)
/* make a concave hull for roads within each traval time interval and add it to the isochrones table */
INSERT INTO shelter_isochrones(shelter_id, iso_minutes, geom)
SELECT
  n.shelter_id AS shelter_id,
  c.iso_minutes,
  ST_ConcaveHull(ST_Collect(ST_Segmentize(geom, 0.0001)), 0.08) AS hull_geom
FROM
  cost_buckets c
  JOIN edges e ON e.cost <= c.iso_minutes
  LEFT JOIN nearest n ON n.vertex_id=e.start_vid
GROUP BY n.shelter_id, c.iso_minutes
ORDER BY n.shelter_id, c.iso_minutes;
