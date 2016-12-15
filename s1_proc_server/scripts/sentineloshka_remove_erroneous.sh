#!/bin/bash
#remove erroneous combinations from processing
#and... create small_baselines.list file (maybe should be in previous script?)
#must be run from the swath project folder
ls 2*_* -d > check
ls 2*_*/merged/resampled.raw | cut -d '/' -f1 > check.ok 2>/dev/null
diff check check.ok | grep '<' | gawk {'print $2'} > check.err

cat check.err

mkdir ERRORS 2>/dev/null
for x in `cat check.err`; do mv $x ERRORS/.; done

sed 's/_/ /' check.ok > small_baselines.list
for x in `cat day.1.in`; do
 if [ `grep -c $x small_baselines.list` -eq 0 ]; then sed -i '/'$x'/d' day.1.in; fi
done
