#!/bin/bash
TEMPLATES=~/.SENTINELOSHKA/templates
MDIR=$1
SDIR=$2

#Preparing the files
cp $MDIR/master.xml $SDIR/merged/.
cp $MDIR/merged/topophase.flat.full.vrt $SDIR/merged/master.vrt
cp $SDIR/master.xml $SDIR/merged/slave.xml
cd $SDIR/merged
WDIR=`pwd`
cp topophase.flat.full.vrt slave.vrt
echo $WDIR | sed 's/\//\\\//g' | sed 's/\./\\\./' > tmp.tmp
SUB=`cat tmp.tmp`; rm tmp.tmp

#Converting into doris format: master and slave
####
#creating template .res file
cat << EOF > tmp.res
Start_process_control
readfiles:              1
precise_orbits:         1
modify_orbits:          0
crop:                   1
sim_amplitude:          0
master_timing:          0
oversample:             0
resample:               0
filt_azi:               0
filt_range:             0
NOT_USED:               0
End_process_control
*******************************************************************
*_Start_readfiles:
******
RADAR_FREQUENCY (HZ):         5405000454          
Radar_wavelength (m):              0.05546576
Pulse_Repetition_Frequency (computed, Hz):      PULSEREP
*******************************************************************
* End_readfiles:_NORMAL
****
*_Start_crop:
****
Data_output_file:  CONNPATH/FILENAME
Data_output_format:     complex_real4
First_line (w.r.t. original_image):             1
Last_line (w.r.t. original_image):  LENGTH
First_pixel (w.r.t. original_image):            1
Last_pixel (w.r.t. original_image):   WIDTH
Number of lines (non-multilooked):              LENGTH
Number of pixels (non-multilooked):             WIDTH
******
* End_crop:_NORMAL
*******************************************************************
*_Start_precise_orbits:
****
        t(s)    X(m)    Y(m)    Z(m)
NUMBER_OF_DATAPOINTS:                   NUMBERORBITS
EOF

#Filling the temp into res files
for x in master slave; do
 out=$x'.res'
 file=$x'.xml'
 cp tmp.res $out
 LENGTH=`head -n1 $x.vrt | rev | cut -d '"' -f2 | rev`
 WIDTH=`head -n1 $x.vrt | cut -d '"' -f2`

 sed -i 's/PULSEREP/'`grep -A1 pulserepetitionfrequency $file | tail -n1 | cut -d '>' -f2 | cut -d '<' -f1`'/' $out
 sed -i 's/FILENAME/'$x'.raw/' $out
 sed -i 's/WIDTH/'$WIDTH'/' $out
 sed -i 's/LENGTH/'$LENGTH'/' $out
 sed -i 's/CONNPATH/'$SUB'/' $out

 #extracting orbits (valid only for one burst.. but it should be ok for resampling..i hope)
 numberorbits=`grep 'name="statevector' $file | sort -u | wc -l`
 sed -i 's/NUMBERORBITS/'$numberorbits'/' $out
 for i in $(seq 1 $numberorbits); do
   POS=`grep -A 15 'name="statevector'$i $file | grep position -A1 |  head -n2 | tail -n1 | cut -d '[' -f2 | cut -d ']' -f1`
   TIME=`grep -A 17 'name="statevector'$i $file | grep time -A1 |  head -n2 | tail -n1 | cut -d '>' -f2 | cut -d '<' -f1 | gawk {'print $2'}`
   let SECONDS=`echo $TIME | cut -d ':' -f3 | sed 's/^0//'`+`echo $TIME | cut -d ':' -f2 | sed 's/^0//'`*60+`echo $TIME | cut -d ':' -f1 | sed 's/^0//'`*60*60
   echo $SECONDS `echo $POS | cut -d ',' -f1``echo $POS | cut -d ',' -f2``echo $POS | cut -d ',' -f3` >> $out
 done
 echo "************************" >> $out
 echo "* End_precise_orbits:_NORMAL" >> $out
 echo "**" >> $out
done

MLINES=`head -n1 master.vrt | rev | cut -d '"' -f2 | rev`
MSAMPLES=`head -n1 master.vrt | cut -d '"' -f2`

#Preparing coreg.dorisin template
cp $TEMPLATES/coreg.dorisin .
sed -i 's/WIDTH/'$MSAMPLES'/' coreg.dorisin
sed -i 's/LENGTH/'$MLINES'/' coreg.dorisin
sed -i 's/CONNPATH/'$SUB'/' coreg.dorisin
ln -s ../../$MDIR/merged/topophase.flat.full master.raw
ln -s topophase.flat.full slave.raw

cd ../..
