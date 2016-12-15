#!/bin/bash
# This script does:
# Making SB connections
# Coregistering and ESD correcting SB connections (ISCE)
# Coregistering these connections into common frame (doris)
# Clustering into consistent datasets
# Cropping ifgs
# and multitemporal processing of all these clusters
#module add Octave/3.8.2-intel-2015b
source ~/.SENTINELOSHKA/source.sh
PROJNO=$1
SWATHDIR=$2
TEMPLATES=$SENTTEMPLATES
NOPROCESSORS=24
PROJECTIT4I=DD-13-5
USER=$SENTUSER

PREPATH=$SENTPREPATH
cd $PREPATH'/'$PROJNO'/'$SWATHDIR
PROJPATH=$PREPATH'/'$PROJNO

#first we make small baselines connections (triangles)
ls 2*/ -d | cut -d '/' -f1 > day.1.in
for x in `cat day.1.in`; do
 ONEMORE=`grep -A1 $x day.1.in | tail -n1`
 SECOND=`grep -A2 $x day.1.in | tail -n1`
 echo $x'_'$ONEMORE >> tmp.txt
 echo $x'_'$SECOND >> tmp.txt
done
head -n -3 tmp.txt > connections.txt
#sed 's/_/ /' connections.txt > small_baselines.list
rm tmp.txt

#now we coregister and ESD-correct all these connections using ISCE..
cp $TEMPLATES/topsApp_coregister.xml .

# performing ifg processing for all of the connections
for x in `cat connections.txt`; do
 MASTER=`echo $x | cut -d '_' -f1`
 SLAVE=`echo $x | cut -d '_' -f2`
 if [ ! -e $x ]; then
  echo cd `pwd` > qsub_$x'.sh'
  echo sentineloshka_process_ifg.sh $MASTER $SLAVE >> qsub_$x'.sh'
  chmod 775 qsub_$x'.sh'
  #overcoming problem with user limit - 100 tasks in queue
  while [ `qstat | grep $USER | wc -l` -gt 90 ]; do sleep 10; echo "Waiting till something finishes (we have limit 100 tasks per user)"; done
  #I realized that ifg will not be finished within an hour (with 24 processors) in some cases of 4 or more bursts :( so cannot use qexp :((((
  if [ `ls $MASTER | wc -l` -gt 9 ]; then FRONTA="qfree -A "$PROJECTIT4I; else FRONTA="qexp"; fi
  qsub -q $FRONTA ./qsub_$x'.sh'
 fi
done

#Wait till the multinode processing is finished.. (yeah!)
WHOAMI=`whoami`
GRF=0
while [ ! -f sentineloshka_finished ]; do
 if [ `ls 2*_*/sentineloshka_finished 2>/dev/null | wc -l` -eq `cat connections.txt | wc -l` ]; then touch sentineloshka_finished; fi
 sleep 10
 echo "---------------"
 B=`ls 2*_*/sentineloshka_finished 2>/dev/null | rev | cut -d '/' -f2 | rev`
 if [ ! -z `echo $B | gawk {'print $1'}` ]; then
  echo "Waiting. Processing finished for "`ls 2*_*/sentineloshka_finished | wc -l`" of "`cat connections.txt | wc -l`" interferograms."
  if [ `qstat | grep $WHOAMI | wc -l` -eq 0 ]; then 
   if [ $GRF -lt 2 ]; then sentineloshka_check_ifg_processing.sh; else touch sentineloshka_finished; fi
   let GRF=$GRF+1
  fi
 fi
done

rm sentineloshka_finished

#Using doris to coregister the merged bursts
echo cd `pwd` > qsub_doris_coreg.sh
echo sentineloshka_coregister_doris2.sh >> qsub_doris_coreg.sh
chmod 775 qsub_doris_coreg.sh
qsub -q qfree -A $PROJECTIT4I ./qsub_doris_coreg.sh
IFGSNO=`ls 2*_*/merged -d | wc -l`
while [ ! -f sentineloshka_finished ]; do
 sleep 8
 LAST=`ls */merged/resampled.raw 2>/dev/null | wc -l`
 echo "---------------"
 echo "Waiting for coregistration"
 echo "Done: "$LAST" of "$IFGSNO" interferograms."
done
rm sentineloshka_finished

#Filter and cluster out the swath
sentineloshka_filter_swath.sh

#some additional scripts:
cd $PROJPATH
bounding_box2shp.sh

echo "Pre-processing (finally) done. Let's perform the main processing now"
