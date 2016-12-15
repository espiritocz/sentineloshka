function get_la_stamps(insarpath,width)
% function that loads the look angle and los conversion from the ISCE processed data into stamps 
%~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
% Author: David Bekaert
% Organization: Jet Propulsion Laboratory, California Institute of Technology
% Copyright 2016 by the California Institute of Technology.
% ALL RIGHTS RESERVED.
% United States Government Sponsorship acknowledged.
%
% THESE SCRIPTS ARE PROVIDED TO YOU "AS IS" WITH NO WARRANTIES OF CORRECTNESS. USE AT YOUR OWN RISK.
%
% These scripts are not a distribution of the JPL/Caltech ISCE software itself.
% These scripts are open-source contributions and should not be mistaken for official Applications within ISCE.
%~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
%
%

close all
clc


% Getting the file path
if nargin<1 || isempty(insarpath)
    insarpath = pwd;
end
% getting the width
if nargin <2 || isempty(width)
    width_file = [insarpath filesep 'width.txt'];
    if exist(width_file,'file')~=2
        width_file = [insarpath filesep '..' filesep 'width.txt'];
    end
    if exist(width_file,'file')~=2
        error('Specify the width of the file')
    end
    width = load(width_file);
    clear width_file
end


% getting the filename of the look angle and heading angle
load([insarpath filesep 'psver.mat']);
if strcmpi(getparm('small_baseline_flag'),'y')
    laname = [insarpath filesep '..' filesep 'look_angle.raw'];
    ename = [insarpath filesep '..' filesep 'e.raw'];
    nname = [insarpath filesep '..' filesep 'n.raw'];
    uname = [insarpath filesep '..' filesep 'u.raw'];
else
    laname = [insarpath filesep 'look_angle.raw'];
    ename = [insarpath filesep 'e.raw'];
    nname = [insarpath filesep 'n.raw'];
    uname = [insarpath filesep 'u.raw'];
end
ps = load([insarpath filesep  'ps' num2str(psver) '.mat']);
lasavename = [insarpath filesep 'la' num2str(psver) '.mat'];
enusavename = [insarpath filesep 'enu' num2str(psver) '.mat'];
currdir = pwd;



% Get matlab version as function arguments change with the matlab version
matlab_version = version('-release');           % [DB] getting the matlab version
matlab_version = str2num(matlab_version(1:4));  % [DB] the year



% getting the look angle
fid = fopen(laname,'r');
data_la = fread(fid,[width inf],'real*4');
fclose(fid);
% getting the heading angle
fid = fopen(ename,'r');
data_e = fread(fid,[width inf],'real*4');
fclose(fid);
fid = fopen(nname,'r');
data_n = fread(fid,[width inf],'real*4');
fclose(fid);
fid = fopen(uname,'r');
data_u = fread(fid,[width inf],'real*4');
fclose(fid);

% getting the position of the PS
ij = ps.ij;
IND = sub2ind(size(data_la),ij(:,3),ij(:,2));
clear ij

% storing the data
la=data_la(IND);
la = la*pi./180;
east = data_e(IND);
north = data_n(IND);
up = data_u(IND);




%% checking the type of orbit
up_mean = nanmean(up);
east_mean = nanmean(east);
north_mean = nanmean(north);
if up_mean./abs(up_mean)==-1
    up = -1.*up;
    east = -1.*east;
    north = -1.*north;
end

if east_mean./abs(east_mean)==up_mean./abs(up_mean) && north_mean./abs(north_mean)~=up_mean./abs(up_mean)
   fprintf('Looks like descending data \n') 
   mode = 'a';
elseif  east_mean./abs(east_mean)~=up_mean./abs(up_mean) && north_mean./abs(north_mean)~=up_mean./abs(up_mean)
   fprintf('Looks like ascending data \n') 
   mode ='d';
else
    error('Does not look like the sign is right for ascending or descending geometry')
end

%% checkign if the magnitude makes sense
NR =  sub2ind(size(data_la),1,1);
FR =  sub2ind(size(data_la),size(data_la,1),1);
east_NFR = abs(data_e([NR FR]));
north_NFR = abs(data_n([NR FR]));
up_NFR = abs(data_u([NR FR]));
% initialize check_flag to be zero which means as expected
check_flag = 0;
if east_NFR(1)>east_NFR(2)
    check_flag =1;
end
if north_NFR(1)>north_NFR(2)
    check_flag =1;
end
if up_NFR(1)<up_NFR(2)
    check_flag =1;
end
if check_flag==1
    fprintf(['***************Warning!!! check the ENU component does not look right. \n\n'])
end
 
%% plotting the results
xlims = [min(ps.lonlat(:,1)) max(ps.lonlat(:,1))];
ylims = [min(ps.lonlat(:,2)) max(ps.lonlat(:,2))];

ref_radius = getparm('ref_radius');
setparm('ref_radius',-inf)

ps_plot(la.*180./pi);
title('Look angle')
xlim(xlims)
ylim(ylims)

ps_plot(east);
title('East')
xlim(xlims)
ylim(ylims)

ps_plot(north);
title('North')
xlim(xlims)
ylim(ylims)

ps_plot(up);
title('Up')
xlim(xlims)
ylim(ylims)

setparm('ref_radius',ref_radius)

defintion = ' enu2los vectors defined as east, north, and up.\n +u = +los.\n i.e. u2los*U [cm] = LOS [cm], so needs a scaling -4pi/lambda to convert to [rad]\n';
save(lasavename,'la');
save(enusavename,'east','north','up','defintion');



