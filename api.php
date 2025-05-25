<?php
header('Content-Type: application/json');
header("Access-Control-Allow-Origin: *");


$conn = pg_connect("host=localhost port=5432 dbname=gis user=postgres password=[PASSWORD]");
if (!$conn) {
    http_response_code(500);
    echo json_encode(['error' => 'DB connection failed']);
    exit;
}

$cmd = filter_input(INPUT_GET, 'cmd', FILTER_SANITIZE_STRING);
$res = null;
$fields = [];
switch ($cmd) {
    case 'map':
        $sql = "
          SELECT fid as id,
                 ST_AsGeoJSON(geom)::json AS geometry,
                 name
            FROM shelters
            WHERE geom && ST_MakeEnvelope($1, $2, $3, $4, 4326)
        ";
        $stmt = pg_prepare($conn, "getroads", $sql);

        $params = [
            filter_input(INPUT_GET, 'xmin', FILTER_VALIDATE_FLOAT) ?? -180,
            filter_input(INPUT_GET, 'ymin', FILTER_VALIDATE_FLOAT) ?? -90,
            filter_input(INPUT_GET, 'xmax', FILTER_VALIDATE_FLOAT) ??  180,
            filter_input(INPUT_GET, 'ymax', FILTER_VALIDATE_FLOAT) ??  90,
        ];
        $res = pg_execute($conn, "getroads", $params);
        $fields = ['id' => 'int', 'name' => 'string'];
        break;

    case 'isochrone':
        $sql = "
          SELECT ST_AsGeoJSON(geom)::json AS geometry,
                 iso_minutes as minutes
            FROM shelter_isochrones
            WHERE shelter_id=$1
            ORDER BY iso_minutes DESC
        ";
        $stmt = pg_prepare($conn, "getisochrone", $sql);
        $params = [
            filter_input(INPUT_GET, 'shelter', FILTER_VALIDATE_INT) ?? 0,
        ];
        $res = pg_execute($conn, "getisochrone", $params);    
        $fields = ['minutes' => 'int'];
        break;

}





if (!$res) {
    http_response_code(500);
    echo json_encode(['error' => 'Query failed']);
    exit;
}


$features = [];
while ($row = pg_fetch_assoc($res)) {
    $geometry = json_decode($row['geometry'], true);
    $properties = [];
    foreach ($fields as $key => $type) {
        switch ($type) {
            case 'int': $properties[$key] = (int)$row[$key]; break;
            case 'string': $properties[$key] = (string)$row[$key]; break;
        }
    }
    $features[] = [
        'type'       => 'Feature',
        'geometry'   => $geometry,
        'properties' => $properties,
    ];
}

echo json_encode([
    'type'     => 'FeatureCollection',
    'features' => $features,
]);


