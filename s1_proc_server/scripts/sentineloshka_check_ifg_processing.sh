#!/bin/bash
#This is to be started from SWATHDIR, after (incorrect?) s._process_ifg.sh
rm tmp.err 2>/dev/null;
for x in `ls 2*_* -d`; do
 if [ ! -e $x/sentineloshka_finished ]; then echo $x >> tmp.err; fi;
done

for x in `cat tmp.err`; do 
  V=0
  if [ -e $x/topsApp03.err ]; then 
     if [ -e $x/merged ] || [ `ls $x/topsApp03.err -al | gawk {'print $5'}` -eq 0 ]; then
        #try to process it again, but only third step
        echo "Seems that the computation of this ifg didn't finish on time. Let's try again for ifg "$x
        V=3
     else
       if  [ `ls $x/topsApp03.err -al | gawk {'print $5'}` -gt 0 ]; then
        echo "This connection could not be ESD-corrected (low coherence?): "$x
       fi
       echo "This ifg will be removed: "$x
       touch $x/sentineloshka_finished
     fi
  else
   echo "Did we process it? Let's try again, for ifg "$x
   V=1
  fi
  if [ $V -gt 0 ]; then
   U=`echo $x | sed 's/_/ /'`
   sed -i '/sentineloshka_process_ifg/d' qsub_$x'.sh'
   echo "sentineloshka_process_ifg.sh "$U" "$V >> qsub_$x'.sh'
   qsub -q qexp ./qsub_$x'.sh'
  fi
done 2>/dev/null
rm tmp.err 2>/dev/null;

