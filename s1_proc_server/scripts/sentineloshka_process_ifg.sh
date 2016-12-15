#!/bin/bash
source ~/.SENTINELOSHKA/source.sh
#you can also include third parameter - processing step (1,2,3)
#for debugging, i also prepared proc. step 4 = precrop..
# 11/2016 - added: fourth parameter - ending processing step (1,2,3,4)
MASTER=$1
SLAVE=$2

if [[ ! -z $3 ]]; then STEP=$3; else STEP=1; fi
if [[ ! -z $4 ]]; then ENDSTEP=$4; else ENDSTEP=9; fi

 mkdir $MASTER'_'$SLAVE 2>/dev/null
 sed 's/MASTER/'$MASTER'/' topsApp_coregister.xml > topsApp_coregister_$MASTER'_'$SLAVE'.xml'
 sed -i 's/SLAVE/'$SLAVE'/' topsApp_coregister_$MASTER'_'$SLAVE'.xml'
 cd $MASTER'_'$SLAVE
if [ $STEP -lt 2 ]; then
 for SRT in `ls '../../SRTM1_DEM.wgs'*`; do ln -s $SRT; done
 ln -s ../$MASTER'.xml' master.xml
 ln -s ../$SLAVE'.xml' slave.xml
 ln -s ../$MASTER
 ln -s ../$SLAVE
 echo "Processing combination "$MASTER"_"$SLAVE" :"
 echo "Preparing DEM (should be made better in future..)"
 topsApp.py --start='computeBaselines' --end='topo' ../topsApp_coregister_$MASTER'_'$SLAVE'.xml' >topsApp01.log 2>topsApp01.err
fi

if [ $ENDSTEP -eq 1 ]; then cd ..; exit; fi

if [ $STEP -lt 3 ]; then
 echo "Performing ESD correction"
 topsApp.py --start='subsetoverlaps' --end='esd' ../topsApp_coregister_$MASTER'_'$SLAVE'.xml' >topsApp02.log 2>topsApp02.err
fi

if [ $ENDSTEP -eq 2 ]; then cd ..; exit; fi

if [ $STEP -lt 4 ]; then
 echo "Creating (merged) interferogram"
 topsApp.py --start='rangecoreg' --end='mergebursts' ../topsApp_coregister_$MASTER'_'$SLAVE'.xml' >topsApp03.log 2>topsApp03.err
fi

if [ $ENDSTEP -eq 3 ]; then cd ..; exit; fi
 #echo "And cropping (maybe later filtering) the interferogram"
 #echo ".. and preparing preview."
 
if [ $STEP -lt 5 ]; then
 if [ -e merged ]; then
   echo "Computing S, L coordinates to crop from the bounding box" 
   cd merged
   sentineloshka_get_SL_crop.sh `cat ../../../bounding_box.txt | sed 's/,/ /g'` 0.001 64
   S1=`grep S1 cropinfo.txt | gawk {'print $3'}`
   L1=`grep L1 cropinfo.txt | gawk {'print $3'}`
   S2=`grep S2 cropinfo.txt | gawk {'print $3'}`
   L2=`grep L2 cropinfo.txt | gawk {'print $3'}`
   let NEWLEN=$L2-$L1+1
   let NEWWID=$S2-$S1+1
   SAMPLES=`head -n1 topophase.flat.full.vrt | cut -d '"' -f2`
   echo "Pre-cropping the area (for easier coregistration)"
   mv cropinfo.txt precropinfo.txt
   cpxfiddle -w $SAMPLES -q normal -f cr4 -o float -p $S1 -P $S2 -l $L1 -L $L2 topophase.flat.full > topophase.flat.cropped
   cp topophase.flat.full.vrt topophase.flat.full.vrt.bck
   echo '<VRTDataset rasterXSize="'$NEWWID'" rasterYSize="'$NEWLEN'">' > topophase.flat.cropped.vrt
   cp topophase.flat.cropped.vrt topophase.flat.full.vrt #later on i should do something with this...
   cp topophase.flat.cropped.vrt lat.rdr.full.vrt #later on i should do something with this...
   cp topophase.flat.cropped.vrt lat.rdr.cropped.vrt
   #tail -n +2 topophase.flat.full.vrt >> topophase.flat.cropped.vrt
   cpxfiddle -w $SAMPLES -q normal -f r8 -o float -p $S1 -P $S2 -l $L1 -L $L2 lat.rdr.full > lat.rdr.cropped   
   cpxfiddle -w $SAMPLES -q normal -f r8 -o float -p $S1 -P $S2 -l $L1 -L $L2 lon.rdr.full > lon.rdr.cropped
   #cpxfiddle -w $SAMPLES -q normal -f r8 -o float -p $S1 -P $S2 -l $L1 -L $L2 los.rdr.full > los.rdr.cropped
   cpxfiddle -w $SAMPLES -q normal -f r8 -o float -p $S1 -P $S2 -l $L1 -L $L2 z.rdr.full > z.rdr.cropped
   for r in `ls *cropped | rev | cut -c 9- | rev`; do mv $r.full $r.bck; mv $r.cropped $r.full; done
   cd ..
   echo "Done. I should be cleaning unnecessary files now.. (but I am not)"
  else
   echo "Seems there was an error in connection "$x
   echo $MASTER'_'$SLAVE >> ../sentineloshka_error
 fi
fi
 touch sentineloshka_finished
 cd ..
 echo "----------------------"

