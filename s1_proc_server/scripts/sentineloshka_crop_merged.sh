#!/bin/bash
#module add Octave/3.8.2-intel-2015b
#should be run from the 2*_*/merged folder
outdir=$1
MDIRDIR=$2 #edited: now MDIR should be absolute path!
MDIR=`echo $MDIRDIR | rev | cut -d '/' -f1 | rev`
 S1=`grep S1 $MDIRDIR/merged/cropinfo.txt | gawk {'print $3'}`
 L1=`grep L1 $MDIRDIR/merged/cropinfo.txt | gawk {'print $3'}`
 S2=`grep S2 $MDIRDIR/merged/cropinfo.txt | gawk {'print $3'}`
 L2=`grep L2 $MDIRDIR/merged/cropinfo.txt | gawk {'print $3'}`
 SAMPLES=`head -n1 $MDIRDIR/merged/topophase.flat.full.vrt | cut -d '"' -f2`

#cropping ifgs and making preview using cpxfiddle
if [ -e $outdir ]; then
 cpxfiddle -w $SAMPLES -q normal -f cr4 -o float -p $S1 -P $S2 -l $L1 -L $L2 resampled.raw > $outdir/cint.minrefdem.raw
 cpxfiddle -w $SAMPLES -q phase -M5/5 -f cr4 -o sunraster -c jet -p $S1 -P $S2 -l $L1 -L $L2 resampled.raw | convert - $outdir/`echo $outdir | rev | cut -d '/' -f1 | rev`.png
fi

bsdir=`echo $outdir | rev | cut -c 19- | rev`
if [ `echo $outdir | rev | cut -d '/' -f1 | rev | grep -c $MDIR` -gt 0 ]; then
 #expecting that we are in MDIR folder, cropping also lon, lat, dem,...
 cpxfiddle -w $SAMPLES -q normal -f r4 -o float -p $S1 -P $S2 -l $L1 -L $L2 lat.rdr.full > $bsdir/lat.raw #original latlon files are r8 from ISCE, but.. I crop it..to r4
 cpxfiddle -w $SAMPLES -q normal -f r4 -o float -p $S1 -P $S2 -l $L1 -L $L2 lon.rdr.full > $bsdir/lon.raw
 cpxfiddle -w $SAMPLES -q normal -f r4 -o float -p $S1 -P $S2 -l $L1 -L $L2 z.rdr.full > $bsdir/dem.raw

 #now i have to do both precrop and final crop..
 PRESAMPLES=`head -n1 los.rdr.full.vrt | cut -d '"' -f2`
 if [ ! -e precropinfo.txt ]; then 
  mkdir bck; mv lat.rdr.full lon.rdr.full los.rdr.full lat.rdr.full.vrt bck/.;
  mv lat.rdr.bck lat.rdr.full; mv lon.rdr.bck lon.rdr.full; mv los.rdr.bck los.rdr.full; 
  sed 's/lon/lat/' lon.rdr.full.vrt > lat.rdr.full.vrt; mv cropinfo.txt cropinfo.txt.bck;
  sentineloshka_get_SL_crop.sh `cat ../../../bounding_box.txt | sed 's/,/ /g'` 0.001 64
  mv cropinfo.txt precropinfo.txt;
  mv cropinfo.txt.bck cropinfo.txt
  mv lat.rdr.full lat.rdr.bck; mv lon.rdr.full lon.rdr.bck
  cd bck; mv lat.rdr.full lon.rdr.full lat.rdr.full.vrt ../.; cd ..
 fi
 PRES1=`grep S1 precropinfo.txt | gawk {'print $3'}`
 PREL1=`grep L1 precropinfo.txt | gawk {'print $3'}`
 PRES2=`grep S2 precropinfo.txt | gawk {'print $3'}`
 PREL2=`grep L2 precropinfo.txt | gawk {'print $3'}`
 imageMath.py -e="a_0" --a=los.rdr.full -o los.tmp.pre -s BIL
 cpxfiddle -w $PRESAMPLES -q normal -f r4 -o float -p $PRES1 -P $PRES2 -l $PREL1 -L $PREL2 los.tmp.pre > los.tmp
 cpxfiddle -w $SAMPLES -q normal -f r4 -o float -p $S1 -P $S2 -l $L1 -L $L2 los.tmp > $bsdir/look_angle.raw
 imageMath.py -e="-1*a_1-270" --a=los.rdr.full -o heading.tmp -s BIL
 get_mean_isce.py heading.tmp | tail -n1 > $bsdir/heading.1.in
 imageMath.py --eval='sin(rad(a_0))*cos(rad(a_1+90))' --a=los.rdr.full -t FLOAT -s BIL -o e.tmp
 cpxfiddle -w $PRESAMPLES -q normal -f r4 -o float -p $PRES1 -P	$PRES2 -l $PREL1 -L $PREL2 e.tmp > los.tmp
 cpxfiddle -w $SAMPLES -q normal -f r4 -o float -p $S1 -P $S2 -l $L1 -L $L2 los.tmp > $bsdir/e.raw
 imageMath.py --eval='sin(rad(a_0)) * sin(rad(a_1+90))' --a=los.rdr.full -t FLOAT -s BIL -o n.tmp
 cpxfiddle -w $PRESAMPLES -q normal -f r4 -o float -p $PRES1 -P	$PRES2 -l $PREL1 -L $PREL2 n.tmp > los.tmp
 cpxfiddle -w $SAMPLES -q normal -f r4 -o float -p $S1 -P $S2 -l $L1 -L $L2 los.tmp > $bsdir/n.raw
 imageMath.py --eval='cos(rad(a_0))' --a=los.rdr.full -t FLOAT -s BIL -o u.tmp
 cpxfiddle -w $PRESAMPLES -q normal -f r4 -o float -p $PRES1 -P	$PRES2 -l $PREL1 -L $PREL2 u.tmp > los.tmp
 cpxfiddle -w $SAMPLES -q normal -f r4 -o float -p $S1 -P $S2 -l $L1 -L $L2 los.tmp > $bsdir/u.raw
 rm los.tmp* heading.tmp* e.tmp* n.tmp* u.tmp*
fi
