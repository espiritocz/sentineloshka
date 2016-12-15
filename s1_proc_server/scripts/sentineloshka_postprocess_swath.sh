#!/bin/bash
# This script does post-processing for all swath subset folders, depending on TASK (third parameter)

source ~/.SENTINELOSHKA/source.sh
PROJNO=$1
SWATHDIR=$2
TASK=$3
TEMPLATES=$SENTTEMPLATES
NOPROCESSORS=24
PROJECTIT4I=DD-13-5

PREPATH=$SENTPREPATH
cd $PREPATH'/'$PROJNO'/'$SWATHDIR
PROJPATH=$PREPATH'/'$PROJNO

#Run STAMPS preprocessing for all swath clusters
cd $PROJPATH
for SWATH in `ls $SWATHDIR* -d`; do
 cd $SWATH
 echo cd `pwd` > qsub_postproc.sh
case "$TASK" in
 sb)
  echo "echo 'Preparing STAMPS processing for '"$SWATH >> qsub_postproc.sh
  echo sentineloshka_prepare_stamps_sb.sh >> qsub_postproc.sh
  echo "echo 'Performing STAMPS processing for '"$SWATH >> qsub_postproc.sh
  echo sentineloshka_process_stamps.sh >> qsub_postproc.sh
  ;;
 select_aoi)
  echo cd `pwd` > qsub_postproc.sh
  echo "echo 'Preparing STAMPS processing for '"$SWATH >> qsub_postproc.sh
  echo sentineloshka_prepare_stamps_sb.sh >> qsub_postproc.sh
  echo cd INSAR*/SMALL* >> qsub_postproc.sh
  echo "echo 'Selecting PS candidates only for '"$SWATH >> qsub_postproc.sh
  echo sentineloshka_select_cand.sh >> qsub_postproc.sh
  ;;
esac
 chmod 775 qsub_postproc.sh
 qsub -q qfree -A $PROJECTIT4I ./qsub_postproc.sh
 cd ..
done

echo "Alright, now it should be working.. Check the results yourself, you know where J"

