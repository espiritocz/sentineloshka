#!/bin/bash
if [ -z $4 ]; then 
echo "Usage: sentineloshka_make_it.sh lat1 lat2 lon1 lon2"
echo "as in S N W E"
echo "e.g. sentineloshka_make_it.sh 49.25 49.49 18.15 18.38"
exit
fi
source ~/sentineloshka_db_vars
sentineloshka_prepare_crops.sh $1 $2 $3 $4 sb 2>/dev/null
