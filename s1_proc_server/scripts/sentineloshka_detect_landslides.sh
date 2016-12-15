#!/bin/bash
#Input is CSV file from Sentineloshka PROJID folder
#I assume you keep the name of this CSV, meaning, the SWATHDIR..
CSV=$1
COHTRES=0.8

module add PROJ_4/4.9.2-foss-2015g
PROJID=`pwd`
SWATHDIR=`echo $CSV | cut -d '.' -f1`
CSVBASE=`echo $CSV | cut -d '.' -f1`
GIS=tmp_$CSVBASE
mkdir $GIS

#preparation of data
gdal_translate -of GTiff SRTM1_DEM.wgs84.vrt $GIS/DEM_wgs.tif

#So, first I convert the CSV into SHP, in order to create an interpolated
#heat map.
cp $CSV $GIS/.
cd $GIS
csv_change_dates.sh $CSV
mv $CSVBASE*ok* $CSV
csv2shp.sh -c $CSV -x LON -y LAT -s $CSVBASE'.shp'
BBOX=`cat ../bounding_box.txt`
S=`echo $BBOX | cut -d ',' -f1`
N=`echo $BBOX | cut -d ',' -f2`
W=`echo $BBOX | cut -d ',' -f3`
E=`echo $BBOX | cut -d ',' -f4`
#MID=`echo "($E+$W)/2" | bc`
#if [ $MID -gt 0 ]; then
#  UNICOOR=326$MID
# else
#  UNICOOR=327`echo $MID | sed 's/-//'`
#fi
#ogr2ogr -sql "SELECT VEL FROM $CSVBASE WHERE COHER>$COHTRES AND LON>$E" $CSVBASE'_vel.shp' $CSVBASE'.shp'
ogr2ogr -sql "SELECT VEL FROM $CSVBASE WHERE COHER>$COHTRES AND LON<$E AND LON>$W AND LAT>$S AND LAT<$N" $CSVBASE'_vel.shp' $CSVBASE'.shp'
#ogr2ogr -clipsrc $W $S $E $N -sql "SELECT VEL,COHER FROM $CSVBASE WHERE COHER>$COHTRES" $CSVBASE'_vel.shp' $CSVBASE'.shp' #GEOS not enabled!

#Now will interpolate it and export into unified coord.system
gdal_grid -zfield "VEL" -a invdist:power=2.0:smoothing=0.001 -of GTiff -l $CSVBASE'_vel' $CSVBASE'_vel.shp' $CSVBASE'_vel.tif' --config GDAL_NUM_THREADS ALL_CPUS
#gdalwarp -s_srs EPSG:4326 -t_srs EPSG:3857 $CSVBASE'_vel.tif' vel.tif
gdalwarp -s_srs EPSG:4326 -t_srs EPSG:3857 -te_srs EPSG:4326 -te $W $S $E $N $CSVBASE'_vel.tif' vel.tif

#Preparing DEM products (in lower resolution)
gdalwarp -s_srs EPSG:4326 -t_srs EPSG:3857 -multi DEM_wgs.tif DEM.tif
gdal_translate -a_srs EPSG:3857 -tr 200 200 DEM.tif DEM_small.tif
gdaldem slope DEM_small.tif slope.tif
gdaldem aspect DEM_small.tif aspect.tif

#Unifying - thanks to ssrebelious.wordpress.com
cp ~/.SENTINELOSHKA/scripts/sentineloshka_detect_landslides_unify.py .
mkdir tmp; python3 sentineloshka_detect_landslides_unify.py
#mv tmp/*unified* .
#Now I try to crop it to the BBOX.. didn't test it though
cd tmp
for x in `ls *unified*`; do gdalwarp -s_srs EPSG:3857 -t_srs EPSG:3857 -te_srs EPSG:4326 -te $W $S $E $N $x ../$x; done
cd ..

#Now I will compute the LOS2slope
A=vel_unified.tif
B=DEM_unified.tif
C=slope_unified.tif
D=aspect_unified.tif
#I will get inc.angle only as one (average) value.. but this should be okay
WID=`cat ../$CSVBASE/INSAR*/SMAL*/width.txt`
LEN=`cat ../$CSVBASE/INSAR*/SMAL*/len.txt`
let MIDX=$WID/2
let MIDY=$LEN/2
INC=`cpxfiddle -o ascii -q normal -f r4 -w $WID -p $MIDX -P $MIDX -l $MIDY -L $MIDY ../$CSVBASE/INSAR*/SMAL*/look_angle.raw 2>/dev/null | cut -d '.' -f1`
echo $INC > inc.txt
H=`cat ../$CSVBASE/INSAR*/SMAL*/heading*`
HEAD=`echo $H+180 | bc`
echo $HEAD > head.txt

#computing now
#removing points over 1600 m
gdal_calc.py -A $A -B $B --outfile=result_nohei.tif --calc="A*(B<1600)" --NoDataValue=0
A=result_nohei.tif
#removing points at shallow slopes, plus using only negative numbers (down-slope LOS-directed movements)
gdal_calc.py -A $A -B $C --outfile=result_sloped.tif --calc="A*(B>6)*(A<0)" --NoDataValue=0
A=result_sloped.tif
#masking movements S/N direction
gdal_calc.py -A $A -B $D --outfile=result_masked.tif --calc="A*(B-"$HEAD">20)*(B-"$HEAD"<340)" --NoDataValue=0
A=result_masked.tif
#finally computing the slopedir values

gdal_calc.py -A $A -B $C -C $D --outfile=slope_direction.tif \
--calc="A/numpy.sqrt(numpy.square(numpy.sin(B*3.14159/180)*numpy.cos("$INC"*3.14159/180)+numpy.sin(C*3.14159/180-"$HEAD"*3.14159/180)*numpy.cos(B*3.14159/180)*numpy.sin("$INC"*3.14159/180)))"
gdalwarp -t_srs EPSG:4326 slope_direction.tif slope_direction_wgs84.tif

mv slope_direction_wgs84.tif ../$CSVBASE'_slopedir.tif' 
cd ..
