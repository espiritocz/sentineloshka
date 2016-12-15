#!/bin/bash
#Input is PROJID folder that contains CSV files..
#I assume you keep the name of this CSV, meaning, the SWATHDIR..
PROJDIR=`pwd`
COHTRES=0.8
PROJID=`echo $PROJDIR | rev | cut -d '/' -f1 | rev`

cp ~/.SENTINELOSHKA/scripts/decompose/* .

#prepare the variables for decomposition script
for CSV in `ls *.csv`; do
 SWATHDIR=`echo $CSV | cut -d '.' -f1`
 CSVBASE=`echo $CSV | cut -d '.' -f1`
 INFILES=$INFILES"'"`pwd`/`echo $CSV`"',"
  WID=`cat $CSVBASE/INSAR*/SMAL*/width.txt`
  LEN=`cat $CSVBASE/INSAR*/SMAL*/len.txt`
  let MIDX=$WID/2
  let MIDY=$LEN/2
 INC=`cpxfiddle -o ascii -q normal -f r4 -w $WID -p $MIDX -P $MIDX -l $MIDY -L $MIDY $CSVBASE/INSAR*/SMAL*/look_angle.raw 2>/dev/null | cut -d '.' -f1`
 H=`cat $CSVBASE/INSAR*/SMAL*/heading*`
 if [ `echo $H | cut -d '.' -f1 | sed 's/-//'` -gt 50 ]; then HEAD=`echo $H+270 | bc`
   else HEAD=`echo $H-90 | bc`; fi
 TRACK_DATA=$TRACK_DATA""$INC","$HEAD";"
done
INFILES=`echo $INFILES | rev | cut -c 2- | rev`
TRACK_DATA=`echo $TRACK_DATA | rev | cut -c 2- | rev`

OUTFILE=`pwd`/$PROJID"_decomposed.csv"

BBOX=`cat bounding_box.txt`
S=`echo $BBOX | cut -d ',' -f1`
N=`echo $BBOX | cut -d ',' -f2`
W=`echo $BBOX | cut -d ',' -f3`
E=`echo $BBOX | cut -d ',' -f4`
BBOX_AOI=`echo $W","$E";"$N","$S`

#I will get inc.angle only as one (average) value.. but this should be okay

SEDINF=`echo $INFILES | sed 's/\//\\\\\//g'`
SEDOUT=`echo $OUTFILE | sed 's/\//\\\\\//g'`

sed -i 's/INFILES/'$SEDINF'/' sentineloshka_decompose.m
sed -i 's/OUTFILE/'$SEDOUT'/' sentineloshka_decompose.m
sed -i 's/TRACK_DATA/'$TRACK_DATA'/' sentineloshka_decompose.m
sed -i 's/COHER_THR/'$COHTRES'/' sentineloshka_decompose.m
sed -i 's/BBOX_AOI/'$BBOX_AOI'/' sentineloshka_decompose.m

matlab -nodesktop -nosplash -r "sentineloshka_decompose; exit"

