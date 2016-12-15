#!/bin/bash
#to be run from the project directory
#this script will convert bounding_box.txt into shapefile
MYFOLDER=`pwd`
PROJECTT=`echo $MYFOLDER | rev | cut -d '/' -f1 | rev`
BBOX=`cat bounding_box.txt`
lat1=`echo $BBOX | cut -d ',' -f1`
lat2=`echo $BBOX | cut -d ',' -f2`
lon1=`echo $BBOX | cut -d ',' -f3`
lon2=`echo $BBOX | cut -d ',' -f4`

echo "id,gm" > bounding_box.csv
echo '1,"POLYGON(('$lon1' '$lat1','$lon1' '$lat2','$lon2' '$lat2','$lon2' '$lat1'))"' >> bounding_box.csv

cat << EOF > bounding_box.vrt
<OGRVRTDataSource>
    <OGRVRTLayer name="bounding_box">
       <SrcDataSource>bounding_box.csv</SrcDataSource>
      <GeometryType>wkbPolygon25D</GeometryType>
 <LayerSRS>WGS84</LayerSRS>
 <GeometryField encoding="WKT" field='gm' > </GeometryField >
     </OGRVRTLayer>
</OGRVRTDataSource>
EOF

ogr2ogr $PROJECTT'_bbox.shp' bounding_box.vrt

exit
tohle je kdyztak v LayerSRS:
PROJCS["WGS_1984_Lambert_Conformal_Conic",GEOGCS["GCS_WGS_1984",DATUM["D_WGS_1984",SPHEROID["WGS_1984",6378137.0,298.257223563]],PRIMEM["Greenwich",0.0],UNIT["Degree",0.0174532925199433]],PROJECTION["Lambert_Conformal_Conic"],PARAMETER["False_Easting",1000000.0],PARAMETER["False_Northing",1000000.0],PARAMETER["Central_Meridian",85.875],PARAMETER["Standard_Parallel_1",24.625],PARAMETER["Standard_Parallel_2",27.125],PARAMETER["Latitude_Of_Origin",25.8772525],UNIT["Meter",1.0]]
