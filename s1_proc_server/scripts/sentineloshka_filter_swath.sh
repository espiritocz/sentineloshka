#!/bin/bash
#to be run from the SWATH folder
THRESHOLD_CLUSTER=5
HERE=`pwd`
SWATHDIR=`echo $HERE | rev | cut -d '/' -f1 | rev`

#Remove erroneous ifgs first
echo "Removing erroneous interferograms:"
sentineloshka_remove_erroneous.sh
echo " "

#Check for correct cluster connections
echo "Checking for clusters in the available interferogram combinations"
SM=small_baselines.list
cp $SM small_baselines.list.bck
cp day.1.in day.1.in.bck
#checking all days (without the first and last one)
for DEN in `cat day.1.in | tail -n +2 | head -n -1`; do
 i=`ls -d ../$SWATHDIR* | wc -l`
 #if there is no previous connection
 if [ `grep -c ' '$DEN $SM` -eq 0 ] && [ `grep -c $DEN day.1.in` -eq 1 ]; then
  DENPO=`grep -A1 $DEN day.1.in | tail -n1`
  DENPRED=`grep -B1 $DEN day.1.in | head -n1`
  sed '/'$DEN'/d' $SM > sm.tmp
  #and if there is no previous connection also of the next day - then it means we have to create a new cluster
  #where we will move all good connections BEFORE this day
  if [ `grep -c ' '$DENPO sm.tmp` -eq 0 ]; then
   LASTLINE=`grep ' '$DENPRED $SM | tail -n1`
   mkdir ../$SWATHDIR'_'$i
   grep -B9999 "$LASTLINE" $SM > ../$SWATHDIR'_'$i/small_baselines.list
   grep -B9999 $DENPRED day.1.in > ../$SWATHDIR'_'$i/day.1.in
   #while this folder will be actually... the last cluster
   grep -A9999 "$LASTLINE" $SM | tail -n +2 > sm.tmp
   mv sm.tmp $SM
   #nema tu byt az DENPO??
   grep -A9999 $DEN day.1.in > day.tmp
   mv day.tmp day.1.in
  fi
 fi
done

#We will make this last cluster now (if there are more than one)
cd ..
i=`ls -d $SWATHDIR* | wc -l`
if [ $i -eq 1 ]; then echo "Good. The dataset is fully consistent"; exit; 
 else
  mkdir $SWATHDIR'_'$i
  cp $SWATHDIR/day.1.in $SWATHDIR/small_baselines.list $SWATHDIR'_'$i'/.'
fi
#Now check the size of connection clusters and remove those with less than $THRESHOLD_CLUSTER images
#mkdir WRONG 2>/dev/null
for CLUSTER in `ls $SWATHDIR'_'* -d 2>/dev/null`; do
 CLUNO=`cat $CLUSTER/day.1.in | wc -l`
 if [ $CLUNO -lt $THRESHOLD_CLUSTER ]; then
  #mv $CLUSTER WRONG/.
  rm -r $CLUSTER
  echo "Cluster "$CLUSTER" removed. Contained only "$CLUNO" images."
 fi
done

#And if now there are no more clusters, then shrink it (baby)
i=`ls -d $SWATHDIR* | wc -l`
if [ $i -eq 2 ]; then
 echo "Great, we have only one cluster to be processed! Moving it back..";
 cp $SWATHDIR'_'*/* $SWATHDIR/.
 rm -r $SWATHDIR'_'*
 cd $SWATHDIR
 if [ `diff day.1.in day.1.in.bck | wc -l` -gt 0 ]; then
  mkdir ERROR_2
  for u in `diff day.1.in day.1.in.bck | tail -n +2 | gawk {'print $2'}`; do
   mv *$u* ERROR_2/.
  done
 fi
 cd ..
 exit;
fi

#Otherwise it means we are clustering! So..
for CLUSTER in `ls $SWATHDIR'_'* -d 2>/dev/null`; do
  cd $CLUSTER
#  for x in `sed 's/ /_/' small_baselines.list`; do
#   mv ../$SWATHDIR/$x .
#  done
  for x in `cat day.1.in`; do 
   mv ../$SWATHDIR/*$x* . 2>/dev/null;
  done
  cd ..
done 2>/dev/null
mv $SWATHDIR bck_$SWATHDIR
