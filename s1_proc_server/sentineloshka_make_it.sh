#!/bin/bash
if [ -z $1 ]; then 
 echo "Usage: sentineloshka_make_it.sh PROJNO SWATHDIR"
 echo "e.g. sentineloshka_make_it.sh 1030 relorb_124_iw_1"
 exit
fi
sentineloshka_process_swath.sh $1 $2
