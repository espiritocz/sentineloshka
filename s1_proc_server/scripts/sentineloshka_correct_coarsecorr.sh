#!/bin/bash
#This is to correct the horribly evaluated overall estimation of COARSECORR in doris (blame you guys)
#input parameter is ifg folder
x=$1
grep Start_coarse -A 56 $x/merged/coreg.out | tail -n +9 | gawk {'print $5'} > $x/merged/tmp.L
grep Start_coarse -A 56 $x/merged/coreg.out | tail -n +9 | gawk {'print $6'} > $x/merged/tmp.S
NEWL=`octave -q --eval "a=load('"$x"/merged/tmp.L'); median(a)" | gawk {'print $3'}`
NEWS=`octave -q --eval "a=load('"$x"/merged/tmp.S'); median(a)" | gawk {'print $3'}`
sed -i 's/Coarse_correlation_translation_lines.*/Coarse_correlation_translation_lines:   '$NEWL'/' $x/merged/coreg.out
sed -i 's/Coarse_correlation_translation_pixels.*/Coarse_correlation_translation_pixels:   '$NEWS'/' $x/merged/coreg.out
sed -i 's/Estimated total offset.*/Estimated total offset (l,p): 	'$NEWL', '$NEWS'/' $x/merged/log.out
rm $x/merged/tmp.S $x/merged/tmp.L
