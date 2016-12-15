#!/bin/bash
#not sure why this happens... but i can correct it this way
#to be run from swathdir
ls -d 2*_* | cut -d '_' -f1 >tmp.tmp
ls -d 2*_* | cut -d '_' -f2 >>tmp.tmp
sort -u tmp.tmp > day.1.in
ls 2*_* -d | sed 's/_/ /' > small_baselines.list
