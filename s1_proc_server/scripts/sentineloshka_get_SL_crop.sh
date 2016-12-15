#!/bin/bash
#module add Octave/3.8.2-intel-2015b
#input is just bounding box.. and the tolerance (normally 0.0001 is the best but slave imgs can have more..)
#to be run from 'merged' folder..
lat1=$1
lat2=$2
lon1=$3
lon2=$4
#bevel=0.0001
bevel=$5
#float=32 or 64
float=$6

LIINES=`head -n1 lat.rdr.full.vrt | rev | cut -d '"' -f2 | rev`
SAMPLES=`head -n1 lat.rdr.full.vrt | cut -d '"' -f2`

#code to convert bounding box to radar coordinates
cat << EOF > octave_get_SL.m
addpath('/home/laz048/WORK/IT4INSAR/shared/matlab/insarmatlab');
lat=freadbk('lat.rdr.full',$LIINES,'float$float');
lon=freadbk('lon.rdr.full',$LIINES,'float$float');
if(max(lat(200,:))-max(lat(size(lat,1)-200))>0)
	%klesa to
	min_i=size(lat,1);
	max_i=1;
	else
	  min_i=1;
	  max_i=size(lat,1);
	endif
if(max(lon(:,200))-max(lon(:,(size(lon,2)-200)))>0)
	%klesa to
	min_j=size(lon,2);
	max_j=1;
	else
	  min_j=1;
	  max_j=size(lon,2);
	endif
[ii, jj] = find(lon > $lon1-$bevel & lon < $lon1+$bevel & lat > $lat1-$bevel & lat < $lat1+$bevel);
if(length(ii)==0)
	 ii=min_i; jj=min_j;
 endif
%[ii, jj] = find(lon > lon1 & lon < lon2 & lat > 49.7939 & lat < 49.7941);
i1=ii(ceil(end/2), :);
j1=jj(ceil(end/2), :);
[ii, jj] = find(lon > $lon2-$bevel & lon < $lon2+$bevel & lat > $lat2-$bevel & lat < $lat2+$bevel);
if(length(ii)==0)
	 ii=max_i; jj=max_j;
 endif
i2=ii(ceil(end/2), :);
j2=jj(ceil(end/2), :);
S1=min([j1 j2])
S2=max([j1 j2])
L1=min([i1 i2])
L2=max([i1 i2])
new_width=S2-S1+1
new_length=L2-L1+1
EOF

octave --eval octave_get_SL -q > cropinfo.txt 2>/dev/null
