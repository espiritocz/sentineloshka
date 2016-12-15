#!/bin/bash

cat << EOF > do_mask.m
addpath('/home/laz048/WORK/IT4INSAR/shared/matlab/insarmatlab');
len=load('len.txt');
lat=freadbk('lat.raw',len,'float32');
%oh my... so the mask is opposite in stamps!
%means, 1=to be masked, 0=to be used.. foda-se
mask=lat==0;
fid = fopen('mask.ij','wb');
fwrite(fid,mask','integer*1');
fclose(fid);
EOF

octave --eval do_mask -q 2>/dev/null
#matlab -nodesktop -nosplash -r "do_mask;exit" > /dev/null

rm do_mask.m
