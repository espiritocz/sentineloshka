#!/bin/bash
#Lat and Lon are always as: S N W E
#e.g. 49.794 49.898 18.384 18.58
#lat1=49.794
#lat2=49.898
#lon1=18.384
#lon2=18.58
#to be run from ISCE server..
#The fifth parameter is task to be performed
# and this can be:
# sb - to do just SB processing (STAMPS)
# landslide - to perform landslide detection postprocessing after SB
# sb_decompose - this will perform decomposition after SB
# select_aoi - to perform only PS candidate selection based on AOI file
lat1=$1
lat2=$2
lon1=$3
lon2=$4
TASK=$5
#Threshold for minimal number of images
MINIMAGES=15
#####################
source ~/sentineloshka_db_vars
PROJNOOLD=`ssh $SENT_PROCSSH "ls -d $SENT_PATH_PROC/1* | tail -n 1 | rev | cut -d '/' -f1 | rev"`
let PROJNO=$PROJNOOLD+1
PROJDIR=$SENT_HOME/project

#Checking if another ISCE Cloud processing is running - only one will be permitted..
if [ `ls $PROJDIR/1* -d 2>/dev/null | wc -l` -gt 0 ]; then
 echo "Another processing is ongoing. Sorry, try again later."
 exit
fi

cd $PROJDIR
#code to generate path-list of images that contain given area
mysql -h $SENT_MYSQL_DB -u $SENT_MYSQL_USER --password=$SENT_MYSQL_PASS --database=$SENT_MYSQL_S1DB -e "SELECT distinct files.abs_path, files.swath, files.rel_orb from files inner join files2bursts on files.fid=files2bursts.fid inner join bursts on files2bursts.bid=bursts.bid WHERE Intersects(GeomFromText('Polygon(($lat1 $lon1, $lat1 $lon2, $lat2 $lon2, $lat2 $lon1, $lat1 $lon1))'), GeomFromText(CONCAT('Polygon((', bursts.corner1_lat, ' ', bursts.corner1_lon, ', ', bursts.corner2_lat, ' ', bursts.corner2_lon, ', ', bursts.corner3_lat, ' ', bursts.corner3_lon, ', ', bursts.corner4_lat, ' ', bursts.corner4_lon, ', ', bursts.corner1_lat, ' ', bursts.corner1_lon, ')) ')));" | tail -n+2 > selection.txt 2>/dev/null
if [ `cat selection.txt | wc -l` -lt 2 ]; then echo "Nothing was found in our S-1 database.."; exit; fi

#preparatory part
mkdir $PROJNO
cd $PROJNO
mv ../selection.txt .
cp $SENT_HOME/templates/topsApp_coregister.xml .
sed -i 's/AOI/['$lat1','$lat2','$lon1','$lon2']/' topsApp_coregister.xml
#sed -i 's/AOI/['$lat1','`echo 0.0001+$lat1 | bc`','$lon1','`echo 0.0001+$lon1 | bc`']/' topsApp_bperp.xml
ssh $SENT_PROCSSH "mkdir -p $SENT_PATH_PROC/$PROJNO"

#prepare the structure
cat selection.txt | awk {'print $3'} | sort -u > relorbits.txt
for relorb in `cat relorbits.txt`; do
 cat selection.txt | awk '$3=='$relorb' {print $1}' | sort -u > relorb_$relorb'_list.txt'
 cat selection.txt | awk '$3=='$relorb' {print $2}' | sort -u | cut -c 3- > relorb_$relorb'_swath.txt'
 if [ `cat relorb_$relorb'_list.txt' | wc -l` -lt $MINIMAGES ]; then
   echo "Number of images in relative orbit "$relorb" is lower than the minimal threshold. Cancelling."
   rm relorb_$relorb'_'*
 fi
done

#prepare DEM (converted to WGS84)
#downloading +1' bigger (each side)
A=`echo $lat1 | cut -d '.' -f1`; let DEMlat1=$A'-1'
A=`echo $lat2 | cut -d '.' -f1`; let DEMlat2=$A'+1'
A=`echo $lon1 | cut -d '.' -f1`; let DEMlon1=$A'-1'
A=`echo $lon2 | cut -d '.' -f1`; let DEMlon2=$A'+1'
while [ ! -e SRTM1_DEM.xml ]; do
dem.py -b $DEMlat1 $DEMlat2 $DEMlon1 $DEMlon2 -s 1 -c -o SRTM1_DEM
done
rm SRTM1_DEM SRTM1_DEM.xml SRTM1_DEM.vrt
scp SRTM* $SENT_PROCSSH:$SENT_PATH_PROC/$PROJNO'/.'
echo $lat1','$lat2','$lon1','$lon2 > bounding_box.txt
scp bounding_box.txt $SENT_PROCSSH:$SENT_PATH_PROC/$PROJNO'/.'

#This is for Select_aoi task
if [ $TASK == "select_aoi" ]; then
scp AOI.* $SENT_PROCSSH:$SENT_PATH_PROC/$PROJNO'/.'
fi

#make it..
echo "Using topsApp.py to crop images one-by-one. Ignore Segm. faults please.."
for relorbit in `ls relorb*swath.txt | cut -d '_' -f2`; do
 echo "Loading relative orbit "$relorbit
 mkdir $relorbit
 cd $relorbit
 #create and populate ISCE topsApp input files for cropping the selected images
 for FILE in `cat ../relorb_$relorbit'_list.txt'`; do
  ln -s $FILE
  FILENAME=`echo $FILE | rev | cut -d '/' -f1 | rev`
  DATUM=`echo $FILENAME | cut -c 18-25`
  #preparing ISCE xml files for merge and crop to bursts:
  if [ ! -e topsApp_coregister_$DATUM'.xml' ]; 
   then
    sed 's/DIR/'$DATUM'/' ../topsApp_coregister.xml > topsApp_coregister_$DATUM'.xml'
    sed -i "s/']/..\/"$FILENAME"']/" topsApp_coregister_$DATUM'.xml'
   else
    sed -i "s/']/','..\/"$FILENAME"']/" topsApp_coregister_$DATUM'.xml'
  fi
 done

 #Now preparing within each swath
 for x in `cat ../relorb_$relorbit'_swath.txt'`; do
  echo "Preparing swath "$x" of rel. orbit "$relorbit
  #Prepare the structure here and also at IT4Innovations
  IWDIR=relorb_$relorbit'_iw_'$x
  mkdir $IWDIR
  ssh $SENT_PROCSSH "mkdir -p $SENT_PATH_PROC/$PROJNO'/'$IWDIR"
  #crop the images
  for y in `ls topsApp_coregister_*xml`; do
   DATE=`echo $y | cut -d '_' -f3 | cut -d '.' -f1`
   echo "Cropping date "$DATE", swath no. "$x
   sed 's/SWATH/'$x'/' $y > $IWDIR/$y
   cd $IWDIR
   topsApp.py $y --end='preprocess' >/dev/null 2>/dev/null #>topsapp.log 2>topsapp2.log
   if [ ! -e $DATE'.xml' ]; then
     echo "Well, this date "$DATE" was erroneous. Removing :("
     rm -r $DATE; echo $DATE >> erroneous;
    else
     #if ok, move it to the HPC processing system for preprocessing
     echo "Done. Moving to HPC for further processing"
     scp -r $DATE* $SENT_PROCSSH:$SENT_PATH_PROC/$PROJNO'/'$IWDIR'/.'
     rm -r $DATE*
   fi
   cd ..
  done
  #remove erroneous images and other cleaning
  #for wrongone in `cat erroneous`; do rm -r *$wrongone*; done
  #rm topsApp_coregister*
  cd $IWDIR
  # Older solution - should be redone... here we process swath by swath
  ssh $SENT_PROCSSH "echo 1 > $SENT_PATH_PROC/$PROJNO'/'$IWDIR'/ice_cloud_done'"
  ssh $SENT_PROCSSH "echo $SENT_PROC_SCRIPTS/sentineloshka_process_swath.sh $PROJNO $IWDIR > $SENT_PATH_PROC/$PROJNO'/'$IWDIR'/qsub.sh'"
  #Let's process according to what we want to do here:
  ssh $SENT_PROCSSH "echo $SENT_PROC_SCRIPTS/sentineloshka_postprocess_swath.sh $PROJNO $IWDIR $TASK >> $SENT_PATH_PROC/$PROJNO'/'$IWDIR'/qsub.sh'"
  ssh $SENT_PROCSSH "chmod 775 $SENT_PATH_PROC/$PROJNO'/'$IWDIR'/qsub.sh'"
  ssh $SENT_PROCSSH "sh $SENT_PATH_PROC/$PROJNO'/'$IWDIR'/qsub.sh'" >$SENT_HOME/project/$IWDIR'.out' 2>$SENT_HOME/project/$IWDIR'.err' &
  cd ..
 done
 cd ..
done

#Cleaning ISCE Cloud
cd $PROJDIR
rm -r $PROJDIR/$PROJNO
