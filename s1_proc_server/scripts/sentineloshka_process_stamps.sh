#!/bin/bash
#This should be final (?) script to perform stamps pre-processing
IWDIR=`pwd | rev | cut -d '/' -f1 | rev`

cd INSAR*/SMALL*
#tady bylo puvodne cislo 4000000 pod tim sqrt....
octave -q --eval "x=load('width.txt'); y=load('len.txt'); py=y/sqrt(10000000); px=py*x/y; dlmwrite('norg',round(px)); dlmwrite('noazi',round(py))"
echo "Preparing mask (so far based on lon lat = 0 only.. do you need foreshortening filtering?? no prob later..)"
mask_lat0.sh &
calamp calamp.in `cat len.txt` calamp.out
#LAZY_mt_prep 0.6 2 2 100 100
LAZY_mt_prep 0.5 `cat norg` `cat noazi` 100 100

echo "Now we do the parallel processing. It may take some time."
for x in `ls -d PATCH_*`; do
#I have to split it in maximum of 10 patches (more gives error...)
while [ `pidof MATLAB | wc -w` -gt 9 ]; do sleep 10; echo "We reached maximal number of MATLAB instances (10). Sorry, but we have to wait.."; tail -n1 PATCH*/screenout; done
cd $x;
nohup matlab -nodesktop -nosplash -r "getparm; setparm('filter_weighting','SNR');setparm('gamma_change_convergence',0.01);setparm('gamma_max_iterations',6); \
setparm('weed_time_win',530); setparm('clap_win',32); setparm('merge_resample_size',50); setparm('max_topo_err',10); \
setparm('unwrap_time',530); setparm('unwrap_gold_alpha',1);setparm('unwrap_gold_n_win',10); setparm('unwrap_grid',1000); \
setparm('weed_standard_dev',1.25); setparm('dens',20); stamps(1,4);csvwrite('hotowo',1); exit" > screenout 2>&1 &
sleep 10
cd ..;
done
while [ ! -f hotowo ]; do
if [ `ls PATCH*/hotowo 2>/dev/null | wc -l` -eq `ls -d PATCH* | wc -l` ]; then touch hotowo; fi
sleep 8
echo "---PATCHWORK:--"
tail -n1 PATCH*/screenout | grep ":"
echo "---------------"
B=`ls PATCH*/hotowo 2>/dev/null | rev | cut -d '/' -f2 | rev`
if [ ! -z `echo $B | gawk {'print $1'}` ]; then
echo "Processing finished in these patches: "
echo $B; fi
done
rm hotowo



echo "First stage completed - now only unwrapping, filtering, APS,..."

#code to convert look angle to la2 file (thanks to D. Bakeart)
matlab -nodesktop -nosplash -r "stamps(5,5); width = load('width.txt'); ps = load('ps2.mat'); lasavename = 'la2.mat';laname = 'look_angle.raw';fid = fopen(laname,'r'); \
data_la = fread(fid,[width inf],'real*4');fclose(fid);ij = ps.ij; IND = sub2ind(size(data_la),ij(:,3)+1,ij(:,2)+1);clear ij;la=data_la(IND);la = la*pi./180;save(lasavename,'la'); \
setparm('unwrap_hold_good_values','n');stamps(6,6); setparm('unwrap_spatial_cost_func_flag','y'); setparm('subtr_tropo','n'); stamps(7,7); exit"

cp psver.mat ../.
rm *aps* 2>/dev/null
matlab -nodesktop -nosplash -r "aps_linear; setparm('subtr_tropo','y');  setparm('unwrap_spatial_cost_func_flag','n'); stamps(6,7); \
ps_calc_ifg_std;a=load('ifgstd2.mat');setparm('sb_scla_drop_i',find(a.ifg_std>50)'); setparm('unwrap_hold_good_values','y'); \
for u=1:4, u, stamps(6,7); end; \
setparm('scla_deramp','y'); stamps(6,7); stamps(6,6); ps_plot('V-dao','a_l',-1); exit" #load ps_plot_v-dao ph_disp; data= ph_disp; ps_shapefile('vdao.shp',data);exit"



matlab -nodesktop -nosplash -r "LAZY_rsb_update(1); \
setparm('unwrap_hold_good_values','n'); stamps(6,6);aps_linear;stamps(7,7); setparm('unwrap_spatial_cost_func_flag','y'); stamps(6,7); exit"


cat << EOF > LAZY_export_to_csv.m
%if ~exist([pwd filesep 'ps_ij.txt'], 'file') || ~exist([pwd filesep 'ps_ll.txt'], 'file')
    ps_output;
%end
    ij      = load('ps_ij.txt');         % PS radar coord.
    ps_ll   = load('ps_ll.txt');      % PS geographic coord
 %   ps_mean = load('ps_mean_v.xy'); % PS velocities
    load pm2
    load hgt2
load ps_plot_v-dao ph_disp
ps_f    = [ij ps_ll(:,2) ps_ll(:,1) hgt ph_disp coh_ps ];
save(['phy_v-dao.mat'], 'ps_f');
LAZY_stamps2rwt_csv
EOF

matlab -nodesktop -nosplash -r "ps_calc_ifg_std;a=load('ifgstd2.mat');setparm('sb_scla_drop_i',find(a.ifg_std>55)'); \
setparm('unwrap_hold_good_values','y'); setparm('unwrap_spatial_cost_func_flag','n'); for u=1:4, stamps(6,7); end; \
ps_calc_ifg_std;a=load('ifgstd2.mat');setparm('sb_scla_drop_i',find(a.ifg_std>60)'); for u=1:4, stamps(6,7); end; ps_plot('V-dao','a_l',-1); exit"
matlab -nodesktop -nosplash -r "LAZY_export_to_csv; exit"

mv exported*csv ../../../$IWDIR'.csv'
chmod 775 ../../../$IWDIR'.csv'
echo "It seems that everything was smoothly done(!)"
