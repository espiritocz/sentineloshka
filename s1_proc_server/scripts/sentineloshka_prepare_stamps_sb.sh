#!/bin/bash
#prepare STAMPS SB processing and compute bperp.1.in
#must be run from the swath project folder
#parameter is FILTER - if 0, we will not filter.. but default will be filter it..
if [ ! -z $1 ]; then FILTER=1; else FILTER=$1; fi
SWATHDIR=`pwd`
cd ..
PROJPATH=`pwd`
cd $SWATHDIR
TEMPLATES=$SENTTEMPLATES

#Choose master in the middle of dataset and prepare the bperp computation.
#I do it here again because a step before was clustering due to errors in ifg generation/coregistration = the dataset may have changed
let maspos=`cat day.1.in | wc -l`/2
head -n $maspos day.1.in | tail -n1 > master_day.1.in
master=`cat master_day.1.in`
STAMPSPROCDIR=`pwd`/INSAR_$master
mkdir -p $STAMPSPROCDIR/SMALL_BASELINES
SBDIR=$STAMPSPROCDIR/SMALL_BASELINES

#Compute bperps
sentineloshka_correct_day.sh
echo "Computing perp. baselines for PS combinations with master as "$master
rm bperp.1.in 2>/dev/null
cp $TEMPLATES/topsApp_coregister.xml .
for DATUM in `cat day.1.in`; do
 if [ ! $DATUM -eq $master ]; 
  then
   rm -r PICKLE master.xml slave.xml 2>/dev/null
   sed 's/SLAVE/'$DATUM'/' topsApp_coregister.xml > topsApp_bperp_$DATUM'.xml'
   sed -i "s/MASTER/"$master"/" topsApp_bperp_$DATUM'.xml'
   ln -s $master'.xml' master.xml
   ln -s $DATUM'.xml' slave.xml
   topsApp.py topsApp_bperp_$DATUM'.xml' --dostep='computeBaselines' | grep Bperp | head -n1 | rev | gawk {'print $1'} | rev >> bperp.1.in
  else
   echo 0 >> bperp.1.in
 fi
done

#Get master image and find bounding box coordinates
#The coordinates must be found in the original Master image (i.e. before clustering)
ORIGMDIR=`ls 2*_*/merged/master.raw -alh | head -n1 | rev | cut -d '/' -f3 | rev`
if [ `ls $SWATHDIR -d | rev | cut -d 'w' -f1 | wc -c` -gt 3 ]; then
  ROOTSWATH=`echo $SWATHDIR | rev | cut -d '/' -f1 | cut -c 3- | rev`
 else
  ROOTSWATH=`echo $SWATHDIR | rev | cut -d '/' -f1 | rev`
fi
ORIGMDIRDIR=`find ../$ROOTSWATH* -name $ORIGMDIR | head -n1`
cd $ORIGMDIRDIR
ORIGMDIRDIR=`pwd`
cd merged
 #now we can do a crop with only a small buffer..
 sentineloshka_get_SL_crop.sh `cat $PROJPATH/bounding_box.txt | sed 's/,/ /g'` 0.0001 32
 WIDTH=`grep width cropinfo.txt | gawk {'print $3'}`
 echo $WIDTH > $SBDIR/width.txt
 LENGTH=`grep length cropinfo.txt | gawk {'print $3'}`
 echo $LENGTH > $SBDIR/len.txt
 S1=`grep S1 cropinfo.txt | gawk {'print $3'}`
 L1=`grep L1 cropinfo.txt | gawk {'print $3'}`
 S2=`grep S2 cropinfo.txt | gawk {'print $3'}`
 L2=`grep L2 cropinfo.txt | gawk {'print $3'}`
cd $SWATHDIR


#Now this code is to care about situation when original master is not in this cluster..
echo $ORIGMDIRDIR >tmp.tmp
grep -c `echo $SWATHDIR | rev | cut -d '/' -f1 | rev` tmp.tmp > tmp.tmpp
if [ `cat tmp.tmpp` -eq 0 ]; then
  #here we should go to this "nonexisting" original Master dir to move lon lat etc. to SBDIR
  cd $ORIGMDIRDIR/merged
  rm resampled.raw
  ln -s topophase.flat.full resampled.raw
  sentineloshka_crop_merged.sh $SBDIR/$ORIGMDIR $ORIGMDIRDIR
fi
cd $SWATHDIR
rm tmp.tm*

#Crop and move and filter ifgs to SB processing
for x in `ls 2*_* -d`; do
 mkdir $SBDIR/$x 2>/dev/null

 #Crop the coregistered images
 #If this image is MDIR, then also crop lat, lon etc.
 cd $x/merged
 sentineloshka_crop_merged.sh $SBDIR/$x $ORIGMDIRDIR

 #only if it was run twice..
 rm cint.minrefdem.raw 2>/dev/null; rm ../cint.minrefdem.raw 2>/dev/null

 if $FILTER=1; then
  #Filter the cropped ifgs
  ln -s $SBDIR/$x/cint.minrefdem.raw
  ln -s $SBDIR/$x/cint.minrefdem.raw ../cint.minrefdem.raw
  cp $TEMPLATES/cint.minrefdem.raw.* .
  sed -i 's/WIDTH/'$WIDTH'/' cint.minrefdem.raw.xml
  sed -i 's/LENGTH/'$LENGTH'/' cint.minrefdem.raw.xml
  let POWID=$WIDTH*8
  sed -i 's/WIDTH/'$WIDTH'/' cint.minrefdem.raw.vrt
  sed -i 's/LENGTH/'$LENGTH'/' cint.minrefdem.raw.vrt
  sed -i 's/POWID/'$POWID'/' cint.minrefdem.raw.vrt
  cp cint.minrefdem.raw.vrt ../.
  mv topophase.flat.xml topophase.flat.xml.bck
  ln -s cint.minrefdem.raw.xml topophase.flat.xml
  cd ..
  #I provide spatial filtering as default...
  topsApp.py --dostep='filter' ../topsApp_coregister_$x'.xml'
  cd merged
  rm topophase.flat.xml
  cp topophase.flat.xml.bck topophase.flat.xml
  mv $SBDIR/$x/cint.minrefdem.raw $SBDIR/$x/cint.minrefdem.raw.orig
  mv filt_topophase.flat $SBDIR/$x/cint.minrefdem.raw
  cpxfiddle -w $WIDTH -M 5/5 -q phase -o sunraster -c jet -f cr4 $SBDIR/$x/cint.minrefdem.raw > $SBDIR/$x/$x'_filtered.ras'
  rm filt_topoph*
 else
  if [ $x == $ORIGMDIR ]; then ln -s topophase.flat resampled.raw; fi
  ln -s `pwd`/resampled.raw $SBDIR/$x/cint.minrefdem.raw
 fi
 cd ../..
done


#put other information there
cp *.1.in small_baselines.list $SBDIR
echo 1 > $SBDIR/slc_osfactor.1.in
echo 0.05546576 > $SBDIR/lambda.1.in
cp $SBDIR/small_baselines.list $SBDIR/ifgday.1.in
cat $SBDIR/width.txt > $SBDIR/pscdem.in
echo $SBDIR/dem.raw >> $SBDIR/pscdem.in
cat $SBDIR/width.txt > $SBDIR/psclonlat.in
echo $SBDIR/lon.raw >> $SBDIR/psclonlat.in
echo $SBDIR/lat.raw >> $SBDIR/psclonlat.in
cat $SBDIR/width.txt > $SBDIR/pscphase.in
ls $SBDIR/*/cint.minrefdem.raw >> $SBDIR/pscphase.in
rm $SBDIR/calamp.in 2>/dev/null
#for x in `cat $SBDIR/day.1.in`; do
ls $SBDIR/*/cint.minrefdem.raw > $SBDIR/calamp.in
#done
cd $SBDIR
calamp calamp.in `cat len.txt` calamp.out
touch sentineloshka_finished
cd $SWATHDIR

