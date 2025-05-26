import requests
import json
from qgis.core import (
    QgsProject, QgsVectorLayer, QgsFeature, QgsGeometry, QgsFields, QgsField, QgsWkbTypes
)
from PyQt5.QtCore import QVariant

data_folder = '[project-path]'

def removeLayer(name):
    project = QgsProject.instance()
    for lyr in project.mapLayers().values():
        if lyr.name() == name:
            project.removeMapLayer(lyr)


layers = {}

def getLayer(name, type):
    # remove this line to raise errors when one type of features and different geometry type
    name = f"{name}_{type}"

    if name in layers:
        layer = layers[name]
        if layer[2] != type:
            raise Exception(f"Type doesn't match: existing: {layer[2]} requested: {type}")
        return layer
    
    removeLayer(name)
    
    layer_type = f"{type}?crs=EPSG:25832"
    print(f"create layer {name} of type {layer_type}")
    # Prepare a memory layer for MultiPolygons in EPSG:25832 (Danish UTM)
    vl = QgsVectorLayer(layer_type, name, "memory")
    pr = vl.dataProvider()
    pr.addAttributes([
        QgsField("id", QVariant.String),
        QgsField("name", QVariant.String),
        QgsField("description", QVariant.String),
        QgsField("type", QVariant.String),
        QgsField("region", QVariant.String),
    ])
    vl.updateFields()
    
    layers[name] = [vl, pr, type, name]
    return layers[name]



def addShelters(region, umbId):
    url = f"https://udinaturen.dk/api/map/categories/GetCategoriesByUmbId?region={region}&umbId={umbId}&organisation=33157274"
    response = requests.get(url)
    shelters = response.json()
    if 'status' in shelters:
        print(f"source {region},{umbId} not found")
        return
    
    with open(f"{data_folder}/r{region}_umb{umbId}.json", 'w', encoding='utf-8') as f:
        json.dump(shelters, f, ensure_ascii=False, indent=4)
    
    count = 0
    for feat in shelters:
        feature_type = feat["type"]
        geometry_type = feat["geometryType"]
        [vl, pr, type, name] = getLayer(feature_type, geometry_type)
        
        coords = feat["geometry"]
        if geometry_type == 'MultiPolygon':
            geom = QgsGeometry.fromMultiPolygonXY([
                [ [QgsPointXY(x, y) for x, y in ring] for ring in polygon ]
                for polygon in coords
            ])
        elif geometry_type == 'MultiPoint':
            geom = QgsGeometry.fromMultiPointXY([QgsPointXY(x, y) for x, y in coords])
        else:
            print(f"unknown geometry type {geometry_type}")
            continue
        
        count += 1
        f = QgsFeature()
        f.setGeometry(geom)
        f.setAttributes([
            feat.get("id"),
            feat.get("name"),
            feat.get("description"),
            feat.get("type"),
            feat.get("region"),
        ])
        pr.addFeature(f)
    
    print(f"source {region},{umbId}: {count} features")

for region in range(81, 86): 
    for umbid in [1106, 1111, 1112, 1115, 1327, 1328]:
        addShelters(region, umbid)

for name in layers:
    [vl,br,type,name] = layers[name]
    vl.updateExtents()
    QgsProject.instance().addMapLayer(vl)

