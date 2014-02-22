function mergegui
% MERGEGUI Interactive merging of layer picks from consecutive, overlapping radar data blocks.
%   
%   MERGEGUI loads a GUI for merging a transect's radar layers traced
%   previously for individual blocks using PICKGUI. Refer to manual for
%   operation (pickgui_man.pdf).
%   
%   MERGEGUI requires that the functions TOPOCORR AND SMOOTH_LOWESS be
%   available within the user's path. If the Parallel Computing Toolbox is
%   licensed and available, then several calculations related to data
%   flattening will be parallelized. The Mapping Toolbox is necessary to
%   plot a map of the transect location.
% 
% Joe MacGregor (UTIG)
% Last updated: 02/22/14

if ~exist('topocorr', 'file')
    error('mergegui:topocorr', 'Necessary function TOPOCORR is not available within this user''s path.')
end
if ~exist('smooth_lowess', 'file')
    error('mergegui:smoothlowess', 'Necessary function SMOOTH_LOWESS is not available within this user''s path.')
end

%% Intialize variables

pk                          = struct;

% elevation/depth/distance/dB defaults
[elev_min_ref, elev_max_ref]= deal(0, 1);
[elev_min, elev_max]        = deal(elev_min_ref, elev_max_ref);
[depth_min, depth_min_ref]  = deal(elev_min_ref);
[depth_max, depth_max_ref]  = deal(elev_max_ref);
[dist_min_ref, dist_max_ref]= deal(0, 1);
[dist_min, dist_max]        = deal(dist_min_ref, dist_max_ref);
[db_min_ref, db_max_ref]    = deal(-130, 0);
[db_min, db_max]            = deal(-80, -20);
[age_min_ref, age_max_ref]  = deal(0, 130);
[age_min, age_max]          = deal(age_min_ref, age_max_ref);

% more default values
speed_vacuum                = 299792458; % speed of light in the vacuum, m/s
permitt_ice                 = 3.15; % standard CReSIS permittivity for Greenland
speed_ice                   = speed_vacuum / sqrt(permitt_ice);
decim                       = 10; % decimate radargram for display
length_chunk                = 100; % chunk length in km
disp_type                   = 'elev.';
ord_poly                    = 3; % default polynomial order
cmaps                       = {'bone' 'jet'}';
var_cell                    = {'ind_match' 'file_in' 'file_pk' 'file_block'}; % cell variables that are easy to merge
var_zero                    = {'freq' 'length_smooth' 'num_sample' 'num_trace' 'twtt_match' 'ind_trace_start' 'num_layer_block'};
num_cell                    = length(var_cell);
num_zero                    = length(var_zero);
var_layer                   = {'ind_y' 'twtt' 'twtt_ice' 'int' 'ind_y_smooth' 'twtt_smooth' 'twtt_ice_smooth' 'int_smooth' 'depth' 'depth_smooth' 'elev' 'elev_smooth'}; % layer variables
var_layer_gimp              = {'elev_gimp' 'elev_smooth_gimp'}; % layer variables
var_pos                     = {'dist' 'lat' 'lon' 'x' 'y' 'elev_air' 'twtt_surf' 'elev_surf' 'twtt_bed' 'elev_bed'}; % position variables
var_pos_gimp                = {'dist_gimp' 'x_gimp' 'y_gimp' 'elev_air_gimp' 'elev_surf_gimp' 'elev_bed_gimp'}; % position variables
num_var_layer               = length(var_layer);
num_var_layer_gimp          = length(var_layer_gimp);
num_var_pos                 = length(var_pos);
num_var_pos_gimp            = length(var_pos_gimp);
colors_def                  = [0    0       0.75;
                               0    0       1;
                               0    0.25    1;
                               0    0.50    1;
                               0    0.75    1;
                               0    1       1;
                               0.25 1       0.75;
                               0.50 1       0.50;
                               0.75 1       0.25;
                               1    1       0;
                               1    0.75    0;
                               1    0.50    0;
                               1    0.25    0;
                               1    0       0;
                               0.75 0       0];
letters                     = 'a':'z';

% allocate a bunch of variables
[age_done, bed_avail, core_done, data_done, edit_flag, flat_done, gimp_avail, merge_done, merge_file, surf_avail] ...
                            = deal(false);
[age, age_curr, amp_depth, amp_elev, amp_flat, button, colors, colors_age, curr_chunk, curr_layer, curr_subtrans, curr_trans, curr_year, depth, depth_bed, depth_bed_flat, depth_curr, depth_flat, depth_layer_flat, depth_layer_ref, depth_mat, dist_chunk, dt, elev, ii, ind_decim, ind_int, ...
 ind_x_pk, ind_x_ref, ind_y_pk, int_core, jj, kk, name_core, name_trans, num_chunk, num_core, num_data, num_decim, num_int, num_pk, num_sample, num_trans, num_year, p_bed, p_beddepth, p_bedflat, p_block, p_blockflat, p_blocknum, p_blocknumflat, p_core, p_coreflat, p_corename, p_corenameflat, ...
 p_data, pk_all, p_pk, p_pkdepth, p_pkflat, p_snr, p_surf, pkfig, p_refflat, rad_threshold, snr_all, snrgui, snrlist, tmp1, tmp2, tmp3, tmp4, tmp5, twtt] ...
                            = deal(0);
[file_age, file_data, file_core, file_pk, file_pk_short, file_save, file_snr, path_age, path_core, path_data, path_pk, path_save, path_snr] ...
                            = deal('');
layer_str                   = {};
cb_type                     = 'std';

if license('checkout', 'distrib_computing_toolbox')
    if ~matlabpool('size')
        matlabpool open
    end
    parallel_check          = true;
else
    parallel_check          = false;
end

if ispc
    if exist('\\melt\icebridge\data\mat\grl_coast.mat', 'file')
        load('\\melt\icebridge\data\mat\grl_coast', 'num_coast', 'x_coast_gimp', 'y_coast_gimp')
    end
else
    if exist('mat/grl_coast.mat', 'file')
        load('mat/grl_coast', 'num_coast', 'x_coast_gimp', 'y_coast_gimp')
    end
end

%% draw GUI

set(0, 'DefaultFigureWindowStyle', 'docked')
if ispc % windows switch
    mgui                    = figure('toolbar', 'figure', 'name', 'MERGEGUI', 'position', [1920 940 1 1], 'menubar', 'none', 'keypressfcn', @keypress, 'windowscrollwheelfcn', @wheel_zoom, 'windowbuttondownfcn', @mouse_click);
    ax_radar                = subplot('position', [0.065 0.06 1.42 0.81]);
    size_font               = 14;
    width_slide             = 0.01;
else
    mgui                    = figure('toolbar', 'figure', 'name', 'MERGEGUI', 'position', [1864 1100 1 1], 'menubar', 'none', 'keypressfcn', @keypress, 'windowscrollwheelfcn', @wheel_zoom, 'windowbuttondownfcn', @mouse_click);
    ax_radar                = subplot('position', [0.065 0.06 0.86 0.81]);
    size_font               = 18;
    width_slide             = 0.02;
end

hold on
colormap(bone)
caxis([db_min db_max])
axis xy tight
set(gca, 'fontsize', size_font, 'layer', 'top')
xlabel('Distance (km)')
yl                          = ylabel('Elevation (m)');
colorbar('fontsize', size_font)
box on
% pan/zoom callbacks
h_pan                       = pan;
set(h_pan, 'actionpostcallback', @panzoom)
h_zoom                      = zoom;
set(h_zoom, 'actionpostcallback', @panzoom)

% sliders
z_min_slide                 = uicontrol(mgui, 'style', 'slider', 'units', 'normalized', 'position', [0.005 0.07 width_slide 0.32], 'callback', @slide_z_min, 'min', 0, 'max', 1, 'value', elev_min_ref, 'sliderstep', [0.01 0.1]);
z_max_slide                 = uicontrol(mgui, 'style', 'slider', 'units', 'normalized', 'position', [0.005 0.50 width_slide 0.32], 'callback', @slide_z_max, 'min', 0, 'max', 1, 'value', elev_max_ref, 'sliderstep', [0.01 0.1]);
cb_min_slide                = uicontrol(mgui, 'style', 'slider', 'units', 'normalized', 'position', [0.96 0.07 width_slide 0.32], 'callback', @slide_cb_min, 'min', db_min_ref, 'max', db_max_ref, 'value', db_min_ref, 'sliderstep', [0.01 0.1]);
cb_max_slide                = uicontrol(mgui, 'style', 'slider', 'units', 'normalized', 'position', [0.96 0.50 width_slide 0.32], 'callback', @slide_cb_max, 'min', db_min_ref, 'max', db_max_ref, 'value', db_max_ref, 'sliderstep', [0.01 0.1]);
dist_min_slide              = uicontrol(mgui, 'style', 'slider', 'units', 'normalized', 'position', [0.12 0.005 0.27 0.02], 'callback', @slide_dist_min, 'min', 0, 'max', 1, 'value', dist_min_ref, 'sliderstep', [0.01 0.1]);
dist_max_slide              = uicontrol(mgui, 'style', 'slider', 'units', 'normalized', 'position', [0.64 0.005 0.27 0.02], 'callback', @slide_dist_max, 'min', 0, 'max', 1, 'value', dist_max_ref, 'sliderstep', [0.01 0.1]);
% slider values
z_min_edit                  = annotation('textbox', [0.005 0.39 0.04 0.03], 'string', num2str(elev_min_ref), 'fontsize', size_font, 'color', 'k', 'edgecolor', 'none');
z_max_edit                  = annotation('textbox', [0.005 0.82 0.04 0.03], 'string', num2str(elev_max_ref), 'fontsize', size_font, 'color', 'k', 'edgecolor', 'none');
cb_min_edit                 = annotation('textbox', [0.965 0.39 0.04 0.03], 'string', num2str(db_min_ref), 'fontsize', size_font, 'color', 'k', 'edgecolor', 'none');
cb_max_edit                 = annotation('textbox', [0.9665 0.82 0.04 0.03], 'string', num2str(db_max_ref), 'fontsize', size_font, 'color', 'k', 'edgecolor', 'none');
dist_min_edit               = annotation('textbox', [0.08 0.005 0.04 0.03], 'string', num2str(dist_min_ref), 'fontsize', size_font, 'color', 'k', 'edgecolor', 'none');
dist_max_edit               = annotation('textbox', [0.59 0.005 0.04 0.03], 'string', num2str(dist_max_ref), 'fontsize', size_font, 'color', 'k', 'edgecolor', 'none');

% push buttons
uicontrol(mgui, 'style', 'pushbutton', 'string', 'Load picks', 'units', 'normalized', 'position', [0.005 0.965 0.07 0.03], 'callback', @load_pk, 'fontsize', size_font, 'foregroundcolor', 'b')
uicontrol(mgui, 'style', 'pushbutton', 'string', 'Load radar data', 'units', 'normalized', 'position', [0.30 0.965 0.09 0.03], 'callback', @load_data, 'fontsize', size_font, 'foregroundcolor', 'b')
uicontrol(mgui, 'style', 'pushbutton', 'string', 'Load core intersections', 'units', 'normalized', 'position', [0.64 0.925 0.11 0.03], 'callback', @load_core, 'fontsize', size_font, 'foregroundcolor', 'b')
uicontrol(mgui, 'style', 'pushbutton', 'string', 'Flatten data', 'units', 'normalized', 'position', [0.30 0.885 0.09 0.03], 'callback', @flatten, 'fontsize', size_font, 'foregroundcolor', 'm')
uicontrol(mgui, 'style', 'pushbutton', 'string', 'Focus', 'units', 'normalized', 'position', [0.41 0.925 0.05 0.03], 'callback', @pk_focus, 'fontsize', size_font, 'foregroundcolor', 'm')
uicontrol(mgui, 'style', 'pushbutton', 'string', 'Select', 'units', 'normalized', 'position', [0.41 0.885 0.04 0.03], 'callback', @pk_select_gui, 'fontsize', size_font, 'foregroundcolor', 'm')
uicontrol(mgui, 'style', 'pushbutton', 'string', 'Last', 'units', 'normalized', 'position', [0.46 0.885 0.04 0.03], 'callback', @pk_last, 'fontsize', size_font, 'foregroundcolor', 'm')
uicontrol(mgui, 'style', 'pushbutton', 'string', 'Next', 'units', 'normalized', 'position', [0.46 0.925 0.04 0.03], 'callback', @pk_next, 'fontsize', size_font, 'foregroundcolor', 'm')
uicontrol(mgui, 'style', 'pushbutton', 'string', 'Load ages', 'units', 'normalized', 'position', [0.64 0.885 0.07 0.03], 'callback', @load_age, 'fontsize', size_font, 'foregroundcolor', 'b')
uicontrol(mgui, 'style', 'pushbutton', 'string', 'Merge layers', 'units', 'normalized', 'position', [0.505 0.965 0.07 0.03], 'callback', @pk_merge, 'fontsize', size_font, 'foregroundcolor', 'm')
uicontrol(mgui, 'style', 'pushbutton', 'string', 'Split layer', 'units', 'normalized', 'position', [0.505 0.925 0.07 0.03], 'callback', @pk_split, 'fontsize', size_font, 'foregroundcolor', 'm')
uicontrol(mgui, 'style', 'pushbutton', 'string', 'Delete layer', 'units', 'normalized', 'position', [0.505 0.885 0.07 0.03], 'callback', @pk_del, 'fontsize', size_font, 'foregroundcolor', 'r')
uicontrol(mgui, 'style', 'pushbutton', 'string', 'Test', 'units', 'normalized', 'position', [0.59 0.965 0.04 0.03], 'callback', @misctest, 'fontsize', size_font, 'foregroundcolor', 'r')
uicontrol(mgui, 'style', 'pushbutton', 'string', 'SNR', 'units', 'normalized', 'position', [0.59 0.925 0.04 0.03], 'callback', @snr, 'fontsize', size_font, 'foregroundcolor', 'b')
uicontrol(mgui, 'style', 'pushbutton', 'string', 'Map', 'units', 'normalized', 'position', [0.865 0.925 0.03 0.03], 'callback', @pop_map, 'fontsize', size_font, 'foregroundcolor', 'g')
uicontrol(mgui, 'style', 'pushbutton', 'string', 'Pop figure', 'units', 'normalized', 'position', [0.90 0.925 0.06 0.03], 'callback', @pop_fig, 'fontsize', size_font, 'foregroundcolor', 'g')
uicontrol(mgui, 'style', 'pushbutton', 'string', 'Save', 'units', 'normalized', 'position', [0.965 0.925 0.03 0.03], 'callback', @pk_save, 'fontsize', size_font, 'foregroundcolor', 'g')
uicontrol(mgui, 'style', 'pushbutton', 'string', 'Reset x/y', 'units', 'normalized', 'position', [0.945 0.885 0.05 0.03], 'callback', @reset_xz, 'fontsize', size_font, 'foregroundcolor', 'r')
uicontrol(mgui, 'style', 'pushbutton', 'string', 'Reset', 'units', 'normalized', 'position', [0.005 0.03 0.03 0.03], 'callback', @reset_z_min, 'fontsize', size_font, 'foregroundcolor', 'r')
uicontrol(mgui, 'style', 'pushbutton', 'string', 'Reset', 'units', 'normalized', 'position', [0.005 0.46 0.03 0.03], 'callback', @reset_z_max, 'fontsize', size_font, 'foregroundcolor', 'r')
uicontrol(mgui, 'style', 'pushbutton', 'string', 'Reset', 'units', 'normalized', 'position', [0.40 0.005 0.03 0.03], 'callback', @reset_dist_min, 'fontsize', size_font, 'foregroundcolor', 'r')
uicontrol(mgui, 'style', 'pushbutton', 'string', 'Reset', 'units', 'normalized', 'position', [0.92 0.005 0.03 0.03], 'callback', @reset_dist_max, 'fontsize', size_font, 'foregroundcolor', 'r')
uicontrol(mgui, 'style', 'pushbutton', 'string', 'Reset', 'units', 'normalized', 'position', [0.965 0.03 0.03 0.03], 'callback', @reset_cb_min, 'fontsize', size_font, 'foregroundcolor', 'r')
uicontrol(mgui, 'style', 'pushbutton', 'string', 'Reset', 'units', 'normalized', 'position', [0.965 0.46 0.03 0.03], 'callback', @reset_cb_max, 'fontsize', size_font, 'foregroundcolor', 'r')

% fixed text annotations
a(1)                        = annotation('textbox', [0.13 0.965 0.03 0.03], 'string', 'N_{decimate}', 'fontsize', size_font, 'color', 'b', 'edgecolor', 'none');
a(2)                        = annotation('textbox', [0.21 0.965 0.03 0.03], 'string', 'Chunk', 'fontsize', size_font, 'color', 'b', 'edgecolor', 'none');
a(3)                        = annotation('textbox', [0.21 0.925 0.03 0.03], 'string', 'L_{chunk}', 'fontsize', size_font, 'color', 'b', 'edgecolor', 'none');
a(4)                        = annotation('textbox', [0.41 0.965 0.03 0.03], 'string', 'Layer', 'fontsize', size_font, 'color', 'm', 'edgecolor', 'none');
a(5)                        = annotation('textbox', [0.85 0.885 0.03 0.03], 'string', 'Grid', 'fontsize', size_font, 'color', 'k', 'edgecolor', 'none');
a(6)                        = annotation('textbox', [0.005 0.42 0.03 0.03], 'string', 'z_{min}', 'fontsize', size_font, 'color', 'k', 'edgecolor', 'none');
a(7)                        = annotation('textbox', [0.005 0.85 0.03 0.03], 'string', 'z_{max}', 'fontsize', size_font, 'color', 'k', 'edgecolor', 'none');
a(8)                        = annotation('textbox', [0.04 0.005 0.03 0.03], 'string', 'dist_{min}', 'fontsize', size_font, 'color', 'k', 'edgecolor', 'none');
a(9)                        = annotation('textbox', [0.55 0.005 0.03 0.03], 'string', 'dist_{max}', 'fontsize', size_font, 'color', 'k', 'edgecolor', 'none');
a(10)                       = annotation('textbox', [0.025 0.85 0.03 0.03], 'string', 'fix', 'fontsize', size_font, 'color', 'k', 'edgecolor', 'none');
a(11)                       = annotation('textbox', [0.005 0.005 0.03 0.03], 'string', 'fix', 'fontsize', size_font, 'color', 'k', 'edgecolor', 'none');
a(12)                       = annotation('textbox', [0.95 0.005 0.03 0.03], 'string', 'fix 1', 'fontsize', size_font, 'color', 'k', 'edgecolor', 'none');
a(13)                       = annotation('textbox', [0.98 0.005 0.03 0.03], 'string', '2', 'fontsize', size_font, 'color', 'k', 'edgecolor', 'none');
a(14)                       = annotation('textbox', [0.31 0.925 0.10 0.03], 'string', 'block divisions', 'fontsize', size_font, 'color', 'k', 'edgecolor', 'none');
if ~ispc
    set(a, 'fontweight', 'bold')
end

% variable text annotations
file_box                    = annotation('textbox', [0.005 0.925 0.20 0.03], 'string', '', 'color', 'k', 'fontsize', size_font, 'backgroundcolor', 'w', 'edgecolor', 'k', 'interpreter', 'none');
status_box                  = annotation('textbox', [0.64 0.965 0.35 0.03], 'string', '', 'color', 'k', 'fontsize', size_font, 'backgroundcolor', 'w', 'edgecolor', 'k', 'interpreter', 'none');
cbl                         = annotation('textbox', [0.93 0.03 0.03 0.03], 'string', '(dB)', 'fontsize', size_font, 'color', 'k', 'edgecolor', 'none');
if ~ispc
    set(cbl, 'fontweight', 'bold')
end
cbl_min                     = annotation('textbox', [0.965 0.42 0.03 0.03], 'string', 'dB_{min}', 'fontsize', size_font, 'color', 'k', 'edgecolor', 'none');
cbl_max                     = annotation('textbox', [0.965 0.85 0.03 0.03], 'string', 'dB_{max}', 'fontsize', size_font, 'color', 'k', 'edgecolor', 'none');

% value boxes
decim_edit                  = uicontrol(mgui, 'style', 'edit', 'string', num2str(decim), 'units', 'normalized', 'position', [0.175 0.965 0.03 0.03], 'fontsize', size_font, 'foregroundcolor', 'k', 'backgroundcolor', 'w', 'callback', @adj_decim);
length_chunk_edit           = uicontrol(mgui, 'style', 'edit', 'string', num2str(length_chunk), 'units', 'normalized', 'position', [0.25 0.925 0.04 0.03], 'fontsize', size_font, 'foregroundcolor', 'k', 'backgroundcolor', 'w', 'callback', @adj_length_chunk);
% menus
chunk_list                  = uicontrol(mgui, 'style', 'popupmenu', 'string', 'N/A', 'value', 1, 'units', 'normalized', 'position', [0.25 0.955 0.045 0.04], 'fontsize', size_font, 'foregroundcolor', 'k', 'callback', @plot_chunk);
cmap_list                   = uicontrol(mgui, 'style', 'popupmenu', 'string', cmaps, 'value', 1, 'units', 'normalized', 'position', [0.89 0.865 0.05 0.05], 'callback', @change_cmap, 'fontsize', size_font);
layer_list                  = uicontrol(mgui, 'style', 'popupmenu', 'string', 'N/A', 'value', 1, 'units', 'normalized', 'position', [0.45 0.955 0.05 0.04], 'fontsize', size_font, 'foregroundcolor', 'k', 'callback', @pk_select);
block_list                  = uicontrol(mgui, 'style', 'popupmenu', 'string', 'N/A', 'value', 1, 'units', 'normalized', 'position', [0.16 0.865 0.135 0.05], 'fontsize', size_font, 'foregroundcolor', 'k');

% check boxes
zfix_check                  = uicontrol(mgui, 'style', 'checkbox', 'units', 'normalized', 'position', [0.04 0.85 0.01 0.02], 'fontsize', size_font, 'value', 0, 'backgroundcolor', get(mgui, 'color'));
distfix_check               = uicontrol(mgui, 'style', 'checkbox', 'units', 'normalized', 'position', [0.02 0.005 0.01 0.02], 'fontsize', size_font, 'value', 0, 'backgroundcolor', get(mgui, 'color'));
cbfix_check1                = uicontrol(mgui, 'style', 'checkbox', 'units', 'normalized', 'position', [0.97 0.005 0.01 0.02], 'fontsize', size_font, 'value', 0, 'backgroundcolor', get(mgui, 'color'));
cbfix_check2                = uicontrol(mgui, 'style', 'checkbox', 'units', 'normalized', 'position', [0.985 0.005 0.01 0.02], 'callback', @narrow_cb, 'fontsize', size_font, 'value', 1, 'backgroundcolor', get(mgui, 'color'));
grid_check                  = uicontrol(mgui, 'style', 'checkbox', 'units', 'normalized', 'position', [0.88 0.885 0.01 0.02], 'callback', @toggle_grid, 'fontsize', size_font, 'value', 0, 'backgroundcolor', get(mgui, 'color'));
pk_check                    = uicontrol(mgui, 'style', 'checkbox', 'units', 'normalized', 'position', [0.08 0.965 0.01 0.02], 'callback', @show_pk, 'fontsize', size_font, 'value', 0, 'backgroundcolor', get(mgui, 'color'));
data_check                  = uicontrol(mgui, 'style', 'checkbox', 'units', 'normalized', 'position', [0.395 0.965 0.01 0.02], 'callback', @show_data, 'fontsize', size_font, 'value', 0, 'backgroundcolor', get(mgui, 'color'));
block_check                 = uicontrol(mgui, 'style', 'checkbox', 'units', 'normalized', 'position', [0.395 0.925 0.01 0.02], 'callback', @show_block, 'fontsize', size_font, 'value', 0, 'backgroundcolor', get(mgui, 'color'));
core_check                  = uicontrol(mgui, 'style', 'checkbox', 'units', 'normalized', 'position', [0.75 0.925 0.01 0.02], 'callback', @show_core, 'fontsize', size_font, 'value', 0, 'backgroundcolor', get(mgui, 'color'));

% display buttons
disp_group                  = uibuttongroup('position', [0.005 0.885 0.15 0.03], 'selectionchangefcn', @disp_radio);
uicontrol(mgui, 'style', 'text', 'parent', disp_group, 'units', 'normalized', 'position', [0 0.6 0.9 0.3], 'fontsize', size_font)
disp_check(1)               = uicontrol(mgui, 'style', 'radio', 'string', 'elev.', 'units', 'normalized', 'position', [0.01 0.1 0.25 0.8], 'parent', disp_group, 'fontsize', size_font, 'handlevisibility', 'off');
disp_check(2)               = uicontrol(mgui, 'style', 'radio', 'string', 'depth', 'units', 'normalized', 'position', [0.3 0.1 0.3 0.8], 'parent', disp_group, 'fontsize', size_font, 'handlevisibility', 'off');
disp_check(3)               = uicontrol(mgui, 'style', 'radio', 'string', 'flat', 'units', 'normalized', 'position', [0.65 0.1 0.3 0.8], 'parent', disp_group, 'fontsize', size_font, 'handlevisibility', 'off');
set(disp_group, 'selectedobject', disp_check(1))

% colorscale buttons
cb_group                    = uibuttongroup('position', [0.72 0.885 0.075 0.03], 'selectionchangefcn', @cb_radio);
uicontrol(mgui, 'style', 'text', 'parent', cb_group, 'units', 'normalized', 'position', [0 0.6 0.9 0.3], 'fontsize', size_font)
cb_check(1)                 = uicontrol(mgui, 'style', 'radio', 'string', 'std', 'units', 'normalized', 'position', [0.01 0.1 0.45 0.8], 'parent', cb_group, 'fontsize', size_font, 'handlevisibility', 'off');
cb_check(2)                 = uicontrol(mgui, 'style', 'radio', 'string', 'age', 'units', 'normalized', 'position', [0.51 0.1 0.45 0.8], 'parent', cb_group, 'fontsize', size_font, 'handlevisibility', 'off');
set(cb_group, 'selectedobject', cb_check(1))

%% Clear plots

    function clear_plots(source, eventdata) %#ok<*INUSD>
        if (logical(p_bed) && ishandle(p_bed))
            delete(p_bed)
        end
        if (logical(p_beddepth) && ishandle(p_beddepth))
            delete(p_beddepth)
        end
        if (logical(p_bedflat) && ishandle(p_bedflat))
            delete(p_bedflat)
        end
        if (any(p_block) && any(ishandle(p_block)))
            delete(p_block(logical(p_block) & ishandle(p_block)))
        end
        if (any(p_blockflat) && any(ishandle(p_blockflat)))
            delete(p_blockflat(logical(p_blockflat) & ishandle(p_blockflat)))
        end
        if (any(p_blocknum) && any(ishandle(p_blocknum)))
            delete(p_blocknum(logical(p_blocknum) & ishandle(p_blocknum)))
        end
        if (any(p_blocknumflat) && any(ishandle(p_blocknumflat)))
            delete(p_blocknumflat(logical(p_blocknumflat) & ishandle(p_blocknumflat)))
        end
        if (any(p_core) && any(ishandle(p_core)))
            delete(p_core(logical(p_core) & ishandle(p_core)))
        end
        if (any(p_coreflat) && any(ishandle(p_coreflat)))
            delete(p_coreflat(logical(p_coreflat) & ishandle(p_coreflat)))
        end
        if (any(p_corename) && any(ishandle(p_corename)))
            delete(p_corename(logical(p_corename) & ishandle(p_corename)))
        end
        if (any(p_corenameflat) && any(ishandle(p_corenameflat)))
            delete(p_corenameflat(logical(p_corenameflat) & ishandle(p_corenameflat)))
        end
        if (logical(p_data) && ishandle(p_data))
            delete(p_data)
        end
        if (any(p_pk) && any(ishandle(p_pk)))
            delete(p_pk(logical(p_pk) & ishandle(p_pk)))
        end
        if (any(p_pkdepth) && any(ishandle(p_pkdepth)))
            delete(p_pkdepth(logical(p_pkdepth) & ishandle(p_pkdepth)))
        end
        if (any(p_pkflat) && any(ishandle(p_pkflat)))
            delete(p_pkflat(logical(p_pkflat) & ishandle(p_pkflat)))
        end
        if (logical(p_surf) && ishandle(p_surf))
            delete(p_surf)
        end
        set([layer_list block_list], 'string', 'N/A', 'value', 1)
        if (get(disp_group, 'selectedobject') ~= disp_check(1))
            set(disp_group, 'selectedobject', disp_check(1))
            disp_type       = 'elev.';
        end
        if (get(cb_group, 'selectedobject') ~= cb_check(1))
            set(cb_group, 'selectedobject', cb_check(1))
            cb_type         = 'dB';
        end
    end

%% Clear data and picks

    function clear_data(source, eventdata)
        pk                  = struct;
        [bed_avail, data_done, edit_flag, flat_done, gimp_avail, merge_done, merge_file, surf_avail] ...
                            = deal(false);
        [age_curr, amp_depth, amp_elev, amp_flat, colors, curr_chunk, curr_layer, curr_subtrans, curr_trans, curr_year, depth, depth_bed, depth_bed_flat, depth_curr, depth_flat, depth_layer_flat, depth_layer_ref, depth_mat, ...
         dist_chunk, dt, elev, ii, ind_decim, ind_int, ind_x_pk, ind_x_ref, ind_y_pk, jj, kk, num_chunk, num_data, num_decim, num_int, num_pk, num_sample, p_bed, p_beddepth, p_bedflat, p_block, p_blockflat, p_blocknum, ...
         p_blocknumflat, p_core, p_coreflat, p_corename, p_corenameflat, p_data, p_pk, p_pkdepth, p_pkflat, p_refflat, p_snr, p_surf, pk_all, pkfig, snrgui, snrlist, tmp1, tmp2, tmp3, tmp4, tmp5, twtt] ...
                            = deal(0);
        [file_data, file_pk, file_pk_short, file_save] ...
                            = deal('');
        set(file_box, 'string', '')
    end

%% Load picks for this transect

    function load_pk(source, eventdata)
        
        if (merge_done || data_done)
            clear_plots
            clear_data
        end
        
        % Dialog box to choose picks file to load
        set(mgui, 'keypressfcn', [])
        set(status_box, 'string', 'Load pick files (F) or directory (D)?')
        waitforbuttonpress
        if strcmpi(get(mgui, 'currentcharacter'), 'F')
            [tmp1, tmp2]    = deal(file_pk, path_pk);
            if ~isempty(path_pk)
                [file_pk, path_pk] = uigetfile('*.mat', 'Load picks files (*_pk.mat):', path_pk, 'multiselect', 'on');
            elseif ~isempty(path_data)
                [file_pk, path_pk] = uigetfile('*.mat', 'Load picks files: (*_pk.mat)', path_data, 'multiselect', 'on');
            else
                [file_pk, path_pk] = uigetfile('*.mat', 'Load picks files: (*_pk.mat)', 'multiselect', 'on');
            end
            if isnumeric(file_pk)
                [file_pk, path_pk] = deal('', tmp2);
            end
        elseif strcmpi(get(mgui, 'currentcharacter'), 'D')
            [tmp1, tmp2]    = deal(file_pk, path_pk);
            if ~isempty(path_pk)
                path_pk     = uigetdir(path_pk, 'Load picks directory (containing *_pk.mat):');
            elseif ~isempty(path_data)
                path_pk     = uigetdir(path_data, 'Load picks directory (containing *_pk.mat):');
            else
                path_pk     = uigetdir('Load picks directory (containing *_pk.mat):');
            end
            if ~ischar(path_pk)
                [file_pk, path_pk] ...
                            = deal('', tmp2);
            else
                if ispc
                    path_pk = [path_pk '\'];
                else
                    path_pk = [path_pk '/'];
                end
                file_pk     = dir([path_pk '*_pk.mat']);
                file_pk     = {file_pk.name}';
            end
        else
            set(status_box, 'string', 'Choice unclear. Try again.')
            set(mgui, 'keypressfcn', @keypress)
            return
        end
        
        set(mgui, 'keypressfcn', @keypress)
        
        if isempty(file_pk)
            file_pk         = tmp1;
            set(status_box, 'string', 'No picks loaded.')
            return
        end
        
        set(status_box, 'string', 'Starting initial loading and merging of picks...')
        pause(0.1)
        
        if ischar(file_pk)
            file_pk         = {file_pk}; % only one pick file
        end
        
        % load picks files
        num_pk              = length(file_pk);
        pk_all              = cell(1, num_pk);
        [bed_avail, gimp_avail, surf_avail] ...
                            = deal(false(1, num_pk));
        
        for ii = 1:num_pk %#ok<*FXUP>
            set(status_box, 'string', ['Loading ' file_pk{ii}(1:(end - 4)) ' (' num2str(ii) ' / ' num2str(num_pk) ')...'])
            pause(0.1)
            tmp1            = load([path_pk file_pk{ii}]);
            try
                pk_all{ii}  = tmp1.pk;
                tmp1        = 0;
                % check to see if surface and bed picks are available
                if isfield(pk_all{ii}, 'elev_bed')
                    bed_avail(ii) ...
                            = true;
                end
                if isfield(pk_all{ii}, 'elev_surf')
                    surf_avail(ii) ...
                            = true;
                end
                if isfield(pk_all{ii}, 'elev_surf_gimp')
                    gimp_avail(ii) ...
                            = true;
                end
            catch % give up, force restart
                set(status_box, 'string', [file_pk{ii} ' does not contain a pk structure. Try again.'])
                [pk_all, num_pk] ...
                            = deal(0);
                return
            end
        end
        
        if (~any(surf_avail) && any(~isnan(pk.elev_surf)))
            set(status_box, 'string', 'Surface pick is not included in the pick files, so data will not be elevation-corrected.')
            pause(0.1)
        end
        
        % extract date and simple name from pk files
        [tmp1, tmp2]        = strtok(file_pk{ii}, '_');
        file_pk_short       = [tmp1 tmp2(1:3)];
        if (~strcmp(tmp2(4), '_') && ~strcmp(tmp2(4:8), 'block'))
            file_pk_short   = [file_pk_short tmp2(4)];
        end
        set(file_box, 'string', file_pk_short)
        
        if ((num_pk == 1) && isfield(pk_all{1}, 'merge_flag')) % data already merged
            
            tmp1            = fieldnames(pk_all{1});
            for ii = 1:length(tmp1)
                eval(['pk.' tmp1{ii} ' = pk_all{1}.' tmp1{ii} ';'])
            end
            merge_file      = true;
            path_save       = path_pk;
            if isfield(pk, 'poly_flat_merge')
                if any(pk.poly_flat_merge(:))
                    flat_done ...
                            = true;
                    ord_poly ...
                            = size(pk.poly_flat_merge, 1) - 1;
                end
            end
            
            set(status_box, 'string', 'Merged file loaded...')
            pause(0.1)
            
        else % time to merge
            
            for ii = 1:num_cell
                eval(['pk.' var_cell{ii} ' = cell(num_pk, 1);'])
            end
            for ii = 1:num_zero
                eval(['pk.' var_zero{ii} ' = zeros(num_pk, 1);'])
            end
            pk.ind_overlap  ...
                        = NaN(num_pk, 2);
            tmp1        = cell(1, num_pk);
            
            % loop through pk files and assign values
            for ii = 1:num_pk
                pk.ind_overlap(ii, :) ...
                            = pk_all{ii}.ind_overlap;
                pk.file_pk{ii} ...
                            = file_pk{ii};
                pk.file_block{ii} ...
                            = pk_all{ii}.file_block;
                pk.num_layer_block(ii) ...
                            = pk_all{ii}.num_layer;
                for jj = 1:(num_cell - 2)
                    if isfield(pk_all{ii}, var_cell{jj})
                        eval(['pk.' var_cell{jj} '{ii} = pk_all{ii}.' var_cell{jj} ';'])
                    end
                end
                for jj = 1:(num_zero - 2)
                    if isfield(pk_all{ii}, var_zero{jj})
                        eval(['pk.' var_zero{jj} '(ii) = pk_all{ii}.' var_zero{jj} ';'])
                    end
                end
                tmp1{ii}= pk_all{ii}.ind_match';
            end
            
            pk.num_layer    = length(unique([tmp1{:}])); % number of layers in this transect
            
            pk.num_trace_tot= sum(pk.num_trace) - sum(pk.ind_overlap(~isnan(pk.ind_overlap(:, 1)), 1)); % number of non-overlapping traces
            if ~isnan(pk.ind_overlap(1, 1)) % true if not starting at beginning of transect (e.g., no layers in early blocks)
                pk.num_trace_tot ...
                            = pk.num_trace_tot + pk.ind_overlap(1, 1);
            end
            
            % allocate variables for merging
            for ii = 1:num_var_layer
                eval(['pk.' var_layer{ii} ' = NaN(pk.num_layer, pk.num_trace_tot, ''single'');'])
            end
            if any(gimp_avail)
                for ii = 1:num_var_layer_gimp
                    eval(['pk.' var_layer_gimp{ii} ' = NaN(pk.num_layer, pk.num_trace_tot, ''single'');'])
                end
            end
            for ii = 1:num_var_pos
                eval(['pk.' var_pos{ii} ' = NaN(1, pk.num_trace_tot);'])
            end
            if any(gimp_avail)
                for ii = 1:num_var_pos_gimp
                    eval(['pk.' var_pos_gimp{ii} ' = NaN(1, pk.num_trace_tot);'])
                end
            end
            
            [pk.ind_trace_start(1), pk.ind_layer_all, pk.ind_match_block] ...
                            = deal(1, 1:pk.num_layer, false(pk.num_layer, num_pk)); % start at 1, layer indices that are present in all blocks (to be eroded in loop below)
            
            % merge picks
            for ii = 1:num_pk
                
                set(status_box, 'string', ['Merging picks (' num2str(ii) ' / ' num2str(num_pk) ')...'])
                pause(0.1)
                tmp1        = pk.ind_trace_start(ii):(pk.ind_trace_start(ii) + pk.num_trace(ii) - 1); % merged indices
                
                % merge layer data
                for jj = 1:pk.num_layer
                    if any(pk.ind_match{ii} == jj)
                        tmp2                        = find((pk.ind_match{ii} == jj), 1);
                        pk.ind_match_block(jj, ii)  = true;
                        if (ii == 1)
                            for kk = 1:num_var_layer
                                eval(['pk.' var_layer{kk} '(jj, tmp1) = single(pk_all{ii}.layer(tmp2).' var_layer{kk} ');'])
                            end
                            if gimp_avail(ii)
                                for kk = 1:num_var_layer_gimp
                                    eval(['pk.' var_layer_gimp{kk} '(jj, tmp1) = single(pk_all{ii}.layer(tmp2).' var_layer_gimp{kk} ');'])
                                end
                            end
                        else
                            for kk = 1:num_var_layer
                                eval(['pk.' var_layer{kk} '(jj, tmp1(1:pk.ind_overlap(ii, 1))) = single(nanmean([pk_all{ii}.layer(tmp2).' var_layer{kk} '(1:pk.ind_overlap(ii, 1)); pk.' var_layer{kk} '(jj, tmp1(1:pk.ind_overlap(ii, 1)))]));'])
                                tmp3                = pk_all{ii}.layer(tmp2); % intermediate step because of some variable assignment restriction
                                eval(['pk.' var_layer{kk} '(jj, tmp1((pk.ind_overlap(ii, 1) + 1):end)) = single(tmp3.' var_layer{kk} '((pk.ind_overlap(ii, 1) + 1):end));'])
                            end
                            if gimp_avail(ii)
                                for kk = 1:num_var_layer_gimp
                                    eval(['pk.' var_layer_gimp{kk} '(jj, tmp1(1:pk.ind_overlap(ii, 1))) = single(nanmean([pk_all{ii}.layer(tmp2).' var_layer_gimp{kk} '(1:pk.ind_overlap(ii, 1)); pk.' ...
                                          var_layer_gimp{kk} '(jj, tmp1(1:pk.ind_overlap(ii, 1)))]));'])
                                    tmp3            = pk_all{ii}.layer(tmp2); % intermediate step because of some variable assignment restriction
                                    eval(['pk.' var_layer_gimp{kk} '(jj, tmp1((pk.ind_overlap(ii, 1) + 1):end)) = single(tmp3.' var_layer_gimp{kk} '((pk.ind_overlap(ii, 1) + 1):end));'])
                                end
                            end
                        end
                    else
                        pk.ind_layer_all            = setdiff(pk.ind_layer_all, jj);
                    end
                end
                
                % merge position data
                if (ii == 1)
                    if (surf_avail(ii) && bed_avail(ii))
                        for jj = 1:num_var_pos
                            eval(['pk.' var_pos{jj} '(tmp1) = pk_all{ii}.' var_pos{jj} ';'])
                        end
                    elseif (surf_avail(ii) && ~bed_avail(ii))
                        for jj = 1:(num_var_pos - 2)
                            eval(['pk.' var_pos{jj} '(tmp1) = pk_all{ii}.' var_pos{jj} ';'])
                        end
                    elseif (~surf_avail(ii) && bed_avail(ii))
                        for jj = [1:6 9 10]
                            eval(['pk.' var_pos{jj} '(tmp1) = pk_all{ii}.' var_pos{jj} ';'])
                        end
                    else
                        for jj = 1:(num_var_pos - 4)
                            eval(['pk.' var_pos{jj} '(tmp1) = pk_all{ii}.' var_pos{jj} ';'])
                        end
                    end
                    if gimp_avail(ii)
                        for jj = 1:num_var_pos_gimp
                            eval(['pk.' var_pos_gimp{jj} '(tmp1) = pk_all{ii}.' var_pos_gimp{jj} ';'])
                        end
                    end
                else % should not need to average overlapping position data
                    if (surf_avail(ii) && bed_avail(ii))
                        for jj = 1:num_var_pos
                            eval(['pk.' var_pos{jj} '(tmp1((pk.ind_overlap(ii, 1) + 1):end)) = pk_all{ii}.' var_pos{jj} '((pk.ind_overlap(ii, 1) + 1):end);'])
                        end
                    elseif (surf_avail(ii) && ~bed_avail(ii))
                        for jj = 1:(num_var_pos - 2)
                            eval(['pk.' var_pos{jj} '(tmp1((pk.ind_overlap(ii, 1) + 1):end)) = pk_all{ii}.' var_pos{jj} '((pk.ind_overlap(ii, 1) + 1):end);'])
                        end
                    elseif (~surf_avail(ii) && bed_avail(ii))
                        for jj = [1:6 9 10]
                            eval(['pk.' var_pos{jj} '(tmp1((pk.ind_overlap(ii, 1) + 1):end)) = pk_all{ii}.' var_pos{jj} '((pk.ind_overlap(ii, 1) + 1):end);'])
                        end
                    else
                        for jj = 1:(num_var_pos - 4)
                            eval(['pk.' var_pos{jj} '(tmp1((pk.ind_overlap(ii, 1) + 1):end)) = pk_all{ii}.' var_pos{jj} '((pk.ind_overlap(ii, 1) + 1):end);'])
                        end
                    end
                    if gimp_avail(ii)
                        for jj = 1:num_var_pos_gimp
                            eval(['pk.' var_pos_gimp{jj} '(tmp1((pk.ind_overlap(ii, 1) + 1):end)) = pk_all{ii}.' var_pos_gimp{jj} '((pk.ind_overlap(ii, 1) + 1):end);'])
                        end
                    end
                end
                
                % prepare for next block and correct for overlap
                if (ii < num_pk)
                    pk.ind_trace_start(ii + 1) ...
                            = pk.ind_trace_start(ii) + pk.num_trace(ii);
                    if ~isnan(pk.ind_overlap(ii, 2));
                        pk.ind_trace_start(ii + 1) ...
                            = pk.ind_trace_start(ii + 1) - (pk.num_trace(ii) - pk.ind_overlap(ii, 2) + 1);
                    end
                end
            end
            
            gimp_avail      = all(gimp_avail); % test to see if every block has GIMP projection
            
            % sort layers by decreasing elevation
            tmp1        = zeros(pk.num_layer, 1);
            if gimp_avail
                for ii = 1:pk.num_layer
                    tmp1(ii)= nanmean(pk.elev_smooth_gimp(ii, :));
                end
            else
                for ii = 1:pk.num_layer
                    tmp1(ii)= nanmean(pk.elev_smooth(ii, :));
                end
            end
            [~, tmp1]   = sort(tmp1);
            for ii = 1:num_var_layer
                eval(['pk.' var_layer{ii} ' = pk.' var_layer{ii} '(flipud(tmp1), :);'])
            end
            if gimp_avail
                for ii = 1:num_var_layer_gimp
                    eval(['pk.' var_layer_gimp{ii} ' = pk.' var_layer_gimp{ii} '(flipud(tmp1), :);'])
                end
            end
            
            pk.dist_lin     = interp1([1 pk.num_trace_tot], pk.dist([1 end]), 1:pk.num_trace_tot); % new linear distance vector (should not be merged because each linear distance vector is different)
            if gimp_avail
                pk.dist_lin_gimp ...
                            = interp1([1 pk.num_trace_tot], pk.dist_gimp([1 end]), 1:pk.num_trace_tot);
            end
        end
        
        % get rid of weird empty layers
        tmp1                = [];
        for ii = 1:pk.num_layer
            if all(isnan(pk.ind_y(ii, :)))
                tmp1        = [tmp1 ii]; %#ok<AGROW>
            end
        end
        if ~isempty(tmp1)
            for ii = 1:num_var_layer
                eval(['pk.' var_layer{ii} ' = pk.' var_layer{ii} '(setdiff(1:pk.num_layer, tmp1), :);'])
            end
            if gimp_avail
                for ii = 1:num_var_layer_gimp
                    eval(['pk.' var_layer_gimp{ii} ' = pk.' var_layer_gimp{ii} '(setdiff(1:pk.num_layer, tmp1), :);'])
                end
            end
            pk.num_layer    = pk.num_layer - length(tmp1);
        end
        
        [pk_all, tmp3]      = deal(0);
        
        % decimated vectors for display
        if (decim > 1)
            ind_decim       = (1 + ceil(decim / 2)):decim:(pk.num_trace_tot - ceil(decim / 2));
        else
            ind_decim       = 1:pk.num_trace_tot;
        end
        num_decim           = length(ind_decim);
        
        if (merge_file && flat_done && isfield(pk, 'ind_x_ref'))
            ind_x_ref       = interp1(ind_decim, 1:num_decim, pk.ind_x_ref, 'nearest', 'extrap');
        else
            [ind_x_ref, pk.ind_x_ref] ...
                            = deal(1);
        end
        
        % make chunks
        adj_length_chunk
        
        % display merged picks
        colors              = repmat(colors_def, ceil(pk.num_layer / size(colors_def, 1)), 1); % extend predefined color pattern
        colors              = colors(1:pk.num_layer, :);
        [p_pk, p_pkdepth]   = deal(zeros(1, pk.num_layer));
        layer_str           = num2cell(1:pk.num_layer);
        for ii = 1:pk.num_layer
            if all(isnan(pk.elev_smooth(ii, ind_decim)))
                p_pk(ii)=plot(0, 0, 'w.', 'markersize', 1, 'visible', 'off');
                layer_str{ii} ...
                        = [num2str(layer_str{ii}) ' H'];
            else
                if gimp_avail
                    p_pk(ii)= plot(pk.dist_lin_gimp(ind_decim(~isnan(pk.elev_smooth_gimp(ii, ind_decim)))), pk.elev_smooth_gimp(ii, ind_decim(~isnan(pk.elev_smooth_gimp(ii, ind_decim)))), '.', 'color', colors(ii, :), 'markersize', 12, 'visible', 'off');
                else
                    p_pk(ii)= plot(pk.dist_lin(ind_decim(~isnan(pk.elev_smooth(ii, ind_decim)))), pk.elev_smooth(ii, ind_decim(~isnan(pk.elev_smooth(ii, ind_decim)))), '.', 'color', colors(ii, :), 'markersize', 12, 'visible', 'off');
                end
            end
            if all(isnan(pk.depth_smooth(ii, ind_decim)))
                p_pkdepth(ii)=plot(0, 0, 'w.', 'markersize', 1, 'visible', 'off');
            else
                if gimp_avail
                    p_pkdepth(ii) ...
                        = plot(pk.dist_lin_gimp(ind_decim(~isnan(pk.depth_smooth(ii, ind_decim)))), pk.depth_smooth(ii, ind_decim(~isnan(pk.depth_smooth(ii, ind_decim)))), '.', 'color', colors(ii, :), 'markersize', 12, 'visible', 'off');
                else
                    p_pkdepth(ii) ...
                        = plot(pk.dist_lin(ind_decim(~isnan(pk.depth_smooth(ii, ind_decim)))), pk.depth_smooth(ii, ind_decim(~isnan(pk.depth_smooth(ii, ind_decim)))), '.', 'color', colors(ii, :), 'markersize', 12, 'visible', 'off');
                end
            end
        end
        set(layer_list, 'string', layer_str, 'value', 1)
        
        if gimp_avail
            [dist_min_ref, dist_max_ref, dist_min, dist_max] ...
                            = deal(pk.dist_lin_gimp(1), pk.dist_lin_gimp(end), pk.dist_lin_gimp(1), pk.dist_lin_gimp(end));
        else
            [dist_min_ref, dist_max_ref, dist_min, dist_max] ...
                            = deal(pk.dist_lin(1), pk.dist_lin(end), pk.dist_lin(1), pk.dist_lin(end));
        end
        if (any(surf_avail) && any(~isnan(pk.elev_surf)))
            if gimp_avail
                [elev_max_ref, elev_max] ...
                            = deal(nanmax(pk.elev_surf_gimp(~isinf(pk.elev_surf_gimp))) + (0.1 * (nanmax(pk.elev_surf_gimp(~isinf(pk.elev_surf_gimp))) - nanmin(pk.elev_surf_gimp(~isinf(pk.elev_surf_gimp))))));
            else
                [elev_max_ref, elev_max] ...
                            = deal(nanmax(pk.elev_surf(~isinf(pk.elev_surf))) + (0.1 * (nanmax(pk.elev_surf(~isinf(pk.elev_surf))) - nanmin(pk.elev_surf(~isinf(pk.elev_surf))))));
            end
        else
            if gimp_avail
                [elev_max_ref, elev_max] ...
                            = deal(nanmax(pk.elev_smooth_gimp(:)) + (0.1 * (nanmax(pk.elev_smooth_gimp(:)) - nanmin(pk.elev_smooth_gimp(:)))));
            else
                [elev_max_ref, elev_max] ...
                            = deal(nanmax(pk.elev_smooth(:)) + (0.1 * (nanmax(pk.elev_smooth(:)) - nanmin(pk.elev_smooth(:)))));
            end
        end
        if (any(bed_avail) && any(~isnan(pk.elev_bed)))
            if gimp_avail
                [elev_min_ref, elev_min] ...
                            = deal(nanmin(pk.elev_bed_gimp(~isinf(pk.elev_bed_gimp))) - (0.1 * (nanmax(pk.elev_bed_gimp(~isinf(pk.elev_bed_gimp))) - nanmin(pk.elev_bed_gimp(~isinf(pk.elev_bed_gimp))))));
            else
                [elev_min_ref, elev_min] ...
                            = deal(nanmin(pk.elev_bed(~isinf(pk.elev_bed))) - (0.1 * (nanmax(pk.elev_bed(~isinf(pk.elev_bed))) - nanmin(pk.elev_bed(~isinf(pk.elev_bed))))));
            end
        else
            if gimp_avail
                [elev_min_ref, elev_min] ...
                            = deal(nanmin(pk.elev_smooth_gimp(:)) - (0.1 * (nanmax(pk.elev_smooth_gimp(:)) - nanmin(pk.elev_smooth_gimp(:)))));
            else
                [elev_min_ref, elev_min] ...
                            = deal(nanmin(pk.elev_smooth(:)) - (0.1 * (nanmax(pk.elev_smooth(:)) - nanmin(pk.elev_smooth(:)))));
            end
        end
        set(z_min_slide, 'min', elev_min_ref, 'max', elev_max_ref, 'value', elev_min_ref)
        set(z_max_slide, 'min', elev_min_ref, 'max', elev_max_ref, 'value', elev_max_ref)
        set(dist_min_slide, 'min', dist_min_ref, 'max', dist_max_ref, 'value', dist_min_ref)
        set(dist_max_slide, 'min', dist_min_ref, 'max', dist_max_ref, 'value', dist_max_ref)
        set(z_min_edit, 'string', sprintf('%4.0f', elev_min_ref))
        set(z_max_edit, 'string', sprintf('%4.0f', elev_max_ref))
        set(dist_min_edit, 'string', sprintf('%3.1f', dist_min_ref))
        set(dist_max_edit, 'string', sprintf('%3.1f', dist_max_ref))
        update_dist_range
        update_z_range
        
        [p_block, p_blockflat] ...
                            = deal(zeros(1, length(pk.ind_trace_start)));
        if gimp_avail
            tmp1            = double(pk.dist_lin_gimp);
        else
            tmp1            = pk.dist_lin;
        end
        for ii = 1:length(pk.ind_trace_start)
            p_block(ii)     = plot(repmat(tmp1(pk.ind_trace_start(ii)), 1, 2), [elev_min_ref elev_max_ref], 'm--', 'linewidth', 1, 'visible', 'off');
            if ~isempty(pk.file_block{ii})
                p_blocknum(ii) ...
                            = text(double(tmp1(pk.ind_trace_start(ii)) + 1), double(elev_max_ref - 100), pk.file_block{ii}((end - 1):end), 'color', 'm', 'fontsize', (size_font - 2), 'visible', 'off');
            end
        end
        
        set(pk_check, 'value', 1)
        merge_done      = true;
        set(disp_group, 'selectedobject', disp_check(1))
        disp_type       = 'elev.';
        axes(ax_radar)
        axis xy
        show_pk
        show_block
        if core_done
            load_core_breakout
        end
        if age_done
            load_age_breakout
        end
        
        if merge_file
            set(status_box, 'string', ['Loaded merged pick file from ' file_pk_short '.'])
        else
            set(status_box, 'string', ['Loaded and merged ' num2str(num_pk) ' pick files from ' file_pk_short '.'])
        end
        
        % list with block filenames to load
        set(block_list, 'string', pk.file_block)
    end

%% Load radar data

    function load_data(source, eventdata)
        
        if ~merge_done
            set(status_box, 'string', 'Load picks before data.')
            return
        end
        
        % check if data are in expected location based on picks' path
        tmp1                = file_pk_short;
        if (isnan(str2double(tmp1(end))) || ~isreal(str2double(tmp1(end)))) % check for a/b/c/etc in file_pk_short
            tmp2            = tmp1(1:(end - 1));
        else
            tmp2            = tmp1;
        end
        
        if merge_file
            if ispc
                if ~strcmp(tmp1, tmp2)
                    if (~isempty(path_pk) && exist([path_pk '..\block\' tmp2 '\' tmp1(end) '\'], 'dir'))
                        path_data = [path_pk(1:strfind(path_pk, '\merge')) 'block\' tmp2 '\' tmp1(end) '\'];
                    elseif (~isempty(path_pk) && exist([path_pk '..\block\' tmp2 '\'], 'dir'))
                        path_data = [path_pk(1:strfind(path_pk, '\merge')) 'block\' tmp2 '\'];
                    end
                elseif (~isempty(path_pk) && exist([path_pk '..\block\' tmp2 '\'], 'dir'))
                    path_data = [path_pk(1:strfind(path_pk, '\merge')) 'block\' tmp2 '\'];
                end
            else
                if ~strcmp(tmp1, tmp2)
                    if (~isempty(path_pk) && exist([path_pk '../block/' tmp2 '/' tmp1(end) '/'], 'dir'))
                        path_data = [path_pk(1:strfind(path_pk, '/merge')) 'block/' tmp2 '/' tmp1(end) '/'];
                    elseif (~isempty(path_pk) && exist([path_pk '../block/' tmp2 '/'], 'dir'))
                        path_data = [path_pk(1:strfind(path_pk, '/merge')) 'block/' tmp2 '/'];
                    end
                elseif (~isempty(path_pk) && exist([path_pk '../block/' tmp2 '/'], 'dir'))
                    path_data = [path_pk(1:strfind(path_pk, '/merge')) 'block/' tmp2 '/'];
                end
            end
        else
            if ispc
                if ~strcmp(tmp1, tmp2)
                    if (~isempty(path_pk) && exist([path_pk '..\..\..\block\' tmp2 '\' tmp1(end) '\'], 'dir'))
                        path_data = [path_pk(1:strfind(path_pk, '\pk')) 'block\' tmp2 '\' tmp1(end) '\'];
                    elseif (~isempty(path_pk) && exist([path_pk '..\..\block\' tmp2 '\'], 'dir'))
                        path_data = [path_pk(1:strfind(path_pk, '\pk')) 'block\' tmp2 '\'];
                    end
                elseif (~isempty(path_pk) && exist([path_pk '..\..\block\' tmp2 '\'], 'dir'))
                    path_data = [path_pk(1:strfind(path_pk, '\pk')) 'block\' tmp2 '\'];
                end
            else
                if ~strcmp(tmp1, tmp2)
                    if (~isempty(path_pk) && exist([path_pk '../../../block/' tmp2 '/' tmp1(end) '/'], 'dir'))
                        path_data = [path_pk(1:strfind(path_pk, '/pk')) 'block/' tmp2 '/' tmp1(end) '/'];
                    elseif (~isempty(path_pk) && exist([path_pk '../../block/' tmp2 '/'], 'dir'))
                        path_data = [path_pk(1:strfind(path_pk, '/pk')) '/block/' tmp2 '/'];
                    end
                elseif (~isempty(path_pk) && exist([path_pk '../../block/' tmp2 '/'], 'dir'))
                    path_data = [path_pk(1:strfind(path_pk, '/pk')) 'block/' tmp2 '/'];
                end
            end
        end
        
        % check filenames are available
        tmp1                = false(length(pk.file_block), 1);
        for ii = 1:length(pk.file_block)
            if ~isempty(pk.file_block{ii})
                tmp1(ii)    = true;
            end
        end
        
        if (~isempty(path_data) && all(tmp1) && ~isempty(dir([path_data '*.mat']))) % get data filenames automatically if path found
            if (merge_file && exist([path_data pk.file_block{1} '.mat'], 'file'))
                file_data   = pk.file_block;
                for ii = 1:num_pk
                    file_data{ii} ...
                            = [pk.file_block{ii} '.mat'];
                end
            elseif exist([path_data file_pk{1}(1:(end - 7)) '.mat'], 'file')
                file_data   = cell(num_pk, 1);
                for ii = 1:num_pk
                    file_data{ii} ...
                            = [file_pk{ii}(1:(end - 7)) '.mat'];
                end
            end
        else % dialog box to choose radar data file to load
            [tmp1, tmp2]    = deal(file_data, path_data);
            if ~isempty(path_pk)
                [file_data, path_data] = uigetfile('*.mat', 'Load radar data:', path_pk, 'multiselect', 'on');
            else
                [file_data, path_data] = uigetfile('*.mat', 'Load radar data:', 'multiselect', 'on');
            end
            if isnumeric(file_data)
                [file_data, path_data] = deal('', tmp2);
            end
        end
        
        if isempty(file_data)
            file_data       = tmp1;
            set(status_box, 'string', 'No radar data loaded.')
            return
        end
        
        pause(0.1)
        
        if ischar(file_data)
            file_data       = {file_data};
        end
        
        num_data            = length(file_data);
        if ((num_data ~= num_pk) && ~merge_file)
            set(status_box, 'string', ['Number of data blocks (' num2str(num_data) ') does not match number of picks files (' num2str(num_pk) ').'])
            return
        end
        
        if data_done
            data_done       = false;
        end
        
        load_data_breakout
    end

%% Loading function broken out (so that changing decimation is automatic)

    function load_data_breakout(source, eventdata)
        
        if (logical(p_data) && ishandle(p_data))
            delete(p_data)
        end
        if (any(p_block) && any(ishandle(p_block)))
            delete(p_block(logical(p_block) & ishandle(p_block)))
        end
        if (any(p_blocknum) && any(ishandle(p_blocknum)))
            delete(p_blocknum(logical(p_blocknum) & ishandle(p_blocknum)))
        end
        if (any(p_blockflat) && any(ishandle(p_blockflat)))
            delete(p_blockflat(logical(p_blockflat) & ishandle(p_blockflat)))
        end
        if (any(p_blocknumflat) && any(ishandle(p_blocknumflat)))
            delete(p_blocknumflat(logical(p_blocknumflat) & ishandle(p_blocknumflat)))
        end
        if (any(p_coreflat) && any(ishandle(p_coreflat)))
            delete(p_coreflat(logical(p_coreflat) & ishandle(p_coreflat)))
        end
        if (any(p_corenameflat) && any(ishandle(p_corenameflat)))
            delete(p_corenameflat(logical(p_corenameflat) & ishandle(p_corenameflat)))
        end
        
        % attempt to load data
        set(status_box, 'string', 'Loading radar data...')
        pause(0.1)
        
        for ii = 1:num_data
            
            set(status_box, 'string', ['Loading ' file_data{ii}(1:(end - 4)) ' (' num2str(ii) ' / ' num2str(num_data) ')...'])
            pause(0.1)
            tmp1            = load([path_data file_data{ii}]);
            try
                tmp1        = tmp1.block;
            catch %#ok<*CTCH>
                set(status_box, 'string', [file_data{ii} ' does not contain a block structure. Try again.'])
                return
            end
            
            if (ii == 1) % start decimation
                
                amp_elev    = NaN(pk.num_sample(ii), num_decim, 'single');
                [dt, twtt, num_sample] ...
                            = deal(tmp1.dt, tmp1.twtt, tmp1.num_sample);
                tmp2        = (1 + ceil(decim / 2)):decim:(pk.num_trace(ii) - ceil(decim / 2));
                tmp3        = floor(decim / 2);
                for jj = 1:length(tmp2)
                    amp_elev(:, jj) ...
                            = nanmean(tmp1.amp(:, (tmp2(jj) - tmp3):(tmp2(jj) + tmp3)), 2);
                end
                
            else % middle/end
                
                tmp2        = repmat((pk.ind_trace_start(ii) + pk.ind_overlap(ii, 1)), 1, 2);
                tmp2(2)     = tmp2(2) + pk.num_trace(ii) - pk.ind_overlap(ii, 1) - 1;
                if (ii < num_data)
                    tmp3    = (find((tmp2(1) > ind_decim), 1, 'last') + 1):find((tmp2(2) <= ind_decim), 1);
                else
                    tmp3    = (find((tmp2(1) > ind_decim), 1, 'last') + 1):num_decim;
                end
                if (ii == 2)
                    tmp3    = [(tmp3(1) - 2) (tmp3(1) - 1) tmp3]; %#ok<AGROW> % correct weirdness for first block
                end
                tmp2        = ind_decim(tmp3) - pk.ind_trace_start(ii) + 1;
                tmp4        = tmp2 - floor(decim / 2);
                tmp5        = tmp2 + floor(decim / 2);
                tmp4(tmp4 < 1) ...
                            = 1;
                tmp5(tmp5 > pk.num_trace(ii)) ...
                            = pk.num_trace(ii);
                if (size(amp_elev, 1) > size(tmp1.amp, 1))
                    for jj = 1:length(tmp3)
                        amp_elev(:, tmp3(jj)) ...
                            = [nanmean(tmp1.amp(:, tmp4(jj):tmp5(jj)), 2); NaN((size(amp_elev, 1) - size(tmp1.amp, 1)), 1)];
                    end
                elseif (size(amp_elev, 1) < size(tmp1.amp, 1))
                    for jj = 1:length(tmp3)
                        amp_elev(:, tmp3(jj)) ...
                            = nanmean(tmp1.amp(1:size(amp_elev, 1), tmp4(jj):tmp5(jj)), 2);
                    end
                else
                    for jj = 1:length(tmp3)
                        amp_elev(:, tmp3(jj)) ...
                            = nanmean(tmp1.amp(:, tmp4(jj):tmp5(jj)), 2);
                    end
                end
            end
            
            tmp1            = 0;
            
        end
        
        % convert to dB and determine elevation/depth vectors
        amp_elev(isinf(amp_elev)) ...
                            = NaN;
        amp_elev            = 10 .* log10(abs(amp_elev));
        num_sample          = size(amp_elev, 1);
        depth               = (speed_ice / 2) .* twtt;
        
        if (any(surf_avail) && any(~isnan(pk.elev_surf)))
            tmp2            = interp1(twtt, 1:num_sample, pk.twtt_surf(ind_decim), 'nearest', 'extrap'); % surface traveltime indices
            if any(isnan(tmp2))
                tmp2(isnan(tmp2)) ...
                            = round(interp1(find(~isnan(tmp2)), tmp2(~isnan(tmp2)), find(isnan(tmp2)), 'linear', 'extrap'));
            end
            tmp2(tmp2 <= 0) = 1;
        else
            tmp2            = ones(1, num_decim);
        end
        if gimp_avail
            tmp3            = pk.elev_surf_gimp(ind_decim);
        else
            tmp3            = pk.elev_surf(ind_decim);
        end
        if any(isnan(tmp3))
            tmp3(isnan(tmp3)) ...
                            = interp1(find(~isnan(tmp3)), tmp3(~isnan(tmp3)), find(isnan(tmp3)), 'linear', 'extrap');
        end
        
        amp_depth           = NaN(size(amp_elev), 'single');
        for ii = 1:num_decim
            amp_depth(1:(num_sample - tmp2(ii) + 1), ii) ...
                            = amp_elev(tmp2(ii):num_sample, ii); % shift data up to surface
        end
        amp_elev            = topocorr(amp_depth, depth, tmp3); % topographically correct data
        amp_elev            = flipud(amp_elev); % flip for axes
        depth               = (speed_ice / 2) .* (0:dt:((num_sample - 1) * dt))'; % simple monotonically increasing depth vector
        if gimp_avail
            elev            = flipud(max(pk.elev_surf_gimp(ind_decim)) - depth); % elevation vector
        else
            elev            = flipud(max(pk.elev_surf(ind_decim)) - depth); % elevation vector
        end
        
        if any(surf_avail & bed_avail)
            if gimp_avail
                depth_bed   = pk.elev_surf_gimp(ind_decim) - pk.elev_bed_gimp(ind_decim);
            else
                depth_bed   = pk.elev_surf(ind_decim) - pk.elev_bed(ind_decim);
            end
        end
        
        % assign traveltime and distance reference values/sliders based on data
        [elev_min_ref, elev_max_ref, db_min_ref, db_max_ref, elev_min, elev_max, db_min, db_max, depth_min_ref, depth_max_ref, depth_min, depth_max] ...
                            = deal(min(elev), max(elev), min(amp_elev(~isinf(amp_elev(:)) & ~isnan(amp_elev(:)))), max(amp_elev(~isinf(amp_elev(:)) & ~isnan(amp_elev(:)))), min(elev), max(elev), ...
                                   min(amp_elev(~isinf(amp_elev(:)) & ~isnan(amp_elev(:)))), max(amp_elev(~isinf(amp_elev(:)) & ~isnan(amp_elev(:)))), min(depth), max(depth), min(depth), max(depth));
        set(z_min_slide, 'min', elev_min_ref, 'max', elev_max_ref, 'value', elev_min_ref)
        set(z_max_slide, 'min', elev_min_ref, 'max', elev_max_ref, 'value', elev_max_ref)
        set(cb_min_slide, 'min', db_min_ref, 'max', db_max_ref, 'value', db_min_ref)
        set(cb_max_slide, 'min', db_min_ref, 'max', db_max_ref, 'value', db_max_ref)
        set(z_min_edit, 'string', sprintf('%4.0f', elev_min_ref))
        set(z_max_edit, 'string', sprintf('%4.0f', elev_max_ref))
        set(cb_min_edit, 'string', sprintf('%3.0f', db_min_ref))
        set(cb_max_edit, 'string', sprintf('%3.0f', db_max_ref))
        update_z_range
        
        % plot block divisions
        [p_block, p_blockflat, p_blocknum, p_blocknumflat] ...
                            = deal(zeros(1, length(pk.ind_trace_start)));
        if gimp_avail
            tmp1            = pk.dist_lin_gimp;
        else
            tmp1            = pk.dist_lin;
        end
        for ii = 1:length(pk.ind_trace_start)
            p_block(ii)     = plot(repmat(tmp1(pk.ind_trace_start(ii)), 1, 2), [elev_min_ref elev_max_ref], 'm--', 'linewidth', 1, 'visible', 'off');
            if ~isempty(pk.file_block{ii})
                p_blocknum(ii) ...
                            = text(double(tmp1(pk.ind_trace_start(ii)) + 1), double(elev_max_ref - 100), pk.file_block{ii}((end - 1):end), 'color', 'm', 'fontsize', (size_font - 2), 'visible', 'off');
            end
            p_blockflat(ii) = plot(repmat(tmp1(pk.ind_trace_start(ii)), 1, 2), [depth_min_ref depth_max_ref], 'm--', 'linewidth', 1, 'visible', 'off');
            if ~isempty(pk.file_block{ii})
                p_blocknumflat(ii) ...
                            = text((tmp1(pk.ind_trace_start(ii)) + 1), (depth_min_ref + 100), pk.file_block{ii}((end - 1):end), 'color', 'm', 'fontsize', (size_font - 2), 'visible', 'off');
            end
        end
        
        tmp2                = find(~isnan(ind_int));
        if core_done
            for ii = 1:num_int
                p_coreflat(ii) ...
                            = plot(repmat(tmp1(ind_int(tmp2(ii))), 1, 2), [depth_min_ref depth_max_ref], 'm', 'linewidth', 2, 'visible', 'off');
                p_corenameflat(ii) ...
                            = text((tmp1(ind_int(tmp2(ii))) + 1), (depth_min_ref + 250), name_core{int_core{curr_year}{curr_trans}(tmp2(ii), 3)}, 'color', 'm', 'fontsize', size_font, 'visible', 'off');
            end
        end
        
        % plot data
        data_done           = true;
        set(data_check, 'value', 1)
        plot_elev
        
        if flat_done
            depth_layer_ref = NaN(pk.num_layer, 1);
            depth_layer_ref(~isnan(pk.elev_smooth(:, pk.ind_x_ref))) ...
                            = 1;
            % fix polynomials to current decimation vector
            if (num_decim ~= size(pk.poly_flat_merge, 2))
                pk.poly_flat_merge ...
                            = interp2(pk.poly_flat_merge, linspace(1, num_decim, num_decim), (1:(ord_poly + 1))');
            end
            flatten_breakout
        end
        
        set(status_box, 'string', 'Transect radar data loaded.')
    end

%% Flatten amplitudes using layers

    function flatten(source, eventdata)
        
        if (~merge_done || ~data_done)
            set(status_box, 'string', 'Picks must be loaded and merged and data must be loaded prior to flattening.')
            return
        end
        if (pk.num_layer < (ord_poly + 1))
            set(status_box, 'string', 'Not enough layers to flatten (need 3+ or 4+).')
            return
        end
        
        flat_done           = false;
        
        if (logical(p_bedflat) && ishandle(p_bedflat))
            delete(p_bedflat)
        end
        if (any(p_pkflat) && any(ishandle(p_pkflat)))
            delete(p_pkflat(logical(p_pkflat) & ishandle(p_pkflat)))
        end
        if (any(p_coreflat) && any(ishandle(p_coreflat)))
            delete(p_coreflat(logical(p_coreflat) & ishandle(p_coreflat)))
        end
        if (any(p_corenameflat) && any(ishandle(p_corenameflat)))
            delete(p_corenameflat(logical(p_corenameflat) & ishandle(p_corenameflat)))
        end
        
        % compile layer depths to use in flattening
        pk.poly_flat_merge  = NaN((ord_poly + 1), num_decim, 'single');
        depth_curr          = [zeros(1, num_decim); pk.depth_smooth(:, ind_decim)];
        
        % keep the maximum number of layers for first go
        ind_x_ref           = sum(isnan(depth_curr));
        ind_x_ref           = find((ind_x_ref == min(ind_x_ref)), 1); % reference trace, i.e., the trace with the most layers
        depth_layer_ref     = depth_curr(:, ind_x_ref); % layer depths at reference trace
        tmp1                = depth_curr(~isnan(depth_layer_ref), :); % depth of all layers that are not nan at the reference trace
        tmp2                = tmp1(:, ind_x_ref); % depths of non-nan layers at reference trace
        tmp3                = find(sum(~isnan(tmp1)) > ord_poly); % traces where it will be worth doing the polynomial
        
        set(status_box, 'string', ['Starting polynomial fits using ' num2str(length(tmp2)) ' / ' num2str(pk.num_layer) ' layers...'])
        pause(0.1)
        
        set(mgui, 'keypressfcn', [])
        
        if parallel_check
            pctRunOnAll warning('off', 'MATLAB:polyfit:RepeatedPointsOrRescale')
            pctRunOnAll warning('off', 'MATLAB:polyfit:PolyNotUnique')
        else
            warning('off', 'MATLAB:polyfit:RepeatedPointsOrRescale')
            warning('off', 'MATLAB:polyfit:PolyNotUnique')
        end
        
        % now polyfit
        if parallel_check
            tmp1            = tmp1(:, tmp3);
            tmp4            = pk.poly_flat_merge(:, tmp3);
            parfor ii = 1:length(tmp3)
                tmp4(:, ii) = polyfit(tmp2(~isnan(tmp1(:, ii))), tmp1(~isnan(tmp1(:, ii)), ii), ord_poly)'; %#ok<PFBNS>
            end
            pk.poly_flat_merge(:, tmp3) ...
                            = tmp4;
            tmp4            = 0;
        else
            for ii = 1:length(tmp3)
                pk.poly_flat_merge(:, tmp3(ii)) ...
                            = polyfit(tmp2(~isnan(tmp1(:, tmp3(ii)))), tmp1(~isnan(tmp1(:, tmp3(ii))), tmp3(ii)), ord_poly)';
            end
        end
        
        set(status_box, 'string', 'Smoothing initial polynomials...')
        pause(0.1)
        
        % smooth polynomials
        if gimp_avail
            tmp2            = round(mean(pk.length_smooth) / nanmean(diff(pk.dist_gimp(ind_decim))));
        else
            tmp2            = round(mean(pk.length_smooth) / nanmean(diff(pk.dist(ind_decim))));
        end
        if parallel_check
            tmp1            = pk.poly_flat_merge;
            parfor ii = 1:(ord_poly + 1)
                tmp1(ii, :) = smooth_lowess(tmp1(ii, :), tmp2);
            end
            pk.poly_flat_merge ...
                            = tmp1;
            tmp1            = 0;
        else
            for ii = 1:(ord_poly + 1)
                pk.poly_flat_merge(ii, :) ...
                            = smooth_lowess(pk.poly_flat_merge(ii, :), tmp2);
            end
        end
        
        % iterate using other layers if any are available
        if any(isnan(depth_layer_ref))
            
            % determine which layers overlap with original polyfit layers and order polyfit iteration based on the length of their overlap
            tmp1            = zeros(1, length(depth_layer_ref));
            for ii = find(isnan(depth_layer_ref))'
                tmp1(ii)    = length(find(~isnan(depth_curr(ii, tmp3))));
            end
            [tmp1, tmp2]    = sort(tmp1, 'descend');
            tmp5            = tmp2(logical(tmp1));
            set(status_box, 'string', ['Iterating flattening for ' num2str(length(tmp2(logical(tmp1)))) ' overlapping layers out of ' num2str(length(find(isnan(depth_layer_ref)))) ' not fitted initially...'])
            
            pause(0.1)
            
            kk              = 0;
            
            for ii = tmp5
                
                kk          = kk + 1;
                set(status_box, 'string', ['Adding layer #' num2str(ii) ' (' num2str(kk) ' / ' num2str(length(tmp5)) ') to flattening...'])
                pause(0.1)
                
                % calculate flattening matrix based on current polynomials
                tmp1        = find(~isnan(depth_curr(ii, :)));
                depth_mat   = single(depth(:, ones(1, length(tmp1)))); % depth matrix
                switch ord_poly
                    case 2
                        depth_flat  = ((depth_mat .^ 2) .* pk.poly_flat_merge(ones(num_sample, 1), tmp1)) + (depth_mat .* (pk.poly_flat_merge((2 .* ones(num_sample, 1)), tmp1))) + pk.poly_flat_merge((3 .* ones(num_sample, 1)), tmp1);
                    case 3
                        depth_flat  = ((depth_mat .^ 3) .* pk.poly_flat_merge(ones(num_sample, 1), tmp1)) + ((depth_mat .^ 2) .* pk.poly_flat_merge((2 .* ones(num_sample, 1)), tmp1)) + ...
                                      (depth_mat .* (pk.poly_flat_merge((3 .* ones(num_sample, 1)), tmp1))) + pk.poly_flat_merge((4 .* ones(num_sample, 1)), tmp1);
                end
                depth_mat   = 0;
                depth_flat(depth_flat < 0) ...
                            = 0; % limit too-low depths
                depth_flat(depth_flat > depth(end)) ...
                            = depth(end); % limit too-high depths
                tmp3        = find(sum(~isnan(depth_flat)));
                
                % find best-fit value at original trace
                tmp4        = NaN(1, length(tmp1));
                tmp3        = tmp3(~isnan(depth_curr(ii, tmp1(tmp3)))); % indices where both flattening and new layer exist
                
                if isempty(tmp3)
                    set(status_box, 'string', ['Layer #' num2str(ii) ' has no overlap...'])
                    pause(0.1)
                    continue
                end
                
                % depth of current layer at reference trace for all overlapping traces
                for jj = tmp3
                    [~, tmp2] ...
                            = unique(depth_flat(:, jj), 'last');
                    tmp2    = intersect((1 + find(diff(depth_flat(:, jj)) > 0)), tmp2);
                    if ~isempty(tmp2)
                        tmp4(jj) ...
                            = interp1(depth_flat(tmp2, jj), depth(tmp2), depth_curr(ii, tmp1(jj)), 'linear', NaN);
                    end
                end
                
                depth_layer_ref(ii) ...
                            = nanmean(tmp4); % best guess depth at reference trace 
                
                % extract best layers again, now including the new layer
                tmp4        = tmp1(tmp3);
                tmp1        = depth_curr(~isnan(depth_layer_ref), tmp4);
                tmp2        = depth_layer_ref(~isnan(depth_layer_ref));
                tmp3        = find(sum(~isnan(tmp1)) > ord_poly);
                tmp4        = tmp4(sum(~isnan(tmp1)) > ord_poly);
                
                % new polynomials using additional "depth" for this layer
                if parallel_check
                    tmp1    = tmp1(:, tmp3);
                    tmp3    = pk.poly_flat_merge(:, tmp3);
                    parfor jj = 1:length(tmp4)
                        tmp3(:, jj) ...
                            = polyfit(tmp2(~isnan(tmp1(:, jj))), tmp1(~isnan(tmp1(:, jj)), jj), ord_poly)'; %#ok<PFBNS>
                    end
                    pk.poly_flat_merge(:, tmp4) ...
                            = tmp3;
                else
                    for jj = 1:length(tmp3)
                        pk.poly_flat_merge(:, tmp4(jj)) ...
                            = polyfit(tmp2(~isnan(tmp1(:, tmp3(jj)))), tmp1(~isnan(tmp1(:, tmp3(jj))), tmp3(jj)), ord_poly)';
                    end
                end
                
                % smooth polynomials again
                if gimp_avail
                    tmp2    = round(mean(pk.length_smooth) / nanmean(diff(pk.dist_gimp(ind_decim))));
                else
                    tmp2    = round(mean(pk.length_smooth) / nanmean(diff(pk.dist(ind_decim))));
                end
                if parallel_check
                    tmp1    = pk.poly_flat_merge;
                    parfor jj = 1:(ord_poly + 1)
                        tmp1(jj, :) ...
                            = smooth_lowess(tmp1(jj, :), tmp2);
                    end
                    pk.poly_flat_merge ...
                            = tmp1;
                    tmp1    = 0;
                else
                    for jj = 1:(ord_poly + 1)
                        pk.poly_flat_merge(jj, :) ...
                            = smooth_lowess(pk.poly_flat_merge(jj, :), tmp2);
                    end
                end
            end
        end
        
        depth_layer_ref      = depth_layer_ref(2:end); % drop surface
        
        if parallel_check
            pctRunOnAll warning('on', 'MATLAB:polyfit:RepeatedPointsOrRescale')
            pctRunOnAll warning('on', 'MATLAB:polyfit:PolyNotUnique')
        else
            warning('on', 'MATLAB:polyfit:RepeatedPointsOrRescale')
            warning('on', 'MATLAB:polyfit:PolyNotUnique')
        end
        
        flatten_breakout
        
        set(mgui, 'keypressfcn', @keypress)
        
    end

%% Flatten amplitudes using layers

    function flatten_breakout(source, eventdata)
        
        if (logical(p_bedflat) && ishandle(p_bedflat))
            delete(p_bedflat)
        end
        if (any(p_pkflat) && any(ishandle(p_pkflat)))
            delete(p_pkflat(logical(p_pkflat) & ishandle(p_pkflat)))
        end
        
        set(status_box, 'string', 'Flattening data based on polynomials...')
        
        % flattening matrix based on layer depth fits
        depth_mat           = single(depth(:, ones(1, num_decim))); % depth matrix
        switch ord_poly
            case 2
                depth_flat  = ((depth_mat .^ 2) .* pk.poly_flat_merge(ones(num_sample, 1), :)) + (depth_mat .* (pk.poly_flat_merge((2 .* ones(num_sample, 1)), :))) + ...
                              pk.poly_flat_merge((3 .* ones(num_sample, 1)), :);                
            case 3
                depth_flat  = ((depth_mat .^ 3) .* pk.poly_flat_merge(ones(num_sample, 1), :)) + ((depth_mat .^ 2) .* pk.poly_flat_merge((2 .* ones(num_sample, 1)), :)) + ...
                              (depth_mat .* (pk.poly_flat_merge((3 .* ones(num_sample, 1)), :))) + pk.poly_flat_merge((4 .* ones(num_sample, 1)), :);
        end
        depth_mat           = 0;
        if any(isnan(depth_flat(:))) % fix nans
            for ii = find(any(isnan(depth_flat)))
                if (length(find(~isnan(depth_flat(:, ii)))) > 2)
                    depth_flat(isnan(depth_flat(:, ii)), ii) ...
                            = interp1(find(~isnan(depth_flat(:, ii))), depth_flat(~isnan(depth_flat(:, ii)), ii), find(isnan(depth_flat(:, ii))), 'linear', 'extrap');
                end
            end
        end
        depth_flat(depth_flat < 0) ...
                            = 0;
        depth_flat(depth_flat > depth(end)) ...
                            = depth(end);
        set(status_box, 'string', 'Calculated remapping...')
        pause(0.1)
        
        % flattened radargram based on the polyfits
        tmp1                = amp_depth;
        tmp2                = find(sum(~isnan(depth_flat)));
        amp_flat            = NaN(num_sample, num_decim, 'single');
        if parallel_check
            tmp1            = tmp1(:, tmp2);
            tmp3            = depth_flat(:, tmp2);
            tmp4            = amp_flat(:, tmp2);
            pctRunOnAll warning('off', 'MATLAB:interp1:NaNinY')
            parfor ii = 1:length(tmp2)
                tmp4(:, ii) = interp1(depth, tmp1(:, ii), tmp3(:, ii));
            end
            pctRunOnAll warning('on', 'MATLAB:interp1:NaNinY')
            amp_flat(:, tmp2) ...
                            = tmp4;
        else
            warning('off', 'MATLAB:interp1:NaNinY')
            for ii = 1:length(tmp2)
                amp_flat(:, tmp2(ii)) ...
                            = interp1(depth, tmp1(:, tmp2(ii)), depth_flat(:, tmp2(ii)), 'linear');
            end
            warning('on', 'MATLAB:interp1:NaNinY')
        end
        tmp1                = 0;
        
        set(status_box, 'string', 'Flattened amplitude...')
        pause(0.1)
        
        % flatten bed pick
        if (any(bed_avail) && any(~isnan(pk.elev_bed)) && ~any(isinf(pk.elev_bed)))
            depth_bed_flat  = NaN(1, num_decim);
            for ii = tmp2
                [~, tmp1]   = unique(depth_flat(:, ii), 'last');
                tmp1        = intersect((1 + find(diff(depth_flat(:, ii)) > 0)), tmp1);
                if (length(tmp1) > 1)
                    depth_bed_flat(ii) ...
                            = interp1(depth_flat(tmp1, ii), depth(tmp1), depth_bed(ii), 'nearest', 'extrap');
                end
            end
            depth_bed_flat((depth_bed_flat < 0) | (depth_bed_flat > depth(end))) ...
                            = NaN;
        end
        
        % flatten merged layer depths
        warning('off', 'MATLAB:interp1:NaNinY')
        depth_layer_flat    = NaN(pk.num_layer, num_decim);
        for ii = 1:length(tmp2)
            [~, tmp1]       = unique(depth_flat(:, tmp2(ii)), 'last');
            tmp1            = intersect((1 + find(diff(depth_flat(:, tmp2(ii))) > 0)), tmp1);
            if (any(~isnan(pk.depth_smooth(:, ind_decim(tmp2(ii))))) && ~isempty(tmp1))
                depth_layer_flat(~isnan(pk.depth_smooth(:, ind_decim(tmp2(ii)))), tmp2(ii)) ...
                            = interp1(depth_flat(tmp1, tmp2(ii)), depth(tmp1), pk.depth_smooth(~isnan(pk.depth_smooth(:, ind_decim(tmp2(ii)))), ind_decim(tmp2(ii))), 'nearest', 'extrap');
            end
        end
        warning('on', 'MATLAB:interp1:NaNinY')
        
        % plot flat layers
        axes(ax_radar)
        if gimp_avail
            tmp1            = pk.dist_lin_gimp;
        else
            tmp1            = pk.dist_lin;
        end
        p_pkflat            = zeros(1, pk.num_layer);
        for ii = 1:pk.num_layer
            if ~isempty(find(~isnan(depth_layer_flat(ii, :)), 1))
                p_pkflat(ii)= plot(tmp1(ind_decim(~isnan(depth_layer_flat(ii, :)))), depth_layer_flat(ii, ~isnan(depth_layer_flat(ii, :))), '.', 'markersize', 12, 'color', colors(ii, :), 'visible', 'off');
            else
                p_pkflat(ii)= plot(0, 0, '.', 'markersize', 12, 'color', colors(ii, :), 'visible', 'off');
            end
            if isnan(depth_layer_ref(ii))
                set(p_pkflat(ii), 'markersize', 6)
            end
        end
                
        flat_done           = true;
        edit_flag           = false;
        set(disp_group, 'selectedobject', disp_check(3))
        disp_type           = 'flat';
        pk_select
        [depth_min, depth_max] ...
                            = deal(depth_min_ref, depth_max_ref);
        plot_flat
        set(status_box, 'string', 'Merged radargram flattened.')
        
    end

%% Choose the current layer

    function pk_select(source, eventdata)
        curr_layer          = get(layer_list, 'value');
        pk_curr
    end

    function pk_curr(source, eventdata)
        set(layer_list, 'value', curr_layer)
        if (any(p_pk) && any(ishandle(p_pk)))
            set(p_pk(logical(p_pk) & ishandle(p_pk)), 'markersize', 12)
        end
        if (any(p_pkdepth) && any(ishandle(p_pkdepth)))
            set(p_pkdepth(logical(p_pkdepth) & ishandle(p_pkdepth)), 'markersize', 12)
        end
        if (logical(p_pk(curr_layer)) && ishandle(p_pk(curr_layer)))
            set(p_pk(curr_layer), 'markersize', 24)
        end
        if (logical(p_pkdepth(curr_layer)) && ishandle(p_pkdepth(curr_layer)))
            set(p_pkdepth(curr_layer), 'markersize', 24)
        end
        if (flat_done && data_done)
            if (any(p_pkflat) && any(ishandle(p_pkflat)))
                set(p_pkflat(logical(p_pkflat) & ishandle(p_pkflat)), 'markersize', 12)
            end
            if (logical(p_pkflat(curr_layer)) && ishandle(p_pkflat(curr_layer)))
                set(p_pkflat(curr_layer), 'markersize', 24)
            end
            for ii = find(isnan(depth_layer_ref))'
                if (logical(p_pkflat(ii)) && ishandle(p_pkflat(ii)))
                    set(p_pkflat(ii), 'markersize', 6)
                end
            end
        end
    end

%% Choose a layer manually

    function pk_select_gui(source, eventdata)
        if ~merge_done
            set(status_box, 'string', 'No layers to focus on.')
            return
        end
        set(status_box, 'string', 'Choose a layer to highlight...')
        pause(0.1)
        [ind_x_pk, ind_y_pk]= ginput(1);
        pk_select_gui_breakout
    end

    function pk_select_gui_breakout(source, eventdata)
        switch disp_type
            case 'elev.'
                if gimp_avail
                    [tmp1, tmp2] ...
                            = unique(pk.elev_smooth_gimp(:, interp1(pk.dist_lin_gimp(ind_decim), ind_decim, ind_x_pk, 'nearest', 'extrap')));
                else
                    [tmp1, tmp2] ...
                            = unique(pk.elev_smooth(:, interp1(pk.dist_lin(ind_decim), ind_decim, ind_x_pk, 'nearest', 'extrap')));
                end
            case 'depth'
                if gimp_avail
                    [tmp1, tmp2]= unique(pk.depth_smooth(:, interp1(pk.dist_lin_gimp(ind_decim), ind_decim, ind_x_pk, 'nearest', 'extrap')));
                else
                    [tmp1, tmp2]= unique(pk.depth_smooth(:, interp1(pk.dist_lin(ind_decim), ind_decim, ind_x_pk, 'nearest', 'extrap')));
                end
            case 'flat'
                if gimp_avail
                    [tmp1, tmp2] ...
                            = unique(depth_layer_flat(:, interp1(ind_decim, 1:num_decim, interp1(pk.dist_lin_gimp(ind_decim), ind_decim, ind_x_pk, 'nearest', 'extrap'), 'nearest', 'extrap')));
                else
                    [tmp1, tmp2] ...
                            = unique(depth_layer_flat(:, interp1(ind_decim, 1:num_decim, interp1(pk.dist_lin(ind_decim), ind_decim, ind_x_pk, 'nearest', 'extrap'), 'nearest', 'extrap')));
                end
        end
        if any(~isnan(tmp1))
            if (length(find(~isnan(tmp1))) > 1)
                curr_layer  = interp1(tmp1(~isnan(tmp1)), tmp2(~isnan(tmp1)), ind_y_pk, 'nearest', 'extrap');
            else
                curr_layer  = tmp2(1);
            end
            set(layer_list, 'value', curr_layer)
            pk_select
            set(status_box, 'string', ['Layer #' num2str(curr_layer) ' chosen.'])
        else
            set(status_box, 'string', 'No layer at that position')
        end
    end

%% Focus x/y axes on current layer

    function pk_focus(source, eventdata)
        if ~any(~isnan(pk.elev_smooth(curr_layer, ind_decim)))
            set(status_box, 'string', 'Cannot focus on a layer that is hidden.')
            return
        end
        axes(ax_radar)
        if gimp_avail
            xlim([pk.dist_lin_gimp(find(~isnan(pk.elev_smooth_gimp(curr_layer, :)), 1)) pk.dist_lin_gimp(find(~isnan(pk.elev_smooth_gimp(curr_layer, :)), 1, 'last'))])
        else
            xlim([pk.dist_lin(find(~isnan(pk.elev_smooth(curr_layer, :)), 1)) pk.dist_lin(find(~isnan(pk.elev_smooth(curr_layer, :)), 1, 'last'))])
        end
        tmp1                = get(ax_radar, 'xlim');
        [tmp1(1), tmp1(2)]  = deal((tmp1(1) - diff(tmp1)), (tmp1(2) + diff(tmp1)));
        if (tmp1(1) < dist_min_ref)
            tmp1(1)         = dist_min_ref;
        end
        if (tmp1(2) > dist_max_ref)
            tmp1(2)         = dist_max_ref;
        end
        xlim(tmp1)
        [dist_min, dist_max]= deal(tmp1(1), tmp1(2));
        if (dist_min < get(dist_min_slide, 'min'))
            set(dist_min_slide, 'value', get(dist_min_slide, 'min'))
        elseif (dist_min > get(dist_min_slide, 'max'))
            set(dist_min_slide, 'value', get(dist_min_slide, 'max'))
        else
            set(dist_min_slide, 'value', dist_min)
        end
        if (dist_max < get(dist_max_slide, 'min'))
            set(dist_max_slide, 'value', get(dist_max_slide, 'min'))
        elseif (dist_max > get(dist_max_slide, 'max'))
            set(dist_max_slide, 'value', get(dist_max_slide, 'max'))
        else
            set(dist_max_slide, 'value', dist_max)
        end
        set(dist_min_edit, 'string', sprintf('%3.1f', dist_min))
        set(dist_max_edit, 'string', sprintf('%3.1f', dist_max))
        switch disp_type
            case 'elev.'
                if gimp_avail
                    ylim([min(pk.elev_smooth_gimp(curr_layer, ind_decim)) max(pk.elev_smooth_gimp(curr_layer, ind_decim))])
                else
                    ylim([min(pk.elev_smooth(curr_layer, ind_decim)) max(pk.elev_smooth(curr_layer, ind_decim))])
                end
                tmp1        = get(ax_radar, 'ylim');
                [tmp1(1), tmp1(2)] ...
                            = deal((tmp1(1) - diff(tmp1)), (tmp1(2) + diff(tmp1)));
                if (tmp1(1) < elev_min_ref)
                    tmp1(1) = elev_min_ref;
                end
                if (tmp1(2) > elev_max_ref)
                    tmp1(2) = elev_max_ref;
                end
                ylim(tmp1)
                [elev_min, elev_max] ...
                            = deal(tmp1(1), tmp1(2));
                depth_min       = depth_min - (elev_max - tmp1(2));
                depth_max       = depth_max - (elev_min - tmp1(1));
                if (depth_min < depth_min_ref)
                    depth_min   = depth_min_ref;
                end
                if (depth_max > depth_max_ref)
                    depth_max   = depth_max_ref;
                end
                if (elev_min < get(z_min_slide, 'min'))
                    set(z_min_slide, 'value', get(z_min_slide, 'min'))
                elseif (elev_min > get(z_min_slide, 'max'))
                    set(z_min_slide, 'value', get(z_min_slide, 'max'))
                else
                    set(z_min_slide, 'value', elev_min)
                end
                if (elev_max < get(z_max_slide, 'min'))
                    set(z_max_slide, 'value', get(z_max_slide, 'min'))
                elseif (elev_max > get(z_max_slide, 'max'))
                    set(z_max_slide, 'value', get(z_max_slide, 'max'))
                else
                    set(z_max_slide, 'value', elev_max)
                end
                set(z_min_edit, 'string', sprintf('%4.0f', elev_min))
                set(z_max_edit, 'string', sprintf('%4.0f', elev_max))
            case {'depth' 'flat'}
                ylim([min(depth_layer_flat(curr_layer, :)) max(depth_layer_flat(curr_layer, :))])
                tmp1        = get(ax_radar, 'ylim');
                [tmp1(1), tmp1(2)] ...
                            = deal((tmp1(1) - diff(tmp1)), (tmp1(2) + diff(tmp1)));
                if (tmp1(1) < depth_min_ref)
                    tmp1(1) = depth_min_ref;
                end
                if (tmp1(2) > depth_max_ref)
                    tmp1(2) = depth_max_ref;
                end
                ylim(tmp1)
                [depth_min, depth_max] ...
                            = deal(tmp1(1), tmp1(2));
                elev_min    = elev_min - (depth_max - tmp1(2));
                elev_max    = elev_max - (depth_min - tmp1(1));
                if (elev_min < elev_min_ref)
                    elev_min= elev_min_ref;
                end
                if (elev_max > elev_max_ref)
                    elev_max= elev_max_ref;
                end
                if ((depth_max_ref - (depth_max - depth_min_ref)) < get(z_min_slide, 'min'))
                    set(z_min_slide, 'value', get(z_min_slide, 'min'))
                elseif ((depth_max_ref - (depth_max - depth_min_ref)) > get(z_min_slide, 'max'))
                    set(z_min_slide, 'value', get(z_min_slide, 'max'))
                else
                    set(z_min_slide, 'value', (depth_max_ref - (depth_max - depth_min_ref)))
                end
                if ((depth_max_ref - (depth_min - depth_min_ref)) < get(z_max_slide, 'min'))
                    set(z_max_slide, 'value', get(z_max_slide, 'min'))
                elseif ((depth_max_ref - (depth_min - depth_min_ref)) > get(z_max_slide, 'max'))
                    set(z_max_slide, 'value', get(z_max_slide, 'max'))
                else
                    set(z_max_slide, 'value', (depth_max_ref - (depth_min - depth_min_ref)))
                end
                set(z_min_edit, 'string', sprintf('%4.0f', depth_max))
                set(z_max_edit, 'string', sprintf('%4.0f', depth_min))
        end
        narrow_cb
        set(status_box, 'string', ['Focused on Layer #' num2str(curr_layer) '.'])
    end

%% Delete layer

    function pk_del(source, eventdata)
        if ~merge_done
            set(status_box, 'string', 'No layers to delete yet. Load picks first.')
            return
        end
        set(status_box, 'string', 'Delete current layer? Y: yes; otherwise: no.')
        waitforbuttonpress
        if ~strcmpi(get(mgui, 'currentcharacter'), 'Y')
            set(status_box, 'string', 'Layer deletion cancelled.')
            return
        end
        tmp1                = setdiff(1:pk.num_layer, curr_layer);
        if (logical(p_pk(curr_layer)) && ishandle(p_pk(curr_layer)))
            delete(p_pk(curr_layer))
        end
        if (logical(p_pkdepth(curr_layer)) && ishandle(p_pkdepth(curr_layer)))
            delete(p_pkdepth(curr_layer))
        end
        for ii = 1:num_var_layer
            eval(['pk.' var_layer{ii} ' = pk. ' var_layer{ii} '(tmp1, :);'])
        end
        if gimp_avail
            for ii = 1:num_var_layer_gimp
                eval(['pk.' var_layer_gimp{ii} ' = pk. ' var_layer_gimp{ii} '(tmp1, :);'])
            end
        end
        [pk.num_layer, p_pk, p_pkdepth] ...
                            = deal((pk.num_layer - 1), p_pk(tmp1), p_pkdepth(tmp1));
        layer_str           = num2cell(1:pk.num_layer);
        for ii = 1:pk.num_layer
            if ~any(~isnan(pk.elev_smooth(ii, ind_decim)))
                layer_str{ii} ...
                            = [num2str(layer_str{ii}) ' H'];
            end
        end
        if (flat_done && data_done)
            if (logical(p_pkflat(curr_layer)) && ishandle(p_pkflat(curr_layer)))
                delete(p_pkflat(curr_layer))
            end
            p_pkflat        = p_pkflat(tmp1);
            depth_layer_flat= depth_layer_flat(tmp1, :);
            depth_layer_ref = depth_layer_ref(tmp1);
            edit_flag       = true;
        end
        curr_layer          = curr_layer - 1;
        if (isempty(curr_layer) || any(curr_layer < 1) || any(curr_layer > pk.num_layer))
            curr_layer      = 1;
        end
        if pk.num_layer
            set(layer_list, 'string', layer_str, 'value', curr_layer)
        else
            set(layer_list, 'string', 'N/A', 'value', 1)
        end
        set(status_box, 'string', ['Layer #' num2str(curr_layer) ' deleted.'])
        pk_select
    end

%% Switch to previous/next layer in list

    function pk_last(source, eventdata)
        if (merge_done && (curr_layer > 1))
            curr_layer      = curr_layer - 1;
            pk_curr
        end
    end

    function pk_next(source, eventdata)
        if (merge_done && (curr_layer < pk.num_layer))
            curr_layer      = curr_layer + 1;
            pk_curr
        end
    end

%% Merge two layers

    function pk_merge(source, eventdata)
        
        if ~merge_done
            set(status_box, 'string', 'Load picks before merging them.')
            return
        end
        
        set(status_box, 'string', ['Pick layer to merge with layer #' num2str(curr_layer) ' (Q: cancel)...'])
        pause(0.1)
        
        axes(ax_radar)
        
        % get pick and convert to indices
        [ind_x_pk, ind_y_pk, button] ...
                            = ginput(1);
        
        if strcmpi(char(button), 'Q')
            set(status_box, 'string', 'Layer merging cancelled.')
            return
        end
        
        % get current layer positions at ind_x_pk, depending on what we're working with
        switch disp_type
            case 'elev.'
                if gimp_avail
                    [tmp1, tmp2]= unique(pk.elev_smooth_gimp(:, interp1(pk.dist_lin_gimp(ind_decim), ind_decim, ind_x_pk, 'nearest', 'extrap')));
                else
                    [tmp1, tmp2]= unique(pk.elev_smooth(:, interp1(pk.dist_lin(ind_decim), ind_decim, ind_x_pk, 'nearest', 'extrap')));
                end
            case 'depth'
                if gimp_avail
                    [tmp1, tmp2]= unique(pk.depth_smooth(:, interp1(pk.dist_lin_gimp(ind_decim), ind_decim, ind_x_pk, 'nearest', 'extrap')));
                else
                    [tmp1, tmp2]= unique(pk.depth_smooth(:, interp1(pk.dist_lin(ind_decim), ind_decim, ind_x_pk, 'nearest', 'extrap')));
                end
            case 'flat'
                if gimp_avail
                    [tmp1, tmp2]= unique(depth_layer_flat(:, interp1(ind_decim, 1:num_decim, interp1(pk.dist_lin_gimp(ind_decim), ind_decim, ind_x_pk, 'nearest', 'extrap'), 'nearest', 'extrap')));
                else
                    [tmp1, tmp2]= unique(depth_layer_flat(:, interp1(ind_decim, 1:num_decim, interp1(pk.dist_lin(ind_decim), ind_decim, ind_x_pk, 'nearest', 'extrap'), 'nearest', 'extrap')));
                end
        end
        tmp2                = tmp2(~isnan(tmp1));
        tmp1                = tmp1(~isnan(tmp1));
        if (length(tmp1) > 1)
            tmp1            = interp1(tmp1, tmp2(~isnan(tmp1)), ind_y_pk, 'nearest', 'extrap');
        else
            tmp1            = tmp2;
        end
        if (tmp1 == curr_layer)
            set(status_box, 'string', 'Aborted merging because picked layer for merging is the same as current layer.')
            return
        end
        if isempty(tmp1)
            set(status_box, 'string', 'No layer picked to be merged. Pick more precisely.')
            return
        end
        
        if (logical(p_pk(tmp1)) && ishandle(p_pk(tmp1)))
            set(p_pk(tmp1), 'color', colors(curr_layer, :))
        end
        if (logical(p_pkdepth(tmp1)) && ishandle(p_pkdepth(tmp1)))
            set(p_pkdepth(tmp1), 'color', colors(curr_layer, :))
        end        
        if (flat_done && logical(p_pkflat(tmp1)) && ishandle(p_pkflat(tmp1)))
            set(p_pkflat(tmp1), 'color', colors(curr_layer, :))
        end
        pause(0.1)
        
        set(status_box, 'string', 'Merging correct? (Y: yes; otherwise: cancel)...')
        
        waitforbuttonpress
        if ~strcmpi(get(mgui, 'currentcharacter'), 'Y')
            set([p_pk(tmp1) p_pkdepth(tmp1)], 'color', colors(tmp1, :))
            if (flat_done && data_done)
                set(p_pkflat(tmp1), 'markersize', 12, 'color', colors(tmp1, :))
            end
            set(status_box, 'string', 'Layer merging cancelled.')
            return
        end
        
        % assign layer variables in tmp1 that aren't nan to the same layer variable in curr_layer
        for ii = 1:num_var_layer
            eval(['pk.' var_layer{ii} '(curr_layer, ~isnan(pk.' var_layer{ii} '(tmp1, :))) = pk.' var_layer{ii} '(tmp1, ~isnan(pk. ' var_layer{ii} '(tmp1, :)));']);
        end
        if gimp_avail
            for ii = 1:num_var_layer_gimp
                eval(['pk.' var_layer_gimp{ii} '(curr_layer, ~isnan(pk.' var_layer_gimp{ii} '(tmp1, :))) = pk.' var_layer_gimp{ii} '(tmp1, ~isnan(pk. ' var_layer_gimp{ii} '(tmp1, :)));']);
            end
        end
        if (flat_done && data_done)
            depth_layer_flat(curr_layer, ~isnan(depth_layer_flat(tmp1, :))) ...
                            = depth_layer_flat(tmp1, ~isnan(depth_layer_flat(tmp1, :)));
        end
        
        % redo plots
        if (any(p_pk([curr_layer tmp1])) && any(ishandle(p_pk([curr_layer tmp1]))))
            delete(p_pk([curr_layer tmp1]))
            if gimp_avail
                p_pk(curr_layer)= plot(pk.dist_lin_gimp(~isnan(pk.elev_smooth_gimp(curr_layer, :))), pk.elev_smooth_gimp(curr_layer, ~isnan(pk.elev_smooth_gimp(curr_layer, :))), '.', 'color', colors(curr_layer, :), 'markersize', 24, 'visible', 'off');
            else
                p_pk(curr_layer)= plot(pk.dist_lin(~isnan(pk.elev_smooth(curr_layer, :))), pk.elev_smooth(curr_layer, ~isnan(pk.elev_smooth(curr_layer, :))), '.', 'color', colors(curr_layer, :), 'markersize', 24, 'visible', 'off');
            end
        end
        if (any(p_pkdepth([curr_layer tmp1])) && any(ishandle(p_pkdepth([curr_layer tmp1]))))
            delete(p_pkdepth([curr_layer tmp1]))
            if gimp_avail
                p_pkdepth(curr_layer) = plot(pk.dist_lin_gimp(~isnan(pk.depth_smooth(curr_layer, :))), pk.depth_smooth(curr_layer, ~isnan(pk.depth_smooth(curr_layer, :))), '.', 'color', colors(curr_layer, :), 'markersize', 24, 'visible', 'off');
            else
                p_pkdepth(curr_layer) = plot(pk.dist_lin(~isnan(pk.depth_smooth(curr_layer, :))), pk.depth_smooth(curr_layer, ~isnan(pk.depth_smooth(curr_layer, :))), '.', 'color', colors(curr_layer, :), 'markersize', 24, 'visible', 'off');
            end
        end
        if (flat_done && data_done)
            if (any(p_pkflat([curr_layer tmp1])) && any(ishandle(p_pkflat([curr_layer tmp1]))))
                delete(p_pkflat([curr_layer tmp1]))
            end
            if any(~isnan(depth_layer_flat(curr_layer, :)))
                if gimp_avail
                    p_pkflat(curr_layer)= plot(pk.dist_lin_gimp(ind_decim(~isnan(depth_layer_flat(curr_layer, :)))), depth_layer_flat(curr_layer, ~isnan(depth_layer_flat(curr_layer, :))), '.', 'color', colors(curr_layer, :), 'markersize', 24, 'visible', 'off');
                else
                    p_pkflat(curr_layer)= plot(pk.dist_lin(ind_decim(~isnan(depth_layer_flat(curr_layer, :)))), depth_layer_flat(curr_layer, ~isnan(depth_layer_flat(curr_layer, :))), '.', 'color', colors(curr_layer, :), 'markersize', 24, 'visible', 'off');
                end
            else
                p_pkflat(curr_layer) ...
                            = plot(0, 0, '.', 'markersize', 12, 'color', colors(ii, :), 'visible', 'off');
            end
            if isnan(depth_layer_ref(curr_layer))
                set(p_pkflat(curr_layer), 'markersize', 6)
            end
            edit_flag       = true;
        end
        for ii = 1:num_var_layer
            eval(['pk.' var_layer{ii} ' = pk.' var_layer{ii} '(setdiff(1:pk.num_layer, tmp1), :);']) % remove old layer
        end
        if gimp_avail
            for ii = 1:num_var_layer_gimp
                eval(['pk.' var_layer_gimp{ii} ' = pk.' var_layer_gimp{ii} '(setdiff(1:pk.num_layer, tmp1), :);']) % remove old layer
            end
        end
        [p_pk, p_pkdepth, colors] ...
                            = deal(p_pk(setdiff(1:pk.num_layer, tmp1)), p_pkdepth(setdiff(1:pk.num_layer, tmp1)), colors(setdiff(1:pk.num_layer, tmp1), :));
        if (flat_done && data_done)
            [p_pkflat, depth_layer_flat, depth_layer_ref] ...
                            = deal(p_pkflat(setdiff(1:pk.num_layer, tmp1)), depth_layer_flat(setdiff(1:pk.num_layer, tmp1), :), depth_layer_ref(setdiff(1:pk.num_layer, tmp1))');
        end
        if isrow(depth_layer_ref)
            depth_layer_ref = depth_layer_ref';
        end
        pk.num_layer        = pk.num_layer - 1;
        show_pk
        
        layer_str           = num2cell(1:pk.num_layer);
        for ii = 1:pk.num_layer
            if ~any(~isnan(pk.elev_smooth(ii, ind_decim)))
                layer_str{ii} ...
                            = [num2str(layer_str{ii}) ' H'];
            end
        end
        set(layer_list, 'string', layer_str, 'value', 1)
        set(status_box, 'string', ['Layers #' num2str(curr_layer) ' and #' num2str(tmp1) ' merged.'])
        if (curr_layer > tmp1)
            curr_layer      = curr_layer - 1;
        end
        if (isempty(curr_layer) || any(curr_layer < 1) || any(curr_layer > pk.num_layer))
            curr_layer      = 1;
        end
        set(layer_list, 'value', curr_layer)
        pk_select
    end

%% Split layer

    function pk_split(source, eventdata)
        
        if ~merge_done
            set(status_box, 'string', 'No layers to split yet. Load picks first.')
            return
        end
        
        set(status_box, 'string', ['Pick location to split layer #' num2str(curr_layer) ' (Q: cancel)...'])
        pause(0.1)
        
        axes(ax_radar)
        
        % get pick and convert to indices
        [ind_x_pk, ~, button] ...
                            = ginput(1);
        
        if strcmpi(char(button), 'Q')
            set(status_box, 'string', 'Layer splitting cancelled.')
            return
        end
        
        % get index position of ind_x_pk        
        if gimp_avail
            ind_x_pk        = interp1(pk.dist_lin_gimp(ind_decim), ind_decim, ind_x_pk, 'nearest', 'extrap');            
        else
            ind_x_pk        = interp1(pk.dist_lin(ind_decim), ind_decim, ind_x_pk, 'nearest', 'extrap');
        end
        
        % check split is worthwhile
        switch disp_type
            case 'elev.'
                if gimp_avail
                    if (all(isnan(pk.elev_smooth_gimp(curr_layer, 1:ind_x_pk))) || all(isnan(pk.elev_smooth_gimp(curr_layer, ind_x_pk:end))))
                        set(status_box, 'string', 'Aborted splitting because current layer is empty past split point.')
                        return
                    end
                elseif (all(isnan(pk.elev_smooth(curr_layer, 1:ind_x_pk))) || all(isnan(pk.elev_smooth(curr_layer, ind_x_pk:end))))
                    set(status_box, 'string', 'Aborted splitting because current layer is empty past split point.')
                    return
                end
            case 'depth'
                if (all(isnan(pk.depth_smooth(curr_layer, 1:ind_x_pk))) || all(isnan(pk.depth_smooth(curr_layer, ind_x_pk:end))))
                    set(status_box, 'string', 'Aborted splitting because current layer is empty past split point.')
                    return
                end
            case 'flat'
                if (all(isnan(depth_layer_flat(curr_layer, 1:ind_x_pk))) || all(isnan(depth_layer_flat(curr_layer, ind_x_pk:end))))
                    set(status_box, 'string', 'Aborted splitting because current layer is empty past split point.')
                    return
                end
        end
        
        pk.num_layer        = pk.num_layer + 1;        
        colors              = repmat(colors_def, ceil(pk.num_layer / size(colors_def, 1)), 1); % extend predefined color pattern
        colors              = colors(1:pk.num_layer, :);
        
        % assign layer variables in tmp1 that aren't NaN to the same layer variable in curr_layer
        for ii = 1:num_var_layer
            eval(['pk.' var_layer{ii} '(pk.num_layer, :) = NaN(1, pk.num_trace_tot);']);
            eval(['pk.' var_layer{ii} '(pk.num_layer, ind_x_pk:end) = pk.' var_layer{ii} '(curr_layer, ind_x_pk:end);']);
            eval(['pk.' var_layer{ii} '(curr_layer, ind_x_pk:end) = NaN;']);
        end
        if gimp_avail
            for ii = 1:num_var_layer_gimp
                eval(['pk.' var_layer_gimp{ii} '(pk.num_layer, :) = NaN(1, pk.num_trace_tot);']);
                eval(['pk.' var_layer_gimp{ii} '(pk.num_layer, ind_x_pk:end) = pk.' var_layer_gimp{ii} '(curr_layer, ind_x_pk:end);']);
                eval(['pk.' var_layer_gimp{ii} '(curr_layer, ind_x_pk:end) = NaN;']);
            end
        end
        if (flat_done && data_done)
            depth_layer_flat= [depth_layer_flat; NaN(1, num_decim)];
            depth_layer_flat(end, interp1(ind_decim, 1:num_decim, ind_x_pk, 'nearest', 'extrap'):end) ...
                            = depth_layer_flat(curr_layer, interp1(ind_decim, 1:num_decim, ind_x_pk, 'nearest', 'extrap'):end);
            depth_layer_flat(curr_layer, interp1(ind_decim, 1:num_decim, ind_x_pk, 'nearest', 'extrap'):end) ...
                            = NaN;
        end
        
        % redo plots
        if (logical(p_pk(curr_layer)) && ishandle(p_pk(curr_layer)))
            delete(p_pk(curr_layer))
            if gimp_avail
                p_pk(curr_layer)= plot(pk.dist_lin_gimp(~isnan(pk.elev_smooth_gimp(curr_layer, :))), pk.elev_smooth_gimp(curr_layer, ~isnan(pk.elev_smooth_gimp(curr_layer, :))), '.', 'color', colors(curr_layer, :), 'markersize', 24, 'visible', 'off');
            else
                p_pk(curr_layer)= plot(pk.dist_lin(~isnan(pk.elev_smooth(curr_layer, :))), pk.elev_smooth(curr_layer, ~isnan(pk.elev_smooth(curr_layer, :))), '.', 'color', colors(curr_layer, :), 'markersize', 24, 'visible', 'off');
            end
        end
        if gimp_avail
            p_pk(pk.num_layer) = plot(pk.dist_lin_gimp(~isnan(pk.elev_smooth_gimp(end, :))), pk.elev_smooth_gimp(end, ~isnan(pk.elev_smooth_gimp(end, :))), '.', 'color', colors(end, :), 'markersize', 24, 'visible', 'off');            
        else
            p_pk(pk.num_layer) = plot(pk.dist_lin(~isnan(pk.elev_smooth(end, :))), pk.elev_smooth(end, ~isnan(pk.elev_smooth(end, :))), '.', 'color', colors(end, :), 'markersize', 24, 'visible', 'off');
        end
        if (logical(p_pkdepth(curr_layer)) && ishandle(p_pkdepth(curr_layer)))
            delete(p_pkdepth(curr_layer))
            if gimp_avail
                p_pkdepth(curr_layer) = plot(pk.dist_lin_gimp(~isnan(pk.depth_smooth(curr_layer, :))), pk.depth_smooth(curr_layer, ~isnan(pk.depth_smooth(curr_layer, :))), '.', 'color', colors(curr_layer, :), 'markersize', 24, 'visible', 'off');
            else
                p_pkdepth(curr_layer) = plot(pk.dist_lin(~isnan(pk.depth_smooth(curr_layer, :))), pk.depth_smooth(curr_layer, ~isnan(pk.depth_smooth(curr_layer, :))), '.', 'color', colors(curr_layer, :), 'markersize', 24, 'visible', 'off');
            end
        end
        if gimp_avail
            p_pkdepth(pk.num_layer) = plot(pk.dist_lin_gimp(~isnan(pk.depth_smooth(end, :))), pk.depth_smooth(end, ~isnan(pk.depth_smooth(end, :))), '.', 'color', colors(end, :), 'markersize', 24, 'visible', 'off');
        else
            p_pkdepth(pk.num_layer) = plot(pk.dist_lin(~isnan(pk.depth_smooth(end, :))), pk.depth_smooth(end, ~isnan(pk.depth_smooth(end, :))), '.', 'color', colors(end, :), 'markersize', 24, 'visible', 'off');            
        end
        if (flat_done && data_done)
            if (logical(p_pkflat(curr_layer)) && ishandle(p_pkflat(curr_layer)))
                delete(p_pkflat(curr_layer))
            end
            if any(~isnan(depth_layer_flat(curr_layer, :)))
                if gimp_avail
                    p_pkflat(curr_layer) = plot(pk.dist_lin_gimp(ind_decim(~isnan(depth_layer_flat(curr_layer, :)))), depth_layer_flat(curr_layer, ~isnan(depth_layer_flat(curr_layer, :))), '.', 'color', colors(curr_layer, :), 'markersize', 24, 'visible', 'off');
                else
                    p_pkflat(curr_layer) = plot(pk.dist_lin(ind_decim(~isnan(depth_layer_flat(curr_layer, :)))), depth_layer_flat(curr_layer, ~isnan(depth_layer_flat(curr_layer, :))), '.', 'color', colors(curr_layer, :), 'markersize', 24, 'visible', 'off');
                end
            else
                p_pkflat(curr_layer) ...
                            = plot(0, 0, '.', 'markersize', 12, 'color', colors(ii, :), 'visible', 'off');
            end
            if isnan(depth_layer_ref(curr_layer))
                set(p_pkflat(curr_layer), 'markersize', 6)
            end
            if any(~isnan(depth_layer_flat(end, :)))
                if gimp_avail
                    p_pkflat(pk.num_layer) = plot(pk.dist_lin_gimp(ind_decim(~isnan(depth_layer_flat(end, :)))), depth_layer_flat(end, ~isnan(depth_layer_flat(end, :))), '.', 'color', colors(end, :), 'markersize', 24, 'visible', 'off');
                else
                    p_pkflat(pk.num_layer) = plot(pk.dist_lin(ind_decim(~isnan(depth_layer_flat(end, :)))), depth_layer_flat(end, ~isnan(depth_layer_flat(end, :))), '.', 'color', colors(end, :), 'markersize', 24, 'visible', 'off');
                end
            else
                p_pkflat(pk.num_layer) ...
                            = plot(0, 0, '.', 'markersize', 12, 'color', colors(ii, :), 'visible', 'off');
            end
            edit_flag       = true;
        end
        
        depth_layer_ref     = [depth_layer_ref; NaN];
        show_pk
        
        layer_str           = num2cell(1:pk.num_layer);
        for ii = 1:pk.num_layer
            if ~any(~isnan(pk.elev_smooth(ii, ind_decim)))
                layer_str{ii} ...
                    = [num2str(layer_str{ii}) ' H'];
            end
        end
        set(layer_list, 'string', layer_str, 'value', 1)
        set(status_box, 'string', ['Layer #' num2str(curr_layer) ' split.'])
        if (isempty(curr_layer) || any(curr_layer < 1) || any(curr_layer > pk.num_layer))
            curr_layer      = 1;
        end
        set(layer_list, 'value', curr_layer)
        pk_select
    end

%% Save merged picks

    function pk_save(source, eventdata)

        if ~merge_done
            set(status_box, 'string', 'Layers not merged yet, or need to be re-merged.')
            return
        end
        if edit_flag
            set(status_box, 'string', 'Layers merged or deleted since flattening. Re-flatten prior to saving.')
            return
        end
        
        reset_xz
        pause(0.1)
        
        % didn't get to flatten :(
        if ~flat_done
            set(status_box, 'string', 'Merged layers not flattened...continue saving? Y: yes; otherwise: no.')
            waitforbuttonpress
            if ~strcmpi(get(mgui, 'currentcharacter'), 'Y')
                set(status_box, 'string', 'Saving cancelled.')
                return
            end
            pk.poly_flat_merge ...
                            = [];
        end
        
        pk.merge_flag       = true; % will help when merged picks are loaded later
        pk.ind_x_ref        = ind_decim(ind_x_ref);
        pk                  = orderfields(pk);
        
        if isempty(path_save)
            if ispc
                if (exist([path_pk '..\..\merge'], 'dir') || exist([path_pk '..\..\..\merge'], 'dir'))
                    path_save = [path_pk(1:strfind(path_pk, '\pk')) 'merge\']; 
                end
            else
                if (exist([path_pk '../../merge'], 'dir') || exist([path_pk '../../../merge'], 'dir'))
                    path_save = [path_pk(1:strfind(path_pk, '/pk')) 'merge/']; 
                end
            end
        end

        if (~isempty(path_save) && ~isempty(file_save))
            [file_save, path_save] = uiputfile('*.mat', 'Save picks:', [path_save file_save]);
        elseif ~isempty(path_save)
            [file_save, path_save] = uiputfile('*.mat', 'Save picks:', [path_save file_pk_short '_pk_merge.mat']);
        elseif ~isempty(path_pk)
            [file_save, path_save] = uiputfile('*.mat', 'Save picks:', [path_pk file_pk_short '_pk_merge.mat']);
        elseif ~isempty(path_data)
            [file_save, path_save] = uiputfile('*.mat', 'Save picks:', [path_data file_pk_short '_pk_merge.mat']);
        else
            [file_save, path_save] = uiputfile('*.mat', 'Save picks:', [file_pk_short '_pk_merge.mat']);
        end
        
        if ~ischar(file_save)
            [file_save, path_save] ...
                            = deal('');
            set(status_box, 'string', 'Saving cancelled.')
        else
            
            set(status_box, 'string', 'Saving merged picks...')
            pause(0.1)
            
            save([path_save file_save], '-v7.3', 'pk')
            
            % make a simple figure that also gets saved
            set(0, 'DefaultFigureWindowStyle', 'default')
            pkfig           = figure('position', [10 10 1600 1000]);
            if gimp_avail
                imagesc(pk.dist_lin_gimp(ind_decim), elev, amp_elev, [db_min db_max])
            else
                imagesc(pk.dist_lin(ind_decim), elev, amp_elev, [db_min db_max])
            end
            hold on
            axis xy tight
            colormap(bone)
            for ii = 1:pk.num_layer
                if gimp_avail
                    plot(pk.dist_lin_gimp(ind_decim), pk.elev_smooth_gimp(ii, ind_decim), '.', 'color', colors(ii, :), 'markersize', 12)
                else
                    plot(pk.dist_lin(ind_decim), pk.elev_smooth(ii, ind_decim), '.', 'color', colors(ii, :), 'markersize', 12)
                end
            end
            tmp1            = find(~isnan(ind_int));
            for ii = 1:num_int
                if gimp_avail
                    plot(pk.dist_lin_gimp(ind_int(tmp1(ii))), get(gca, 'ylim'), 'm', 'linewidth', 2)
                    text(double(pk.dist_lin_gimp(ind_int(tmp1(ii))) + 1), double(elev_max_ref - 250), name_core{int_core{curr_year}{curr_trans}(tmp1(ii), 3)}, 'color', 'm', 'fontsize', size_font)
                else
                    plot(pk.dist_lin(ind_int(tmp1(ii))), get(gca, 'ylim'), 'm', 'linewidth', 2)
                    text((pk.dist_lin(ind_int(tmp1(ii))) + 1), (elev_max_ref - 250), name_core{int_core{curr_year}{curr_trans}(tmp1(ii), 3)}, 'color', 'm', 'fontsize', size_font)
                end
            end
            set(gca, 'fontsize', 18)
            xlabel('Distance (km)')
            ylabel('Elevation (m)')
            title(file_pk_short, 'fontweight', 'bold', 'interpreter', 'none')
            grid on
            box on
            print(pkfig, '-dpng', [path_save file_save(1:(end - 4)) '.png'])
            
            set(status_box, 'string', ['Merged picks saved as ' file_save(1:(end - 4)) ' in ' path_save '.'])
            
        end
    end

%% Load core intersection data

    function load_core(source, eventdata)
        
        if core_done
            set(status_box, 'string', 'Core intersections already loaded.')
            return
        end
        
        if merge_file
            if ispc
                if (~isempty(path_pk) && exist([path_pk '..\..\mat'], 'dir'))
                    path_core = [path_pk '..\..\mat\'];
                end
            else
                if (~isempty(path_pk) && exist([path_pk '../../mat/'], 'dir'))
                    path_core = [path_pk '../../mat/'];
                end
            end
        else
            if ispc
                if (~isempty(path_pk) && exist([path_pk '..\..\..\mat\'], 'dir'))
                    path_core = [path_pk '..\..\..\mat\'];
                elseif (~isempty(path_pk) && exist([path_pk '..\..\..\..\mat\'], 'dir'))
                    path_core = [path_pk '..\..\..\..\mat\'];
                end
            else
                if (~isempty(path_pk) && exist([path_pk '../../../mat/'], 'dir'))
                    path_core = [path_pk '../../../mat/'];
                elseif (~isempty(path_pk) && exist([path_pk '../../../../mat/'], 'dir'))
                    path_core = [path_pk '../../../../mat/'];
                end
            end
        end
        
        if (~isempty(path_core) && exist([path_core 'core_int.mat'], 'file'))
            file_core       = 'core_int.mat';
        else
            % Dialog box to choose picks file to load
            if ~isempty(path_core)
                [file_core, path_core] = uigetfile('*.mat', 'Load core intersections (core_int.mat):', path_core);
            elseif ~isempty(path_pk)
                [file_core, path_core] = uigetfile('*.mat', 'Load core intersections (core_int.mat):', path_pk);
            elseif ~isempty(path_data)
                [file_core, path_core] = uigetfile('*.mat', 'Load core intersections (core_int.mat):', path_data);
            else
                [file_core, path_core] = uigetfile('*.mat', 'Load core intersections (core_int.mat):');
            end
            if isnumeric(file_core)
                [file_core, path_core] = deal('');
            end
        end
        
        if ~isempty(file_core)
            
            set(status_box, 'string', 'Loading core intersections...')
            pause(0.1)
            
            % load core intersection file
            tmp1        = load([path_core file_core]);
            try
                [int_core, name_core, rad_threshold, name_trans, num_core, num_trans, num_year] ...
                        = deal(tmp1.int_core, tmp1.name_core, tmp1.rad_threshold, tmp1.name_trans, tmp1.num_core, tmp1.num_trans, tmp1.num_year);
            catch % give up, force restart
                set(status_box, 'string', [file_core ' does not contain the expected variables. Try again.'])
                return
            end
            
            load_core_breakout
            
        else
            set(status_box, 'string', 'No core intersections loaded.')
        end
    end

%% Load core breakout

    function load_core_breakout(source, eventdata)
        
        if merge_done
            
            if (any(p_core) && any(ishandle(p_core)))
                delete(p_core(logical(p_core) & ishandle(p_core)))
            end
            if (any(p_corename) && any(ishandle(p_corename)))
                delete(p_corename(logical(p_corename) & ishandle(p_corename)))
            end
            if (any(p_coreflat) && any(ishandle(p_coreflat)))
                delete(p_coreflat(logical(p_coreflat) & ishandle(p_coreflat)))
            end
            if (any(p_corenameflat) && any(ishandle(p_corenameflat)))
                delete(p_corenameflat(logical(p_corenameflat) & ishandle(p_corenameflat)))
            end
            
            % determine current year/transect
            tmp1            = file_pk_short;
            tmp2            = 'fail';
            if (isnan(str2double(tmp1(end))) || ~isreal(str2double(tmp1(end))))
                tmp3        = tmp1(end);
                tmp1        = tmp1(1:(end - 1));
            else
                tmp3        = 0;
            end
            for ii = 1:num_year
                for jj = 1:num_trans(ii)
                    if strcmp(tmp1, name_trans{ii}{jj})
                        break
                    end
                end
                if strcmp(tmp1, name_trans{ii}{jj})
                    tmp2    = 'success';
                    break
                end
            end
            
            if strcmp(tmp2, 'fail')
                set(status_box, 'string', 'Transect not identified. Try again.')
                return
            end
            
            % fix for 2011 P3/TO ambiguity
            if (ii == 17)
                set(status_box, 'string', '2011 TO (press T)?')
                waitforbuttonpress
                if strcmpi(get(mgui, 'currentcharacter'), 'T')
                    tmp2    = 'fail';
                    ii      = 18;
                    for jj = 1:num_trans(ii)
                        if strcmp(tmp1, name_trans{ii}{jj})
                            tmp2 ...
                            = 'success';
                            break
                        end
                    end
                    if strcmp(tmp2, 'fail')
                        set(status_box, 'string', 'Transect incorrectly identified as 2011 TO. Try again.')
                        return
                    end
                end
            end
            
            [curr_year, curr_trans] ...
                            = deal(ii, jj);
            if ischar(tmp3)
                for ii = 1:length(tmp1)
                    if strcmp(tmp3, letters(ii))
                        curr_subtrans ...
                                = ii;
                        break
                    end
                end
            else
                curr_subtrans = 1;
            end
            
            if ~isempty(int_core{curr_year}{curr_trans})
                
                ind_int     = NaN(1, size(int_core{curr_year}{curr_trans}, 1));
                for ii = 1:size(int_core{curr_year}{curr_trans}, 1)
                    try %#ok<TRYNC>
                        [tmp1, tmp2]= min(sqrt(((pk.x_gimp - int_core{curr_year}{curr_trans}(ii, 4)) .^ 2) + ((pk.y_gimp - int_core{curr_year}{curr_trans}(ii, 5)) .^ 2)));
                        if (tmp1 < rad_threshold)
                            ind_int(ii) = tmp2;
                        end
                    end
                end
                
                num_int     = length(find(~isnan(ind_int)));
                
                if ~num_int
                    core_done ...
                            = true;
                    set(core_check, 'value', 1)
                    set(status_box, 'string', 'Core intersections loaded but none for this transect.')
                    return
                end
                
                [p_core, p_corename] ...
                            = deal(zeros(1, num_int));
                if gimp_avail
                    tmp1    = pk.dist_lin_gimp;
                else
                    tmp1    = pk.dist_lin;
                end
                
                tmp2        = find(~isnan(ind_int));
                
                for ii = 1:num_int
                    p_core(ii) ...
                            = plot(repmat(tmp1(ind_int(tmp2(ii))), 1, 2), [elev_min_ref elev_max_ref], 'm', 'linewidth', 2, 'visible', 'off');
                    p_corename(ii) ...
                            = text(double(tmp1(ind_int(tmp2(ii))) + 1), double(elev_max_ref - 250), name_core(int_core{curr_year}{curr_trans}(tmp2(ii), 3)), 'color', 'm', 'fontsize', size_font, 'visible', 'off');
                end
                
                if data_done
                    for ii = 1:num_int
                        p_coreflat(ii) ...
                            = plot(repmat(tmp1(ind_int(tmp2(ii))), 1, 2), [depth_min_ref depth_max_ref], 'm', 'linewidth', 2, 'visible', 'off');
                        p_corenameflat(ii) ...
                            = text((tmp1(ind_int(tmp2(ii))) + 1), (depth_min_ref + 250), name_core{int_core{curr_year}{curr_trans}(tmp2(ii), 3)}, 'color', 'm', 'fontsize', size_font, 'visible', 'off');
                    end
                end
                
                core_done   = true;
                set(core_check, 'value', 1)
                show_core
                set(status_box, 'string', ['Core intersections loaded. ' num2str(num_int) ' for this transect within ' num2str(rad_threshold) ' km.'])
                
            else
                core_done   = true;
                set(core_check, 'value', 1)
                set(status_box, 'string', 'Core intersections loaded but none for this transect.')
            end
            
        else
            core_done       = true;
            set(core_check, 'value', 1)
            show_core
            set(status_box, 'string', 'Core intersections loaded.')
        end
    end

%% Load layer age data

    function load_age(source, eventdata)
        
        if ~core_done
            set(status_box, 'string', 'Load core intersections first.')
            return
        end
        
        if merge_file
            if ispc
                if (~isempty(path_pk) && exist([path_pk '..\..\mat'], 'dir'))
                    path_age = [path_pk '..\..\mat\'];
                end
            else
                if (~isempty(path_pk) && exist([path_pk '../../mat/'], 'dir'))
                    path_age = [path_pk '../../mat/'];
                end
            end
        else
            if ispc
                if (~isempty(path_pk) && exist([path_pk '..\..\..\mat\'], 'dir'))
                    path_age = [path_pk '..\..\..\mat\'];
                elseif (~isempty(path_pk) && exist([path_pk '..\..\..\..\mat\'], 'dir'))
                    path_age = [path_pk '..\..\..\..\mat\'];
                end
            else
                if (~isempty(path_pk) && exist([path_pk '../../../mat/'], 'dir'))
                    path_age = [path_pk '../../../mat/'];
                elseif (~isempty(path_pk) && exist([path_pk '../../../../mat/'], 'dir'))
                    path_age = [path_pk '../../../../mat/'];
                end
            end
        end
        
        if (~isempty(path_age) && exist([path_age 'date_all.mat'], 'file'))
            file_age        = 'date_all.mat';
        else
            % Dialog box to choose picks file to load
            if ~isempty(path_age)
                [file_age, path_age] = uigetfile('*.mat', 'Load layer ages (date_all.mat):', path_age);
            elseif ~isempty(path_core)
                [file_age, path_age] = uigetfile('*.mat', 'Load layer ages (date_all.mat):', path_core);
            elseif ~isempty(path_pk)
                [file_age, path_age] = uigetfile('*.mat', 'Load layer ages (date_all.mat):', path_pk);
            else
                [file_age, path_age] = uigetfile('*.mat', 'Load layer ages (date_all.mat):');
            end
            if isnumeric(file_age)
                [file_age, path_age] = deal('');
            end
        end
        
        if ~isempty(file_age)
            
            set(status_box, 'string', 'Loading layer ages...')
            pause(0.1)
            
            % load layer ages file
            tmp1        = load([path_age file_age]);
            try
                age     = tmp1.age;
            catch % give up, force restart
                set(status_box, 'string', [file_age ' does not contain the expected variables. Try again.'])
                return
            end
            
            load_age_breakout
            
        else
            set(status_box, 'string', 'No layer ages loaded.')
        end
    end

%% Load layer ages breakout

    function load_age_breakout(source, eventdata)
        
        if merge_done
            
            % determine current year/transect
            tmp1            = file_pk_short;
            tmp2            = 'fail';
            if (isnan(str2double(tmp1(end))) || ~isreal(str2double(tmp1(end))))
                tmp3        = tmp1(end);
                tmp1        = tmp1(1:(end - 1));
            else
                tmp3        = 0;
            end
            for ii = 1:num_year
                for jj = 1:num_trans(ii)
                    if strcmp(tmp1, name_trans{ii}{jj})
                        break
                    end
                end
                if strcmp(tmp1, name_trans{ii}{jj})
                    tmp2    = 'success';
                    break
                end
            end
            
            if strcmp(tmp2, 'fail')
                set(status_box, 'string', 'Transect not identified. Try again.')
                return
            end
            
            % fix for 2011 P3/TO ambiguity
            if (ii == 17)
                set(status_box, 'string', '2011 TO (press T)?')
                waitforbuttonpress
                if strcmpi(get(mgui, 'currentcharacter'), 'T')
                    tmp2    = 'fail';
                    ii      = 18;
                    for jj = 1:num_trans(ii)
                        if strcmp(tmp1, name_trans{ii}{jj})
                            tmp2 ...
                            = 'success';
                            break
                        end
                    end
                    if strcmp(tmp2, 'fail')
                        set(status_box, 'string', 'Transect incorrectly identified as 2011 TO. Try again.')
                        return
                    end
                end
            end
            
            [curr_year, curr_trans] ...
                            = deal(ii, jj);
            if ischar(tmp3)
                for ii = 1:length(tmp1)
                    if strcmp(tmp3, letters(ii))
                        curr_subtrans ...
                            = ii;
                        break
                    end
                end
            else
                curr_subtrans ...
                            = 1;
            end
            
            if ~isempty(age{curr_year}{curr_trans}{curr_subtrans})
                age_curr    = age{curr_year}{curr_trans}{curr_subtrans};
                age_done    = true;
                set(status_box, 'string', 'Layer ages for this transect found.')
            else
                set(status_box, 'string', 'Layer ages loaded but none for this transect.')
            end
            
        else
            age_done        = true;
            set(status_box, 'string', 'Layer ages loaded.')
        end
    end

%% SNR analysis

    function snr(source, eventdata)
        
        if (~merge_file || ~core_done || ~data_done || ~num_int)
            set(status_box, 'string', 'Only do SNR analysis on a fully merged file with core intersections and data loaded.')
            return
        end
        
        path_snr            = path_core;
        
        if exist([path_snr 'snr_all.mat'], 'file')
            file_snr        = 'snr_all.mat';
        else
            % Dialog box to choose picks file to load
            if ~isempty(path_snr)
                [file_snr, path_snr] = uigetfile('*.mat', 'Load SNR data (snr_all.mat):', path_snr);
            elseif ~isempty(path_core)
                [file_snr, path_snr] = uigetfile('*.mat', 'Load SNR data (snr_all.mat):', path_core);
            else
                [file_snr, path_snr] = uigetfile('*.mat', 'Load SNR data (snr_all.mat):');
            end
            if isnumeric(file_snr)
                [file_snr, path_snr] = deal('');
            end
        end
        
        if isempty(file_snr)
            set(status_box, 'string', 'No SNR data loaded.')
            return
        end
        
        set(status_box, 'string', 'Starting SNR analysis...')
        pause(0.1)
        
        % load core intersection file
        tmp1                = load([path_snr file_snr]);
        try
            snr_all         = deal(tmp1.snr_all);
        catch % give up, force restart
            set(status_box, 'string', [file_snr ' does not contain the expected variables. Try again.'])
            return
        end
        
        set(status_box, 'string', 'SNR data loaded.')
        pause(0.1)
        
        set(0, 'DefaultFigureWindowStyle', 'default')
        
        tmp2                = find(~isnan(ind_int));
        
        [p_snr, tmp3]       = deal(cell(1, num_int));
        snrlist             = zeros(1, num_int);
        snr_all{curr_year}{curr_trans}{curr_subtrans} ...
                            = NaN(pk.num_layer, num_core);
        
        for ii = 1:num_int
            
            tmp1            = interp1(ind_decim, 1:num_decim, ind_int(tmp2(ii)), 'nearest', 'extrap');
            tmp3{ii}        = find(~isnan(pk.elev_gimp(:, ind_int(tmp2(ii)))));
            
            p_snr{ii}       = zeros(length(tmp3{ii}), 2);
            
            snrgui(ii)      = figure('position', [(50 + ((ii - 1) * 50)) (50 + ((ii - 1) * 50)) 800 1000]);
            axes('position', [0.12 0.1 0.7 0.8]) %#ok<LAXES>
            hold on
            plot(amp_elev(:, tmp1), elev, 'k', 'linewidth', 2)
            for jj = 1:length(tmp3{ii})
                p_snr{ii}(jj, 1) ...
                            = plot(amp_elev(interp1(elev, num_sample, pk.elev_gimp(tmp3{ii}(jj), ind_int(tmp2(ii))), 'nearest', 'extrap'), tmp1), pk.elev_gimp(tmp3{ii}(jj), ind_int(tmp2(ii))), 'ko', 'markersize', 8, 'markerfacecolor', 'r');
            end
            set(gca, 'fontsize', 20)
            xlabel('Returned power (dB)')
            ylabel('Elevation (m)')
            title(name_core{int_core{curr_year}{curr_trans}(tmp2(ii), 3)}, 'fontweight', 'bold')
            grid on
            box on
            snrlist(ii)     = uicontrol(snrgui(ii), 'style', 'popupmenu', 'string', num2cell(tmp3{ii}), 'value', 1, 'units', 'normalized', 'position', [0.88 0.85 0.1 0.05], 'fontsize', size_font, 'foregroundcolor', 'k', 'callback', eval(['@choose_snr' num2str(ii)]));
            uicontrol(snrgui(ii), 'style', 'pushbutton', 'string', 'Pick', 'units', 'normalized', 'position', [0.88 0.75 0.1 0.05], 'callback', eval(['@do_snr' num2str(ii)]), 'fontsize', size_font, 'foregroundcolor', 'm')                                    
            uicontrol(snrgui(ii), 'style', 'pushbutton', 'string', 'Save', 'units', 'normalized', 'position', [0.88 0.1 0.1 0.05], 'callback', @save_snr, 'fontsize', size_font, 'foregroundcolor', 'g')
        end
        
        set(0, 'DefaultFigureWindowStyle', 'docked')
        
    end

    function choose_snr1(source, eventdata) %#ok<DEFNU>
        ii                  = 1;
        choose_snr
    end

    function choose_snr2(source, eventdata) %#ok<DEFNU>
        ii                  = 2;
        choose_snr
    end

    function choose_snr3(source, eventdata) %#ok<DEFNU>
        ii                  = 3;
        choose_snr
    end

    function choose_snr(source, eventdata)
        tmp5                = tmp3{ii}(get(snrlist(ii), 'value'));
        set(p_snr{ii}(:, 1), 'markersize', 8, 'markerfacecolor', 'r')
        set(p_snr{ii}(get(snrlist(ii), 'value'), 1), 'markersize', 16, 'markerfacecolor', 'b')
        pause(0.1)
    end

    function do_snr1(source, eventdata) %#ok<DEFNU>
        ii                  = 1;
        do_snr
    end

    function do_snr2(source, eventdata) %#ok<DEFNU>
        ii                  = 2;
        do_snr
    end

    function do_snr3(source, eventdata) %#ok<DEFNU>
        ii                  = 3;
        do_snr
    end

    function do_snr(source, eventdata)
        [~, tmp4]           = ginput(1);
        tmp4                = interp1(elev, 1:length(elev), tmp4, 'nearest', 'extrap');
        set(p_snr{ii}(get(snrlist(ii), 'value'), 1), 'markersize', 8, 'markerfacecolor', 'g')
        if (logical(p_snr{ii}(get(snrlist(ii), 'value'), 2)) && ishandle(p_snr{ii}(get(snrlist(ii), 'value'), 2)))
            delete(p_snr{ii}(get(snrlist(ii), 'value'), 2))
        end
        p_snr{ii}(get(snrlist(ii), 'value'), 2) ...
                            = plot(amp_elev(tmp4, interp1(ind_decim, 1:num_decim, ind_int(tmp2(ii)), 'nearest', 'extrap')), elev(tmp4), 'ks', 'markersize', 12, 'markerfacecolor', 'm');
        snr_all{curr_year}{curr_trans}{curr_subtrans}(tmp5, int_core{curr_year}{curr_trans}(tmp2(ii), 3)) ...
                            = amp_elev(interp1(elev, 1:num_sample, pk.elev_gimp(tmp5, ind_int(tmp2(ii))), 'nearest', 'extrap'), interp1(ind_decim, 1:num_decim, ind_int(tmp2(ii)), 'nearest', 'extrap')) - ...
                              amp_elev(tmp4, interp1(ind_decim, 1:num_decim, ind_int(tmp2(ii)), 'nearest', 'extrap')); %#ok<SETNU>
    end

    function save_snr(source, eventdata)
        save([path_snr file_snr], '-v7.3', 'snr_all')
        set(status_box, 'string', ['SNR data saved as ' path_snr file_snr '.'])
    end

%% Update minimum elevation/depth value

    function slide_z_min(source, eventdata)
        switch disp_type
            case 'elev.'
                if (get(z_min_slide, 'value') < elev_max)
                    if get(zfix_check, 'value')
                        tmp1        = elev_max - elev_min;
                    end
                    elev_min        = get(z_min_slide, 'value');
                    if get(zfix_check, 'value')
                        elev_max    = elev_min + tmp1;
                        if (elev_max > elev_max_ref)
                            elev_max = elev_max_ref;
                            elev_min = elev_max - tmp1;
                            if (elev_min < elev_min_ref)
                                elev_min = elev_min_ref;
                            end
                            if (elev_min < get(z_min_slide, 'min'))
                                set(z_min_slide, 'value', get(z_min_slide, 'min'))
                            else
                                set(z_min_slide, 'value', elev_min)
                            end
                        end
                        set(z_max_edit, 'string', sprintf('%4.0f', elev_max))
                        if (elev_max > get(z_max_slide, 'max'))
                            set(z_max_slide, 'value', get(z_max_slide, 'max'))
                        else
                            set(z_max_slide, 'value', elev_max)
                        end
                    end
                    set(z_min_edit, 'string', sprintf('%4.0f', elev_min))
                    update_z_range
                else
                    if (elev_min < get(z_min_slide, 'min'))
                        set(z_min_slide, 'value', get(z_min_slide, 'min'))
                    else
                        set(z_min_slide, 'value', elev_min)
                    end
                end
            case {'depth' 'flat'}
                if ((depth_max_ref - (get(z_min_slide, 'value') - depth_min_ref)) > depth_min)
                    if get(zfix_check, 'value')
                        tmp1        = depth_max - depth_min;
                    end
                    depth_max       = depth_max_ref - (get(z_min_slide, 'value') - depth_min_ref);
                    if get(zfix_check, 'value')
                        depth_min    = depth_max - tmp1;
                        if (depth_min < depth_min_ref)
                            depth_min = depth_min_ref;
                            depth_max = depth_min + tmp1;
                            if (depth_max > depth_max_ref)
                                depth_max = depth_max_ref;
                            end
                            if ((depth_max_ref - (depth_max - depth_min_ref)) < get(z_min_slide, 'min'))
                                set(z_min_slide, 'value', get(z_min_slide, 'min'))
                            elseif ((depth_max_ref - (depth_max - depth_min_ref)) > get(z_min_slide, 'max'))
                                set(z_min_slide, 'value', get(z_min_slide, 'max'))
                            else
                                set(z_min_slide, 'value', (depth_max_ref - (depth_max - depth_min_ref)))
                            end
                        end
                        set(z_min_edit, 'string', sprintf('%4.0f', depth_max))
                        if ((depth_max_ref - (depth_min - depth_min_ref)) < get(z_max_slide, 'min'))
                            set(z_max_slide, 'value', get(z_max_slide, 'min'))
                        elseif ((depth_max_ref - (depth_min - depth_min_ref)) > get(z_max_slide, 'max'))
                            set(z_max_slide, 'value', get(z_max_slide, 'max'))
                        else
                            set(z_max_slide, 'value', (depth_max_ref - (depth_min - depth_min_ref)))
                        end
                    end
                    set(z_min_edit, 'string', sprintf('%4.0f', depth_max))
                    update_z_range
                else
                    if ((depth_max_ref - (depth_max - depth_min_ref)) < get(z_min_slide, 'min'))
                        set(z_min_slide, 'value', get(z_min_slide, 'min'))
                    elseif ((depth_max_ref - (depth_max - depth_min_ref)) > get(z_min_slide, 'max'))
                        set(z_min_slide, 'value', get(z_min_slide, 'max'))
                    else
                        set(z_min_slide, 'value', (depth_max_ref - (depth_max - depth_min_ref)))
                    end
                end
        end
        set(z_min_slide, 'enable', 'off')
        drawnow
        set(z_min_slide, 'enable', 'on')
    end

%% Update maximum elevation/depth value

    function slide_z_max(source, eventdata)
        switch disp_type
            case 'elev.'
                if (get(z_max_slide, 'value') > elev_min)
                    if get(zfix_check, 'value')
                        tmp1        = elev_max - elev_min;
                    end
                    elev_max        = get(z_max_slide, 'value');
                    if get(zfix_check, 'value')
                        elev_min    = elev_max - tmp1;
                        if (elev_min < elev_min_ref)
                            elev_min = elev_min_ref;
                            elev_max = elev_min + tmp1;
                            if (elev_max > elev_max_ref)
                                elev_max = elev_max_ref;
                            end
                            if (elev_max > get(z_max_slide, 'max'))
                                set(z_max_slide, 'value', get(z_max_slide, 'max'))
                            else
                                set(z_max_slide, 'value', elev_max)
                            end
                        end
                        set(z_min_edit, 'string', sprintf('%4.0f', elev_min))
                        if (elev_min < get(z_min_slide, 'min'))
                            set(z_min_slide, 'value', get(z_min_slide, 'min'))
                        else
                            set(z_min_slide, 'value', elev_min)
                        end
                    end
                    set(z_max_edit, 'string', sprintf('%4.0f', elev_max))
                    update_z_range
                else
                    if (elev_max > get(z_max_slide, 'max'))
                        set(z_max_slide, 'value', get(z_max_slide, 'max'))
                    else
                        set(z_max_slide, 'value', elev_max)
                    end
                end
            case {'depth' 'flat'}
                if ((depth_max_ref - (get(z_max_slide, 'value') - depth_min_ref)) < depth_max)
                    if get(zfix_check, 'value')
                        tmp1        = depth_max - depth_min;
                    end
                    depth_min       = depth_max_ref - (get(z_max_slide, 'value') - depth_min_ref);
                    if get(zfix_check, 'value')
                        depth_max   = depth_min + tmp1;
                        if (depth_max > depth_max_ref)
                            depth_max = depth_max_ref;
                            depth_min = depth_max - tmp1;
                            if (depth_min < depth_min_ref)
                                depth_min = depth_min_ref;
                            end
                            if ((depth_max_ref - (depth_min - depth_min_ref)) < get(z_max_slide, 'min'))
                                set(z_max_slide, 'value', get(z_max_slide, 'min'))
                            elseif ((depth_max_ref - (depth_min - depth_min_ref)) > get(z_max_slide, 'max'))
                                set(z_max_slide, 'value', get(z_max_slide, 'max'))
                            else
                                set(z_max_slide, 'value', (depth_max_ref - (depth_min - depth_min_ref)))
                            end
                        end
                        set(z_min_edit, 'string', sprintf('%4.0f', depth_max))
                        if ((depth_max_ref - (depth_max - depth_min_ref)) < get(z_min_slide, 'min'))
                            set(z_min_slide, 'value', get(z_min_slide, 'min'))
                        elseif ((depth_max_ref - (depth_max - depth_min_ref)) > get(z_min_slide, 'max'))
                            set(z_min_slide, 'value', get(z_min_slide, 'max'))
                        else
                            set(z_min_slide, 'value', (depth_max_ref - (depth_max - depth_min_ref)))
                        end
                    end
                    set(z_max_edit, 'string', sprintf('%4.0f', depth_min))
                    update_z_range
                else
                    if ((depth_max_ref - (depth_min - depth_min_ref)) < get(z_max_slide, 'min'))
                        set(z_max_slide, 'value', get(z_max_slide, 'min'))
                    elseif ((depth_max_ref - (depth_min - depth_min_ref)) > get(z_max_slide, 'max'))
                        set(z_max_slide, 'value', get(z_max_slide, 'max'))
                    else
                        set(z_max_slide, 'value', (depth_max_ref - (depth_min - depth_min_ref)))
                    end
                end
        end
        set(z_max_slide, 'enable', 'off')
        drawnow
        set(z_max_slide, 'enable', 'on')
    end

%% Reset minimum elevation/depth value

    function reset_z_min(source, eventdata)
        elev_min            = elev_min_ref;
        depth_max           = depth_max_ref;
        switch disp_type
            case 'elev.'
                if (elev_min_ref < get(z_min_slide, 'min'))
                    set(z_min_slide, 'value', get(z_min_slide, 'min'))
                else
                    set(z_min_slide, 'value', elev_min_ref)
                end
                set(z_min_edit, 'string', sprintf('%4.0f', elev_min_ref))
            case {'depth' 'flat'}
                if (depth_min_ref < get(z_min_slide, 'min'))
                    set(z_min_slide, 'value', get(z_min_slide, 'min'))
                elseif (depth_min_ref > get(z_min_slide, 'max'))
                    set(z_min_slide, 'value', get(z_min_slide, 'max'))
                else
                    set(z_min_slide, 'value', depth_min_ref)
                end
                set(z_min_edit, 'string', sprintf('%4.0f', depth_max_ref))
        end
        update_z_range
    end

%% Reset maximum elevation/depth value

    function reset_z_max(source, eventdata)
        elev_max            = elev_max_ref;
        depth_min           = depth_min_ref;
        switch disp_type
            case 'elev.'
                if (elev_max_ref > get(z_max_slide, 'max'))
                    set(z_max_slide, 'value', get(z_max_slide, 'max'))
                else
                    set(z_max_slide, 'value', elev_max_ref)
                end
                set(z_max_edit, 'string', sprintf('%4.0f', elev_max_ref))
            case {'depth' 'flat'}
                if (depth_max_ref < get(z_max_slide, 'min'))
                    set(z_max_slide, 'value', get(z_max_slide, 'min'))
                elseif (depth_max_ref > get(z_max_slide, 'max'))
                    set(z_max_slide, 'value', get(z_max_slide, 'max'))
                else
                    set(z_max_slide, 'value', depth_max_ref)
                end
                set(z_max_edit, 'string', sprintf('%4.0f', depth_min_ref))
        end
        update_z_range
    end

%% Update elevation/depth-axis range

    function update_z_range(source, eventdata)
        axes(ax_radar)
        switch disp_type
            case 'elev.'
                ylim([elev_min elev_max])
            case {'depth' 'flat'}
                ylim([depth_min depth_max])
        end
        narrow_cb
    end

%% Update minimum color scale

    function slide_cb_min(source, eventdata)
        switch cb_type
            case 'std'
                if (get(cb_min_slide, 'value') < db_max)
                    if get(cbfix_check1, 'value')
                        tmp1= db_max - db_min;
                    end
                    db_min  = get(cb_min_slide, 'value');
                    if get(cbfix_check1, 'value')
                        db_max = db_min + tmp1;
                        if (db_max > db_max_ref)
                            db_max  = db_max_ref;
                            db_min  = db_max - tmp1;
                            if (db_min < db_min_ref)
                                db_min = db_min_ref;
                            end
                            if (db_min < get(cb_min_slide, 'min'))
                                set(cb_min_slide, 'value', get(cb_min_slide, 'min'))
                            else
                                set(cb_min_slide, 'value', db_min)
                            end
                        end
                        set(cb_max_edit, 'string', sprintf('%3.0f', db_max))
                        if (db_max > get(cb_max_slide, 'max'))
                            set(cb_max_slide, 'value', get(cb_max_slide, 'max'))
                        else
                            set(cb_max_slide, 'value', db_max)
                        end
                    end
                    set(cb_min_edit, 'string', sprintf('%3.0f', db_min))
                    update_cb_range
                else
                    if (db_min < get(cb_min_slide, 'min'))
                        set(cb_min_slide, 'value', get(cb_min_slide, 'min'))
                    else
                        set(cb_min_slide, 'value', db_min)
                    end
                end
            case 'age'
                if (get(cb_min_slide, 'value') < age_max)
                    if get(cbfix_check1, 'value')
                        tmp1= age_max - age_min;
                    end
                    age_min = get(cb_min_slide, 'value');
                    if get(cbfix_check1, 'value')
                        age_max = age_min + tmp1;
                        if (age_max > age_max_ref)
                            age_max  = age_max_ref;
                            age_min  = age_max - tmp1;
                            if (age_min < age_min_ref)
                                age_min = age_min_ref;
                            end
                            if (age_min < get(cb_min_slide, 'min'))
                                set(cb_min_slide, 'value', get(cb_min_slide, 'min'))
                            else
                                set(cb_min_slide, 'value', age_min)
                            end
                        end
                        set(cb_max_edit, 'string', sprintf('%3.0f', age_max))
                        if (age_max > get(cb_max_slide, 'max'))
                            set(cb_max_slide, 'value', get(cb_max_slide, 'max'))
                        else
                            set(cb_max_slide, 'value', age_max)
                        end
                    end
                    set(cb_min_edit, 'string', sprintf('%3.0f', age_min))
                    update_cb_range
                else
                    if (age_min < get(cb_min_slide, 'min'))
                        set(cb_min_slide, 'value', get(cb_min_slide, 'min'))
                    else
                        set(cb_min_slide, 'value', age_min)
                    end
                end
        end
        set(cb_min_slide, 'enable', 'off')
        drawnow
        set(cb_min_slide, 'enable', 'on')
    end

%% Update maximum color scale

    function slide_cb_max(source, eventdata)
        switch cb_type
            case 'std'
                if (get(cb_max_slide, 'value') > db_min)
                    if get(cbfix_check1, 'value')
                        tmp1= db_max - db_min;
                    end
                    db_max  = get(cb_max_slide, 'value');
                    if get(cbfix_check1, 'value')
                        db_min = db_max - tmp1;
                        if (db_min < db_min_ref)
                            db_min  = db_min_ref;
                            db_max  = db_min + tmp1;
                            if (db_max > db_max_ref)
                                db_max = db_max_ref;
                            end
                            if (db_max > get(cb_max_slide, 'max'))
                                set(cb_max_slide, 'value', get(cb_max_slide, 'max'))
                            else
                                set(cb_max_slide, 'value', db_max)
                            end
                        end
                        set(cb_min_edit, 'string', sprintf('%3.0f', db_min))
                        if (db_min < get(cb_min_slide, 'min'))
                            set(cb_min_slide, 'value', get(cb_min_slide, 'min'))
                        else
                            set(cb_min_slide, 'value', db_min)
                        end
                    end
                    set(cb_max_edit, 'string', sprintf('%3.0f', db_max))
                    update_cb_range
                else
                    if (db_max > get(cb_max_slide, 'max'))
                        set(cb_max_slide, 'value', get(cb_max_slide, 'max'))
                    else
                        set(cb_max_slide, 'value', db_max)
                    end
                end
            case 'age'
                if (get(cb_max_slide, 'value') > age_min)
                    if get(cbfix_check1, 'value')
                        tmp1= age_max - age_min;
                    end
                    age_max = get(cb_max_slide, 'value');
                    if get(cbfix_check1, 'value')
                        age_min = age_max - tmp1;
                        if (age_min < age_min_ref)
                            age_min  = age_min_ref;
                            age_max  = age_min + tmp1;
                            if (age_max > age_max_ref)
                                age_max = age_max_ref;
                            end
                            if (age_max > get(cb_max_slide, 'max'))
                                set(cb_max_slide, 'value', get(cb_max_slide, 'max'))
                            else
                                set(cb_max_slide, 'value', age_max)
                            end
                        end
                        set(cb_min_edit, 'string', sprintf('%3.0f', age_min))
                        if (age_min < get(cb_min_slide, 'min'))
                            set(cb_min_slide, 'value', get(cb_min_slide, 'min'))
                        else
                            set(cb_min_slide, 'value', age_min)
                        end
                    end
                    set(cb_max_edit, 'string', sprintf('%3.0f', age_max))
                    update_cb_range
                else
                    if (age_max > get(cb_max_slide, 'max'))
                        set(cb_max_slide, 'value', get(cb_max_slide, 'max'))
                    else
                        set(cb_max_slide, 'value', age_max)
                    end
                end
        end
        set(cb_max_slide, 'enable', 'off')
        drawnow
        set(cb_max_slide, 'enable', 'on')
    end

%% Reset minimum color scale

    function reset_cb_min(source, eventdata)
        switch cb_type
            case 'std'
                if (db_min_ref < get(cb_min_slide, 'min'))
                    set(cb_min_slide, 'value', get(cb_min_slide, 'min'))
                else
                    set(cb_min_slide, 'value', db_min_ref)
                end
                set(cb_min_edit, 'string', sprintf('%3.0f', db_min_ref))
                db_min      = db_min_ref;
            case 'age'
                if (age_min_ref < get(cb_min_slide, 'min'))
                    set(cb_min_slide, 'value', get(cb_min_slide, 'min'))
                else
                    set(cb_min_slide, 'value', age_min_ref)
                end
                set(cb_min_edit, 'string', sprintf('%3.0f', age_min_ref))
                age_min     = age_min_ref;                
        end
        update_cb_range
    end

%% Reset maximum color scale

    function reset_cb_max(source, eventdata)
        switch cb_type
            case 'std'
                if (db_max_ref > get(cb_max_slide, 'max'))
                    set(cb_max_slide, 'value', get(cb_max_slide, 'max'))
                else
                    set(cb_max_slide, 'value', db_max_ref)
                end
                set(cb_max_edit, 'string', sprintf('%3.0f', db_max_ref))
                db_max      = db_max_ref;
            case 'age'
                if (age_max_ref > get(cb_max_slide, 'max'))
                    set(cb_max_slide, 'value', get(cb_max_slide, 'max'))
                else
                    set(cb_max_slide, 'value', age_max_ref)
                end
                set(cb_max_edit, 'string', sprintf('%3.0f', age_max_ref))
                age_max     = age_max_ref;
        end
        update_cb_range
    end

%% Update color scale

    function update_cb_range(source, eventdata)
        axes(ax_radar)
        switch cb_type
            case 'std'
                caxis([db_min db_max])
            case 'age'
                colors_age  = repmat([1 0 1], pk.num_layer, 1);
                tmp1        = jet;
                for ii = 1:pk.num_layer
                    if ~isnan(age_curr(ii))
                        colors_age(ii, :) ...
                            = tmp1(interp1(linspace(age_min, age_max, 64), 1:64, (1e-3 * age_curr(ii)), 'nearest', 'extrap'), :);
                    end
                    if (logical(p_pk(ii)) && ishandle(p_pk(ii))) 
                        set(p_pk(ii), 'color', colors_age(ii, :))
                    end
                    if (logical(p_pkdepth(ii)) && ishandle(p_pkdepth(ii))) 
                        set(p_pkdepth(ii), 'color', colors_age(ii, :))
                    end
                    if (data_done && flat_done)
                        if (logical(p_pkflat(ii)) && ishandle(p_pkflat(ii)))
                            set(p_pkflat(ii), 'color', colors_age(ii, :))
                        end
                    end
                end
        end
    end

%% Update minimum distance

    function slide_dist_min(source, eventdata)
        if (get(dist_min_slide, 'value') < dist_max)
            if get(distfix_check, 'value')
                tmp1        = dist_max - dist_min;
            end
            dist_min        = get(dist_min_slide, 'value');
            if get(distfix_check, 'value')
                dist_max    = dist_min + tmp1;
                if (dist_max > dist_max_ref)
                    dist_max= dist_max_ref;
                    dist_min= dist_max - tmp1;
                    if (dist_min < dist_min_ref)
                        dist_min ...
                            = dist_min_ref;
                    end
                    if (dist_min < get(dist_min_slide, 'min'))
                        set(dist_min_slide, 'value', get(dist_min_slide, 'min'))
                    else
                        set(dist_min_slide, 'value', dist_min)
                    end
                end
                if (dist_max > get(dist_max_slide, 'max'))
                    set(dist_max_slide, 'value', get(dist_max_slide, 'max'))
                else
                    set(dist_max_slide, 'value', dist_max)
                end
                set(dist_max_slide, 'value', dist_max)
                set(dist_max_edit, 'string', sprintf('%3.1f', dist_max))
            end
            set(dist_min_edit, 'string', sprintf('%3.1f', dist_min))
            update_dist_range
        else
            if (dist_min < get(dist_min_slide, 'min'))
                set(dist_min_slide, 'value', get(dist_min_slide, 'min'))
            else
                set(dist_min_slide, 'value', dist_min)
            end
        end
        set(dist_min_slide, 'enable', 'off')
        drawnow
        set(dist_min_slide, 'enable', 'on')
    end

%% Update maximum distance

    function slide_dist_max(source, eventdata)
        if (get(dist_max_slide, 'value') > dist_min)
            if get(distfix_check, 'value')
                tmp1        = dist_max - dist_min;
            end
            dist_max        = get(dist_max_slide, 'value');
            if get(distfix_check, 'value')
                dist_min    = dist_max - tmp1;
                if (dist_min < dist_min_ref)
                    dist_min= dist_min_ref;
                    dist_max= dist_min + tmp1;
                    if (dist_max > dist_max_ref)
                        dist_max ...
                            = dist_max_ref;
                    end
                    if (dist_max > get(dist_max_slide, 'max'))
                        set(dist_max_slide, 'value', get(dist_max_slide, 'max'))
                    else
                        set(dist_max_slide, 'value', dist_max)
                    end
                end
                if (dist_min < get(dist_min_slide, 'min'))
                    set(dist_min_slide, 'value', get(dist_min_slide, 'min'))
                else
                    set(dist_min_slide, 'value', dist_min)
                end
                set(dist_min_edit, 'string', sprintf('%3.1f', dist_min))
            end
            set(dist_max_edit, 'string', sprintf('%3.1f', dist_max))
            update_dist_range
        else
            if (dist_max > get(dist_max_slide, 'max'))
                set(dist_max_slide, 'value', get(dist_max_slide, 'max'))
            else
                set(dist_max_slide, 'value', dist_max)
            end
        end
        set(dist_max_slide, 'enable', 'off')
        drawnow
        set(dist_max_slide, 'enable', 'on')
    end

%% Reset minimum distance

    function reset_dist_min(source, eventdata)
        if (dist_min_ref < get(dist_min_slide, 'min'))
            set(dist_min_slide, 'value', get(dist_min_slide, 'min'))
        else
            set(dist_min_slide, 'value', dist_min_ref)
        end
        set(dist_min_edit, 'string', sprintf('%3.1f', dist_min_ref))
        dist_min            = dist_min_ref;
        update_dist_range
    end

%% Reset maximum distance

    function reset_dist_max(source, eventdata)
        if (dist_max_ref > get(dist_max_slide, 'max'))
            set(dist_max_slide, 'value', get(dist_max_slide, 'max'))
        else
            set(dist_max_slide, 'value', dist_max_ref)
        end
        set(dist_max_edit, 'string', sprintf('%3.1f', dist_max_ref))
        dist_max            = dist_max_ref;
        update_dist_range
    end

%% Update distance range

    function update_dist_range(source, eventdata)
        axes(ax_radar)
        xlim([dist_min dist_max])
        narrow_cb
    end

%% Reset both distance (x) and elevation (y)

    function reset_xz(source, eventdata)
        reset_z_min
        reset_z_max
        reset_dist_min
        reset_dist_max
    end

%% Adjust slider limits after panning or zooming

    function panzoom(source, eventdata)
        tmp1                = get(ax_radar, 'xlim');
        if (tmp1(1) < dist_min_ref)
            reset_dist_min
        else
            if (tmp1(1) < get(dist_min_slide, 'min'))
                set(dist_min_slide, 'value', get(dist_min_slide, 'min'))
            else
                set(dist_min_slide, 'value', tmp1(1))
            end
            set(dist_min_edit, 'string', sprintf('%3.1f', tmp1(1)))
            dist_min        = tmp1(1);
        end
        if (tmp1(2) > dist_max_ref)
            reset_dist_max
        else
            if (tmp1(2) > get(dist_max_slide, 'max'))
                set(dist_max_slide, 'value', get(dist_max_slide, 'max'))
            else
                set(dist_max_slide, 'value', tmp1(2))
            end
            set(dist_max_edit, 'string', sprintf('%3.1f', tmp1(2)))
            dist_max        = tmp1(2);
        end
        tmp1                = get(ax_radar, 'ylim');
        switch disp_type
            case 'elev.'
                tmp2        = [elev_min elev_max];
                if (tmp1(1) < elev_min_ref)
                    reset_z_min
                else
                    if (tmp1(1) < get(z_min_slide, 'min'))
                        set(z_min_slide, 'value', get(z_min_slide, 'min'))
                    else
                        set(z_min_slide, 'value', tmp1(1))
                    end
                    set(z_min_edit, 'string', sprintf('%4.0f', tmp1(1)))
                    elev_min= tmp1(1);
                end
                if (tmp1(2) > elev_max_ref)
                    reset_z_max
                else
                    if (tmp1(2) > get(z_max_slide, 'max'))
                        set(z_max_slide, 'value', get(z_max_slide, 'max'))
                    else
                        set(z_max_slide, 'value', tmp1(2))
                    end
                    set(z_max_edit, 'string', sprintf('%4.0f', tmp1(2)))
                    elev_max= tmp1(2);
                end
            case {'depth' 'flat'}
                tmp2        = [depth_min depth_max];
                if (tmp1(1) < depth_min_ref)
                    reset_z_min
                else
                    if (tmp1(1) < get(z_min_slide, 'min'))
                        set(z_min_slide, 'value', get(z_min_slide, 'min'))
                    elseif (tmp1(1) > get(z_min_slide, 'max'))
                        set(z_min_slide, 'value', get(z_min_slide, 'max'))
                    else
                        set(z_min_slide, 'value', tmp1(1))
                    end
                    set(z_min_edit, 'string', sprintf('%4.0f', tmp1(1)))
                    depth_min ...
                            = tmp1(1);
                end
                if (tmp1(2) > depth_max_ref)
                    reset_z_max
                else
                    if (tmp1(2) < get(z_max_slide, 'min'))
                        set(z_max_slide, 'value', get(z_max_slide, 'min'))
                    elseif (tmp1(2) > get(z_max_slide, 'max'))
                        set(z_max_slide, 'value', get(z_max_slide, 'max'))
                    else
                        set(z_max_slide, 'value', tmp1(2))
                    end
                    set(z_max_edit, 'string', sprintf('%4.0f', tmp1(2)))
                    depth_max ...
                            = tmp1(2);
                end
        end
        narrow_cb
    end

    function zoom_in(source, eventdata)
        tmp1                = dist_max - dist_min;
        tmp2                = [(dist_min + (0.25 * tmp1)) (dist_max - (0.25 * tmp1))];
        switch disp_type
            case 'elev.'
                tmp3        = elev_max - elev_min;
                tmp4        = [(elev_min + (0.25 * tmp3)) (elev_max - (0.25 * tmp3))];
            case {'depth' 'flat'}
                tmp3        = depth_max - depth_min;
                tmp4        = [(elev_min + (0.25 * tmp3)) (elev_max - (0.25 * tmp3))];
        end
        set(ax_radar, 'xlim', tmp2, 'ylim', tmp4)
        panzoom
    end

    function zoom_out(source, eventdata)
        tmp1                = dist_max - dist_min;
        tmp2                = [(dist_min - (0.25 * tmp1)) (dist_max + (0.25 * tmp1))];
        switch disp_type
            case 'elev.'
                tmp3        = elev_max - elev_min;
                tmp4        = [(elev_min - (0.25 * tmp3)) (elev_max + (0.25 * tmp3))];
            case {'depth' 'flat'}
                tmp3        = depth_max - depth_min;
                tmp4        = [(elev_min - (0.25 * tmp3)) (elev_max + (0.25 * tmp3))];
        end
        set(ax_radar, 'xlim', tmp2, 'ylim', tmp4)
        panzoom
    end

%% Plot radargram in terms of elevation

    function plot_elev(source, eventdata)
        if (logical(p_data) && ishandle(p_data))
            delete(p_data)
        end
        if (logical(p_beddepth) && ishandle(p_beddepth))
            set(p_beddepth, 'visible', 'off')
        end
        if (logical(p_bedflat) && ishandle(p_bedflat))
            set(p_bedflat, 'visible', 'off')
        end
        if (logical(p_refflat) && ishandle(p_refflat))
            set(p_refflat, 'visible', 'off')
        end
        if (logical(p_surf) && ishandle(p_surf))
            delete(p_surf)
        end
        if (logical(p_bed) && ishandle(p_bed))
            delete(p_bed)
        end
        axes(ax_radar)
        axis xy
        set(z_min_slide, 'min', elev_min_ref, 'max', elev_max_ref, 'value', elev_min)
        set(z_max_slide, 'min', elev_min_ref, 'max', elev_max_ref, 'value', elev_max)
        set(z_min_edit, 'string', sprintf('%4.0f', elev_min))
        set(z_max_edit, 'string', sprintf('%4.0f', elev_max))
        ylim([elev_min elev_max])
        if data_done
            if gimp_avail
                p_data      = imagesc(pk.dist_lin_gimp(ind_decim), elev, amp_elev, [db_min db_max]);
            else
                p_data      = imagesc(pk.dist_lin(ind_decim), elev, amp_elev, [db_min db_max]);
            end
        end
        if (any(surf_avail) && any(~isnan(pk.elev_surf)))
            if gimp_avail
                p_surf      = plot(pk.dist_lin_gimp(ind_decim), pk.elev_surf_gimp(ind_decim), 'g--', 'linewidth', 2);
            else
                p_surf      = plot(pk.dist_lin(ind_decim), pk.elev_surf(ind_decim), 'g--', 'linewidth', 2);
            end
            if any(isnan(pk.elev_surf(ind_decim)))
                set(p_surf, 'marker', '.', 'linestyle', 'none', 'markersize', 12)
            end
        end
        if (any(bed_avail) && any(~isnan(pk.elev_bed)))
            if gimp_avail
                p_bed       = plot(pk.dist_lin_gimp(ind_decim), pk.elev_bed_gimp(ind_decim), 'g--', 'linewidth', 2);
            else
                p_bed       = plot(pk.dist_lin(ind_decim), pk.elev_bed(ind_decim), 'g--', 'linewidth', 2);
            end
            if any(isnan(depth_bed))
                set(p_bed, 'marker', '.', 'linestyle', 'none', 'markersize', 12)
            end
        end
        if any(surf_avail)
            set(yl, 'string', 'Elevation (m)')
        else
            set(yl, 'string', 'Depth (m)')
        end
        narrow_cb
        show_data
        show_core
        show_block
        show_pk
    end

%% Plot radargram in terms of depth

    function plot_depth(source, eventdata)
        if ~data_done
            set(disp_group, 'selectedobject', disp_check(1))
            disp_type       = 'elev.';
            plot_elev
            return
        end
        if (logical(p_data) && ishandle(p_data))
            delete(p_data)
        end
        if (logical(p_surf) && ishandle(p_surf))
            set(p_surf, 'visible', 'off')
        end
        if (logical(p_bed) && ishandle(p_bed))
            set(p_bed, 'visible', 'off')
        end
        if (logical(p_bedflat) && ishandle(p_bedflat))
            set(p_bedflat, 'visible', 'off')
        end
        if (logical(p_refflat) && ishandle(p_refflat))
            set(p_refflat, 'visible', 'off')
        end
        if (logical(p_beddepth) && ishandle(p_beddepth))
            delete(p_beddepth)
        end
        axes(ax_radar)
        axis ij
        set(z_min_slide, 'min', depth_min_ref, 'max', depth_max_ref, 'value', (depth_max_ref - (depth_max - depth_min_ref)))
        set(z_max_slide, 'min', depth_min_ref, 'max', depth_max_ref, 'value', (depth_max_ref - (depth_min - depth_min_ref)))
        set(z_min_edit, 'string', sprintf('%4.0f', depth_max))
        set(z_max_edit, 'string', sprintf('%4.0f', depth_min))
        ylim([depth_min depth_max])
        if gimp_avail
            p_data          = imagesc(pk.dist_lin_gimp(ind_decim), depth, amp_depth, [db_min db_max]);
        else
            p_data          = imagesc(pk.dist_lin(ind_decim), depth, amp_depth, [db_min db_max]);
        end
        if (any(bed_avail) && any(~isnan(depth_bed)))
            if gimp_avail
                p_beddepth  = plot(pk.dist_lin_gimp(ind_decim), depth_bed, 'g--', 'linewidth', 2);
            else
                p_beddepth  = plot(pk.dist_lin(ind_decim), depth_bed, 'g--', 'linewidth', 2);
            end
            if any(isnan(depth_bed))
                set(p_beddepth, 'marker', '.', 'linestyle', 'none', 'markersize', 12)
            end
        end
        set(yl, 'string', 'Depth (m)')
        narrow_cb
        show_data
        show_core
        show_block
        show_pk
    end

%% Plot layer-flattened radargram in terms of depth

    function plot_flat(source, eventdata)
        if (~flat_done && ~data_done)
            set(disp_group, 'selectedobject', disp_check(1))
            disp_type       = 'elev.';
            plot_elev
            return
        end
        if (logical(p_data) && ishandle(p_data)) % get rid of old plotted data
            delete(p_data)
        end
        if (logical(p_surf) && ishandle(p_surf))
            set(p_surf, 'visible', 'off')
        end
        if (logical(p_bed) && ishandle(p_bed))
            set(p_bed, 'visible', 'off')
        end
        if (logical(p_beddepth) && ishandle(p_beddepth))
            set(p_beddepth, 'visible', 'off')
        end
        if (logical(p_bedflat) && ishandle(p_bedflat))
            delete(p_bedflat)
        end
        if (logical(p_refflat) && ishandle(p_refflat))
            delete(p_refflat)
        end
        axes(ax_radar)
        axis ij
        set(z_min_slide, 'min', depth_min_ref, 'max', depth_max_ref, 'value', (depth_max_ref - (depth_max - depth_min_ref)))
        set(z_max_slide, 'min', depth_min_ref, 'max', depth_max_ref, 'value', (depth_max_ref - (depth_min - depth_min_ref)))
        set(z_min_edit, 'string', sprintf('%4.0f', depth_max))
        set(z_max_edit, 'string', sprintf('%4.0f', depth_min))
        ylim([depth_min depth_max])
        if gimp_avail
            tmp1            = pk.dist_lin_gimp;
        else
            tmp1            = pk.dist_lin;
        end
        p_data              = imagesc(tmp1(ind_decim), depth, amp_flat, [db_min db_max]);
        if (any(bed_avail) && any(~isnan(depth_bed_flat)) && any(depth_bed_flat))
            if any(isnan(depth_bed_flat))
                p_bedflat   = plot(tmp1(ind_decim(~isnan(depth_bed_flat))), depth_bed_flat(~isnan(depth_bed_flat)), 'g.', 'markersize', 12);
            else
                p_bedflat   = plot(tmp1(ind_decim), depth_bed_flat, 'g--', 'linewidth', 2);
            end
        end
        p_refflat           = plot(repmat(tmp1(ind_decim(ind_x_ref)), 1, 2), [depth_min_ref depth_max_ref], 'w--', 'linewidth', 2);
        disp_type           = 'flat';
        set(yl, 'string', 'Depth (m)')
        narrow_cb
        show_core
        show_block
        show_pk
    end

%% Show radar data

    function show_data(source, eventdata)
        if data_done
            if (get(data_check, 'value') && logical(p_data) && ishandle(p_data))
                set(p_data, 'visible', 'on');
            elseif (logical(p_data) && ishandle(p_data))
                set(p_data, 'visible', 'off')
            end
        elseif get(data_check, 'value')
            set(data_check, 'value', 0)
        end
    end

%% Show picked layers

    function show_pk(source, eventdata)
        if merge_done
            if get(pk_check, 'value')
                switch disp_type
                    case 'elev.'
                        if (any(p_pk) && any(ishandle(p_pk)))
                            set(p_pk(logical(p_pk) & ishandle(p_pk)), 'visible', 'on')
                            uistack(p_pk(logical(p_pk) & ishandle(p_pk)), 'top')
                        end
                        if (any(p_pkdepth) && any(ishandle(p_pkdepth)))
                            set(p_pkdepth(logical(p_pkdepth) & ishandle(p_pkdepth)), 'visible', 'off')
                        end
                        if (any(p_pkflat) && any(ishandle(p_pkflat)))
                            set(p_pkflat(logical(p_pkflat) & ishandle(p_pkflat)), 'visible', 'off')
                        end
                    case 'depth'
                        if (any(p_pkdepth) && any(ishandle(p_pkdepth)))
                            set(p_pkdepth(logical(p_pkdepth) & ishandle(p_pkdepth)), 'visible', 'on')
                            uistack(p_pkdepth(logical(p_pkdepth) & ishandle(p_pkdepth)), 'top')
                        end
                        if (any(p_pk) && any(ishandle(p_pk)))
                            set(p_pk(logical(p_pk) & ishandle(p_pk)), 'visible', 'off')
                        end
                        if (any(p_pkflat) && any(ishandle(p_pkflat)))
                            set(p_pkflat(logical(p_pkflat) & ishandle(p_pkflat)), 'visible', 'off')
                        end
                    case 'flat'
                        if (any(p_pkflat) && any(ishandle(p_pkflat)))
                            set(p_pkflat(logical(p_pkflat) & ishandle(p_pkflat)), 'visible', 'on')
                            uistack(p_pkflat(logical(p_pkflat) & ishandle(p_pkflat)), 'top')
                        end
                        if (any(p_pk) && any(ishandle(p_pk)))
                            set(p_pk(logical(p_pk) & ishandle(p_pk)), 'visible', 'off')
                        end
                        if (any(p_pkdepth) && any(ishandle(p_pkdepth)))
                            set(p_pkdepth(logical(p_pkdepth) & ishandle(p_pkdepth)), 'visible', 'off')
                        end
                end
            else
                if (any(p_pk) && any(ishandle(p_pk)))
                    set(p_pk(logical(p_pk) & ishandle(p_pk)), 'visible', 'off')
                end
                if (any(p_pkdepth) && any(ishandle(p_pkdepth)))
                    set(p_pkdepth(logical(p_pkdepth) & ishandle(p_pkdepth)), 'visible', 'off')
                end
                if (any(p_pkflat) && any(ishandle(p_pkflat)))
                    set(p_pkflat(logical(p_pkflat) & ishandle(p_pkflat)), 'visible', 'off')
                end
            end
        elseif get(pk_check, 'value')
            set(pk_check, 'value', 0)
        end
    end

%% Show block divisions

    function show_block(source, eventdata)
        if merge_done
            if get(block_check, 'value')
                switch disp_type
                    case 'elev.'
                        if (any(p_block) && any(ishandle(p_block)))
                            set(p_block(logical(p_block) & ishandle(p_block)), 'visible', 'on')
                            uistack(p_block(logical(p_block) & ishandle(p_block)), 'top')
                        end
                        if (any(p_blocknum) && any(ishandle(p_blocknum)))
                            set(p_blocknum(logical(p_blocknum) & ishandle(p_blocknum)), 'visible', 'on')
                            uistack(p_blocknum(logical(p_blocknum) & ishandle(p_blocknum)), 'top')
                        end
                        if (any(p_blockflat) && any(ishandle(p_blockflat)))
                            set(p_blockflat(logical(p_blockflat) & ishandle(p_blockflat)), 'visible', 'off')
                        end
                        if (any(p_blocknumflat) && any(ishandle(p_blocknumflat)))
                            set(p_blocknumflat(logical(p_blocknumflat) & ishandle(p_blocknumflat)), 'visible', 'off')
                        end
                    case {'depth' 'flat'}
                        if (any(p_blockflat) && any(ishandle(p_blockflat)))
                            set(p_blockflat(logical(p_blockflat) & ishandle(p_blockflat)), 'visible', 'on')
                            uistack(p_blockflat(logical(p_blockflat) & ishandle(p_blockflat)), 'top')
                        end
                        if (any(p_blocknumflat) && any(ishandle(p_blocknumflat)))
                            set(p_blocknumflat(logical(p_blocknumflat) & ishandle(p_blocknumflat)), 'visible', 'on')
                            uistack(p_blocknumflat(logical(p_blocknumflat) & ishandle(p_blocknumflat)), 'top')
                        end
                        if (any(p_block) && any(ishandle(p_block)))
                            set(p_block(logical(p_block) & ishandle(p_block)), 'visible', 'off')
                        end
                        if (any(p_blocknum) && any(ishandle(p_blocknum)))
                            set(p_blocknum(logical(p_blocknum) & ishandle(p_blocknum)), 'visible', 'off')
                        end
                end
            else
                if (any(p_block) && any(ishandle(p_block)))
                    set(p_block(logical(p_block) & ishandle(p_block)), 'visible', 'off')
                end
                if (any(p_blocknum) && any(ishandle(p_blocknum)))
                    set(p_blocknum(logical(p_blocknum) & ishandle(p_blocknum)), 'visible', 'off')
                end
                if (any(p_blockflat) && any(ishandle(p_blockflat)))
                    set(p_blockflat(logical(p_blockflat) & ishandle(p_blockflat)), 'visible', 'off')
                end
                if (any(p_blocknumflat) && any(ishandle(p_blocknumflat)))
                    set(p_blocknumflat(logical(p_blocknumflat) & ishandle(p_blocknumflat)), 'visible', 'off')
                end
            end
        elseif get(block_check, 'value')
            set(block_check, 'value', 0)
        end
    end

%% Show core intersections

    function show_core(source, eventdata)
        if core_done
            if get(core_check, 'value')
                switch disp_type
                    case 'elev.'
                        if (any(p_core) && any(ishandle(p_core)))
                            set(p_core(logical(p_core) & ishandle(p_core)), 'visible', 'on')
                            uistack(p_core(logical(p_core) & ishandle(p_core)), 'top')
                        end
                        if (any(p_corename) && any(ishandle(p_corename)))
                            set(p_corename(logical(p_corename) & ishandle(p_corename)), 'visible', 'on')
                            uistack(p_corename(logical(p_corename) & ishandle(p_corename)), 'top')
                        end
                        if (any(p_coreflat) && any(ishandle(p_coreflat)))
                            set(p_coreflat(logical(p_coreflat) & ishandle(p_coreflat)), 'visible', 'off')
                        end
                        if (any(p_corenameflat) && any(ishandle(p_corenameflat)))
                            set(p_corenameflat(logical(p_corenameflat) & ishandle(p_corenameflat)), 'visible', 'off')
                        end
                    case {'depth' 'flat'}
                        if (any(p_coreflat) && any(ishandle(p_coreflat)))
                            set(p_coreflat(logical(p_coreflat) & ishandle(p_coreflat)), 'visible', 'on')
                            uistack(p_coreflat(logical(p_coreflat) & ishandle(p_coreflat)), 'top')
                        end
                        if (any(p_corenameflat) && any(ishandle(p_corenameflat)))
                            set(p_corenameflat(logical(p_corenameflat) & ishandle(p_corenameflat)), 'visible', 'on')
                            uistack(p_corenameflat(logical(p_corenameflat) & ishandle(p_corenameflat)), 'top')
                        end
                        if (any(p_core) && any(ishandle(p_core)))
                            set(p_core(logical(p_core) & ishandle(p_core)), 'visible', 'off')
                        end
                        if (any(p_corename) && any(ishandle(p_corename)))
                            set(p_corename(logical(p_corename) & ishandle(p_corename)), 'visible', 'off')
                        end
                end
            else
                if (any(p_core) && any(ishandle(p_core)))
                    set(p_core(logical(p_core) & ishandle(p_core)), 'visible', 'off')
                end
                if (any(p_corename) && any(ishandle(p_corename)))
                    set(p_corename(logical(p_corename) & ishandle(p_corename)), 'visible', 'off')
                end
                if (any(p_coreflat) && any(ishandle(p_coreflat)))
                    set(p_coreflat(logical(p_coreflat) & ishandle(p_coreflat)), 'visible', 'off')
                end
                if (any(p_corenameflat) && any(ishandle(p_corenameflat)))
                    set(p_corenameflat(logical(p_corenameflat) & ishandle(p_corenameflat)), 'visible', 'off')
                end
            end
        elseif get(core_check, 'value')
            set(core_check, 'value', 0)
        end
    end

%% Switch to a chunk

    function plot_chunk(source, eventdata)
        curr_chunk          = get(chunk_list, 'value');
        axes(ax_radar) %#ok<*MAXES>
        if (curr_chunk <= num_chunk)
            xlim(dist_chunk([curr_chunk (curr_chunk + 1)]))
        else
            if gimp_avail
                xlim(pk.dist_lin_gimp([1 end]))
            else
                xlim(pk.dist_lin([1 end]))
            end
        end
        tmp1                = get(ax_radar, 'xlim');
        [dist_min, dist_max] = deal(tmp1(1), tmp1(2));
        set(dist_min_slide, 'value', dist_min)
        set(dist_max_slide, 'value', dist_max)
        set(dist_min_edit, 'string', sprintf('%3.1f', dist_min))
        set(dist_max_edit, 'string', sprintf('%3.1f', dist_max))
    end

%% Adjust number of indices to display

    function adj_decim(source, eventdata)
        decim               = abs(round(str2double(get(decim_edit, 'string'))));
        if merge_done
            if (decim > 1)
                ind_decim   = (1 + ceil(decim / 2)):decim:(pk.num_trace_tot - ceil(decim / 2));
            else
                ind_decim   = 1:pk.num_trace_tot;
            end
            num_decim       = length(ind_decim);
            if (any(p_pk) && any(ishandle(p_pk)))
                delete(p_pk(logical(p_pk) & ishandle(p_pk)))
            end
            layer_str       = num2cell(1:pk.num_layer);
            for ii = 1:pk.num_layer
                if all(isnan(pk.elev_smooth(ii, ind_decim)))
                    p_pk(ii)=plot(0, 0, 'w.', 'markersize', 1);
                    p_pkdepth(ii) ...
                            = plot(0, 0, 'w.', 'markersize', 1);                    
                    layer_str{ii} ...
                            = [num2str(layer_str{ii}) ' H'];
                else
                    if gimp_avail
                        p_pk(ii)= plot(pk.dist_lin_gimp(ind_decim(~isnan(pk.elev_smooth_gimp(ii, ind_decim)))), pk.elev_smooth_gimp(ii, ind_decim(~isnan(pk.elev_smooth_gimp(ii, ind_decim)))), '.', 'color', colors(ii, :), 'markersize', 12, 'visible', 'off');
                        p_pkdepth(ii) = plot(pk.dist_lin_gimp(ind_decim(~isnan(pk.depth_smooth(ii, ind_decim)))), pk.depth_smooth(ii, ind_decim(~isnan(pk.depth_smooth(ii, ind_decim)))), '.', 'color', colors(ii, :), 'markersize', 12, 'visible', 'off');
                    else
                        p_pk(ii) = plot(pk.dist_lin(ind_decim(~isnan(pk.elev_smooth(ii, ind_decim)))), pk.elev_smooth(ii, ind_decim(~isnan(pk.elev_smooth(ii, ind_decim)))), '.', 'color', colors(ii, :), 'markersize', 12, 'visible', 'off');
                        p_pkdepth(ii) = plot(pk.dist_lin(ind_decim(~isnan(pk.depth_smooth(ii, ind_decim)))), pk.depth_smooth(ii, ind_decim(~isnan(pk.depth_smooth(ii, ind_decim)))), '.', 'color', colors(ii, :), 'markersize', 12, 'visible', 'off');
                    end
                end
            end
            if curr_layer
                set(layer_list, 'string', layer_str, 'value', curr_layer)
            else
                set(layer_list, 'string', layer_str, 'value', 1)
            end
            show_pk
        end
        if data_done
            load_data_breakout
        elseif flat_done
            if (num_decim ~= size(pk.poly_flat_merge, 2))
                pk.poly_flat_merge ...
                            = interp2(pk.poly_flat_merge, linspace(1, num_decim, num_decim), (1:size(pk.poly_flat_merge, 1))');
            end
        end
        set(decim_edit, 'string', num2str(decim))
        set(status_box, 'string', ['Displayed data decimated to 1/' num2str(decim) ' samples.'])
    end

%% Adjust length of each chunk

    function adj_length_chunk(source, eventdata)
        length_chunk        = abs(round(str2double(get(length_chunk_edit, 'string'))));
        if gimp_avail
            tmp1            = pk.dist_lin_gimp;
        else
            tmp1            = pk.dist_lin;
        end
        num_chunk           = floor((tmp1(end) - tmp1(1)) ./ length_chunk);
        dist_chunk          = tmp1(1):length_chunk:tmp1(end);
        if (dist_chunk(end) ~= tmp1(end))
            dist_chunk(end) = tmp1(end);
        end
        set(chunk_list, 'string', [num2cell(1:num_chunk) 'full'], 'value', (num_chunk + 1))
        set(status_box, 'string', ['Display chunk length adjusted to ' num2str(length_chunk) ' km.'])
        set(length_chunk_edit, 'string', num2str(length_chunk))
    end

%% Change colormap

    function change_cmap(source, eventdata)
        axes(ax_radar)
        colormap(cmaps{get(cmap_list, 'value')})
    end

%% Switch display type

    function disp_radio(~, eventdata)
        disp_type           = get(eventdata.NewValue, 'string');
        switch disp_type
            case 'elev.'
                plot_elev
            case 'depth'
                plot_depth
            case 'flat'
                plot_flat
        end
    end

%% Switch layer color type

    function cb_radio(~, eventdata)
        cb_type             = get(eventdata.NewValue, 'string');
        switch cb_type
            case 'std'
                set(cbl, 'string', '(dB)')
                set(cbl_min, 'string', 'dB_{min}')
                set(cbl_max, 'string', 'dB_{max}')
                set(cb_min_edit, 'string', sprintf('%3.0f', db_min))
                set(cb_max_edit, 'string', sprintf('%3.0f', db_max))
                set(cb_min_slide, 'min', db_min_ref, 'max', db_max_ref, 'value', db_min)
                set(cb_max_slide, 'min', db_min_ref, 'max', db_max_ref, 'value', db_max)
                for ii = 1:pk.num_layer
                    if (logical(p_pk(ii)) && ishandle(p_pk(ii)))
                        set(p_pk(ii), 'color', colors(ii, :))
                    end
                    if (data_done && flat_done)
                        if (logical(p_pkflat(ii)) && ishandle(p_pkflat(ii)))
                            set(p_pkflat(ii), 'color', colors(ii, :))
                        end
                    end
                end
            case 'age'
                if age_done
                    set(cbl, 'string', '(ka)')
                    set(cbl_min, 'string', 'age_{min}')
                    set(cbl_max, 'string', 'age_{max}')
                    set(cb_min_edit, 'string', sprintf('%3.0f', age_min))
                    set(cb_max_edit, 'string', sprintf('%3.0f', age_max))
                    set(cb_min_slide, 'min', age_min_ref, 'max', age_max_ref, 'value', age_min)
                    set(cb_max_slide, 'min', age_min_ref, 'max', age_max_ref, 'value', age_max)
                    update_cb_range
                else
                    cb_type = 'dB';
                    set(cb_group, 'selectedobject', cb_check(1))
                end
        end
    end

%% Toggle gridlines

    function toggle_grid(source, eventdata)
        if get(grid_check, 'value')
            axes(ax_radar)
            grid on
        else
            grid off
        end
    end

%% Narrow color axis to +/- 2 standard deviations of current mean value

    function narrow_cb(source, eventdata)
        if ~(get(cbfix_check2, 'value') && data_done && strcmp(cb_type, 'std'))
            return
        end
        axes(ax_radar)
        tmp1                = zeros(2);
        if gimp_avail
            tmp1(1, :)      = interp1(pk.dist_lin_gimp(ind_decim), 1:num_decim, [dist_min dist_max], 'nearest', 'extrap');
        else
            tmp1(1, :)      = interp1(pk.dist_lin(ind_decim), 1:num_decim, [dist_min dist_max], 'nearest', 'extrap');
        end
        switch disp_type
            case 'elev.'
                tmp1(2, :)  = interp1(elev, 1:num_sample, [elev_min elev_max], 'nearest', 'extrap');
                tmp1(2, :)  = flipud(tmp1(2, :));
                tmp1        = amp_elev(tmp1(2, 1):tmp1(2, 2), tmp1(1, 1):tmp1(1, 2));
            case 'depth'
                tmp1(2, :)  = interp1(depth, 1:num_sample, [depth_min depth_max], 'nearest', 'extrap');
                tmp1        = amp_depth(tmp1(2, 1):tmp1(2, 2), tmp1(1, 1):tmp1(1, 2));
            case 'flat'
                tmp1(2, :)  = interp1(depth, 1:num_sample, [depth_min depth_max], 'nearest', 'extrap');
                tmp1        = amp_flat(tmp1(2, 1):tmp1(2, 2), tmp1(1, 1):tmp1(1, 2));
        end
        tmp2                = NaN(1, 2);
        [tmp2(1), tmp2(2)]  = deal(nanmean(tmp1(~isinf(tmp1))), nanstd(tmp1(~isinf(tmp1))));
        if any(isnan(tmp2))
            return
        end
        tmp1                = zeros(1, 2);
        if ((tmp2(1) - (2 * tmp2(2))) < db_min_ref)
            tmp1(1)         = db_min_ref;
        else
            tmp1(1)         = tmp2(1) - (2 * tmp2(2));
        end
        if ((tmp2(1) + (2 * tmp2(2))) > db_max_ref)
            tmp1(2)         = db_max_ref;
        else
            tmp1(2)         = tmp2(1) + (2 * tmp2(2));
        end
        [db_min, db_max]    = deal(tmp1(1), tmp1(2));
        if (db_min < get(cb_min_slide, 'min'))
            set(cb_min_slide, 'value', get(cb_min_slide, 'min'))
        else
            set(cb_min_slide, 'value', db_min)
        end
        if (db_max > get(cb_max_slide, 'max'))
            set(cb_max_slide, 'value', get(cb_max_slide, 'max'))
        else
            set(cb_max_slide, 'value', db_max)
        end
        set(cb_min_edit, 'string', sprintf('%3.0f', db_min))
        set(cb_max_edit, 'string', sprintf('%3.0f', db_max))
        caxis([db_min db_max])
    end

%% Pop out map

    function pop_map(source, eventdata)
        if ~merge_done
            set(status_box, 'string', 'Cannot make map until picks are loaded.')
            return
        end
        if (~license('checkout', 'map_toolbox') || ~exist('num_coast', 'var') || ~gimp_avail)
            set(status_box, 'string', 'Cannot make map without Mapping Toolbox and gimp_90m.mat.')
            return
        end
        set(0, 'DefaultFigureWindowStyle', 'default')
        figure('position', [100 100 600 800]);
        hold on
        for ii = 1:num_coast
            plot(x_coast_gimp{ii}, y_coast_gimp{ii}, 'k', 'linewidth', 1) %#ok<USENS>
        end
        plot(pk.x_gimp, pk.y_gimp, 'k.', 'markersize', 10)
        plot(pk.x_gimp(1), pk.y_gimp(1), 'ko', 'markersize', 12, 'markerfacecolor', 'g')
        plot(pk.x_gimp(end), pk.y_gimp(end), 'ko', 'markersize', 12, 'markerfacecolor', 'r')
        tmp1            = (100 * ceil(pk.dist_lin_gimp(1) / 100)):100:(100 * floor(pk.dist_lin_gimp(end) / 100));
        plot(pk.x_gimp(interp1(pk.dist_lin_gimp, 1:pk.num_trace_tot, tmp1, 'nearest')), pk.y_gimp(interp1(pk.dist_lin_gimp, 1:pk.num_trace_tot, tmp1, 'nearest')), 'ko', 'markersize', 6, 'markerfacecolor', 'b')
        set(gca, 'fontsize', 20)
        xlabel('Polar stereographic X (km)')
        ylabel('Polar stereographic Y (km)')
        axis equal tight
        grid on
        box on
        set(0, 'DefaultFigureWindowStyle', 'docked')
    end

%% Pop out figure

    function pop_fig(source, eventdata)
        if (~merge_done && ~data_done)
            set(status_box, 'string', 'Picks or data must be loaded prior to popping out a figure.')
            return
        end
        set(0, 'DefaultFigureWindowStyle', 'default')
        figure('position', [200 200 1600 800])
        axis tight
        hold on
        colormap(cmaps{get(cmap_list, 'value')})
        caxis([db_min db_max])
        switch disp_type
            case 'elev.'
                axis xy
                axis([dist_min dist_max elev_min elev_max])
                tmp1        = amp_elev;
                tmp1(isnan(tmp1)) ...
                            = db_max;
                if gimp_avail
                    imagesc(pk.dist_lin_gimp(ind_decim), elev, tmp1, [db_min db_max])
                else
                    imagesc(pk.dist_lin(ind_decim), elev, tmp1, [db_min db_max])
                end
                if (any(surf_avail) && any(~isnan(pk.elev_surf)))
                    if gimp_avail
                        tmp1 = plot(pk.dist_lin_gimp(ind_decim), pk.elev_surf_gimp(ind_decim), 'g--', 'linewidth', 2);
                    else
                        tmp1 = plot(pk.dist_lin(ind_decim), pk.elev_surf(ind_decim), 'g--', 'linewidth', 2);
                    end
                    if any(isnan(pk.elev_surf(ind_decim)))
                        set(tmp1, 'marker', '.', 'linestyle', 'none', 'markersize', 12)
                    end
                end
                if (any(bed_avail) && any(~isnan(pk.elev_bed)))
                    if gimp_avail
                        tmp1 = plot(pk.dist_lin_gimp(ind_decim), pk.elev_bed_gimp(ind_decim), 'g--', 'linewidth', 2);
                    else
                        tmp1 = plot(pk.dist_lin(ind_decim), pk.elev_bed(ind_decim), 'g--', 'linewidth', 2);
                    end
                    if any(isnan(depth_bed))
                        set(tmp1, 'marker', '.', 'linestyle', 'none', 'markersize', 12)
                    end
                end
                if get(pk_check, 'value')
                    for ii = 1:pk.num_layer
                        if any(~isnan(pk.elev_smooth(ii, ind_decim)))
                            if gimp_avail
                                tmp1 = plot(pk.dist_lin_gimp(ind_decim(~isnan(pk.elev_smooth_gimp(ii, ind_decim)))), pk.elev_smooth_gimp(ii, ind_decim(~isnan(pk.elev_smooth_gimp(ii, ind_decim)))), '.', 'color', colors(ii, :), 'markersize', 12);
                            else
                                tmp1 = plot(pk.dist_lin(ind_decim(~isnan(pk.elev_smooth(ii, ind_decim)))), pk.elev_smooth(ii, ind_decim(~isnan(pk.elev_smooth(ii, ind_decim)))), '.', 'color', colors(ii, :), 'markersize', 12);
                            end
                            if any(ii == curr_layer)
                                set(tmp1, 'markersize', 24)
                            end
                        end
                    end
                end                
                if get(block_check, 'value')
                    for ii = 1:length(pk.ind_trace_start)
                        if gimp_avail
                            tmp1 = pk.dist_lin_gimp;
                        else
                            tmp1 = pk.dist_lin;
                        end
                        plot(repmat(tmp1(pk.ind_trace_start(ii)), 1, 2), [elev_min elev_max], 'm--', 'linewidth', 1)
                        if ~isempty(pk.file_block{ii})
                            text((tmp1(pk.ind_trace_start(ii)) + 1), (elev_max - (0.1 * (elev_max - elev_min))), pk.file_block{ii}((end - 1):end), 'color', 'm', 'fontsize', (size_font - 2))
                        end
                    end
                end
                if get(core_check, 'value')
                    for ii = 1:num_int
                        if gimp_avail
                            tmp1 = double(pk.dist_lin_gimp);
                        else
                            tmp1 = pk.dist_lin;
                        end
                        tmp2 = find(~isnan(ind_int));
                        plot(repmat(tmp1(ind_int(tmp2(ii))), 1, 2), [elev_min elev_max], 'm', 'linewidth', 2)
                        text(double(tmp1(ind_int(tmp2(ii))) + 1), double(elev_max - (0.2 * (elev_max - elev_min))), name_core{int_core{curr_year}{curr_trans}(tmp2(ii), 3)}, 'color', 'm', 'fontsize', size_font)
                    end
                end
                ylabel('Elevation (m)', 'fontsize', 20)
                text(double(dist_max + (0.015 * (dist_max - dist_min))), double(elev_max + (0.04 * (elev_max - elev_min))), '(dB)', 'color', 'k', 'fontsize', 20)
            case {'depth' 'flat'}
                axis ij
                axis([dist_min dist_max depth_min depth_max])
                if gimp_avail
                    tmp1 = pk.dist_lin_gimp;
                else
                    tmp1 = pk.dist_lin;
                end
                if strcmp(disp_type, 'depth')
                    tmp2 = amp_depth;
                else
                    tmp2 = amp_flat;
                end
                tmp2(isnan(tmp2)) ...
                         = db_max;
                imagesc(tmp1(ind_decim), depth, tmp2, [db_min db_max])
                if (any(bed_avail) && any(~isnan(pk.elev_bed)))
                    if any(isnan(depth_bed_flat))
                        plot(tmp1(ind_decim(~isnan(depth_bed_flat))), depth_bed_flat(~isnan(depth_bed_flat)), 'g.', 'markersize', 12)
                    else
                        plot(tmp1(ind_decim), depth_bed_flat, 'g--', 'linewidth', 2)
                    end
                end
                if get(pk_check, 'value')
                    for ii = 1:pk.num_layer
                        if ~isempty(find(~isnan(depth_layer_flat(ii, :)), 1))
                            tmp2 = plot(tmp1(ind_decim(~isnan(depth_layer_flat(ii, :)))), depth_layer_flat(ii, ~isnan(depth_layer_flat(ii, :))), '.', 'markersize', 12, 'color', colors(ii, :));
                            if isnan(depth_layer_ref(ii))
                                set(tmp2, 'markersize', 6)
                            end
                        end
                    end
                end
                if get(block_check, 'value')
                    for ii = 1:length(pk.ind_trace_start)
                        plot(repmat(tmp1(pk.ind_trace_start(ii)), 1, 2), [depth_min depth_max], 'm--', 'linewidth', 1)
                        if ~isempty(pk.file_block{ii})
                            text((tmp1(pk.ind_trace_start(ii)) + 1), (depth_min + (0.1 * (depth_max - depth_min))), pk.file_block{ii}((end - 1):end), 'color', 'm', 'fontsize', (size_font - 2))
                        end
                    end
                end
                if get(core_check, 'value')
                    tmp2 = find(~isnan(ind_int));
                    for ii = 1:num_int
                        plot(repmat(tmp1(ind_int(tmp2(ii))), 1, 2), [depth_min depth_max], 'm', 'linewidth', 2)
                        text(double(tmp1(ind_int(tmp2(ii))) + 1), double(depth_min + (0.2 * (depth_max - depth_min))), name_core{int_core{curr_year}{curr_trans}(tmp2(ii), 3)}, 'color', 'm', 'fontsize', size_font)
                    end
                end
                plot(repmat(tmp1(ind_decim(ind_x_ref)), 1, 2), [depth_min depth_max], 'w--', 'linewidth', 2)
                ylabel('Depth (m)', 'fontsize', 20)
                text(double(dist_max + (0.015 * (dist_max - dist_min))), double(depth_min - (0.04 * (depth_max - depth_min))), '(dB)', 'color', 'k', 'fontsize', 20)
        end
        set(gca, 'fontsize', 20, 'layer', 'top')
        xlabel('Distance (km)')
        title(file_pk_short, 'fontweight', 'bold', 'interpreter', 'none')
        colorbar('fontsize', 20)
        if get(grid_check, 'value')
            grid on
        end
        box on
        set(0, 'DefaultFigureWindowStyle', 'docked')
    end

%% Keyboard shortcuts for various functions

    function keypress(~, eventdata)

        switch eventdata.Key
            case '1'
                if get(pk_check, 'value')
                    set(pk_check, 'value', 0)
                else
                    set(pk_check, 'value', 1)
                end
                show_pk
            case '2'
                if get(data_check, 'value')
                    set(data_check, 'value', 0)
                else
                    set(data_check, 'value', 1)
                end
                show_data
            case '3'
                if get(block_check, 'value')
                    set(block_check, 'value', 0)
                else
                    set(block_check, 'value', 1)
                end
                show_block
            case '4'
                if get(core_check, 'value')
                    set(core_check, 'value', 0)
                else
                    set(core_check, 'value', 1)
                end
                show_core
            case '5'
                switch cb_type
                    case 'std'
                        if age_done
                            set(cb_group, 'selectedobject', cb_check(2))
                            cb_radio
                        end
                    case 'age'
                        set(cb_group, 'selectedobject', cb_check(1))
                        cb_radio
                end
            case 'a'
                pop_map
            case 'b'
                if get(cbfix_check2, 'value')
                    set(cbfix_check2, 'value', 0)
                else
                    set(cbfix_check2, 'value', 1)
                end
                narrow_cb
            case 'c'
                if ~core_done
                    load_core
                else
                    set(status_box, 'string', 'Core intersection data already loaded.')
                end
            case 'd'
                pk_del
            case 'e'
                reset_xz
            case 'f'
                flatten
            case 'g'
                if get(grid_check, 'value')
                    set(grid_check, 'value', 0)
                else
                    set(grid_check, 'value', 1)
                end
                toggle_grid
            case 'k'
                pk_split
            case 'l'
                load_data
            case 'm'
                pk_merge
            case 'n'
                pk_next
            case 'o'
                pk_focus
            case 'p'
                load_pk
            case 'q'
                pop_fig
            case 's'
                pk_last
            case 'v'
                pk_save
            case 'w'
                if (get(cmap_list, 'value') == 1)
                    set(cmap_list, 'value', 2)
                else
                    set(cmap_list, 'value', 1)
                end
                change_cmap
            case 'x'
                if get(distfix_check, 'value')
                    set(distfix_check, 'value', 0)
                else
                    set(distfix_check, 'value', 1)
                end
            case 'y'
                if get(zfix_check, 'value')
                    set(zfix_check, 'value', 0)
                else
                    set(zfix_check, 'value', 1)
                end
            case 'z'
                pk_select_gui
            case 'slash'
                switch ord_poly
                    case 2
                        ord_poly ...
                            = 3;
                        set(status_box, 'string', 'Flattening polynomial switched to 3rd order')
                    case 3
                        ord_poly ...
                            = 2;
                        set(status_box, 'string', 'Flattening polynomial switched to 2nd order.')
                end
            case 'downarrow'
                switch disp_type
                    case 'elev.'
                        tmp1        = elev_max - elev_min;
                        tmp2        = elev_min - (0.25 * tmp1);
                        if flat_done
                            tmp3    = [elev_min elev_max];
                        end
                        if (tmp2 < elev_min_ref)
                            elev_min= elev_min_ref;
                        else
                            elev_min= tmp2;
                        end
                        elev_max    = elev_min + tmp1;
                        if (elev_max > elev_max_ref)
                            elev_max= elev_max_ref;
                        end
                        set(z_min_edit, 'string', sprintf('%4.0f', elev_min))
                        set(z_max_edit, 'string', sprintf('%4.0f', elev_max))
                        if (elev_min < get(z_min_slide, 'min'))
                            set(z_min_slide, 'value', get(z_min_slide, 'min'))
                        else
                            set(z_min_slide, 'value', elev_min)
                        end
                        if (elev_max > get(z_max_slide, 'max'))
                            set(z_max_slide, 'value', get(z_max_slide, 'max'))
                        else
                            set(z_max_slide, 'value', elev_max)
                        end
                    case {'depth' 'flat'}
                        tmp1        = depth_max - depth_min;
                        tmp2        = depth_max + (0.25 * tmp1);
                        if (tmp2 > depth_max_ref)
                            depth_max= depth_max_ref;
                        else
                            depth_max= tmp2;
                        end
                        depth_min    = depth_max - tmp1;
                        if (depth_min < depth_min_ref)
                            depth_min=depth_min_ref;
                        end
                        set(z_min_edit, 'string', sprintf('%4.0f', depth_max))
                        set(z_max_edit, 'string', sprintf('%4.0f', depth_min))
                        if ((depth_max_ref - (depth_max - depth_min_ref)) < get(z_min_slide, 'min'))
                            set(z_min_slide, 'value', get(z_min_slide, 'min'))
                        elseif ((depth_max_ref - (depth_max - depth_min_ref)) > get(z_min_slide, 'max'))
                            set(z_min_slide, 'value', get(z_min_slide, 'max'))
                        else
                            set(z_min_slide, 'value', (depth_max_ref - (depth_max - depth_min_ref)))
                        end
                        if ((depth_max_ref - (depth_min - depth_min_ref)) < get(z_max_slide, 'min'))
                            set(z_max_slide, 'value', get(z_max_slide, 'min'))
                        elseif ((depth_max_ref - (depth_min - depth_min_ref)) > get(z_max_slide, 'max'))
                            set(z_max_slide, 'value', get(z_max_slide, 'max'))
                        else
                            set(z_max_slide, 'value', (depth_max_ref - (depth_min - depth_min_ref)))
                        end
                end
                update_z_range
            case 'leftarrow'
                tmp1        = dist_max - dist_min;
                tmp2        = dist_min - (0.25 * tmp1);
                if (tmp2 < dist_min_ref)
                    dist_min= dist_min_ref;
                else
                    dist_min= tmp2;
                end
                dist_max    = dist_min + tmp1;
                if (dist_max > dist_max_ref)
                    dist_max= dist_max_ref;
                end
                set(dist_min_edit, 'string', sprintf('%3.1f', dist_min))
                set(dist_max_edit, 'string', sprintf('%3.1f', dist_max))
                if (dist_min < get(dist_min_slide, 'min'))
                    set(dist_min_slide, 'value', get(dist_min_slide, 'min'))
                else
                    set(dist_min_slide, 'value', dist_min)
                end
                if (dist_max > get(dist_max_slide, 'max'))
                    set(dist_max_slide, 'value', get(dist_max_slide, 'max'))
                else
                    set(dist_max_slide, 'value', dist_max)
                end
                update_dist_range
            case 'rightarrow'
                tmp1        = dist_max - dist_min;
                tmp2        = dist_max + (0.25 * tmp1);
                if (tmp2 > dist_max_ref);
                    dist_max= dist_max_ref;
                else
                    dist_max= tmp2;
                end
                dist_min    = dist_max - tmp1;
                if (dist_min < dist_min_ref)
                    dist_min= dist_min_ref;
                end
                set(dist_min_edit, 'string', sprintf('%3.1f', dist_min))
                set(dist_max_edit, 'string', sprintf('%3.1f', dist_max))
                if (dist_min < get(dist_min_slide, 'min'))
                    set(dist_min_slide, 'value', get(dist_min_slide, 'min'))
                else
                    set(dist_min_slide, 'value', dist_min)
                end
                if (dist_max > get(dist_max_slide, 'max'))
                    set(dist_max_slide, 'value', get(dist_max_slide, 'max'))
                else
                    set(dist_max_slide, 'value', dist_max)
                end
                update_dist_range
            case 'uparrow'
                switch disp_type
                    case 'elev.'
                        tmp1        = elev_max - elev_min;
                        tmp2        = elev_max + (0.25 * tmp1);
                        if (tmp2 > elev_max_ref)
                            elev_max= elev_max_ref;
                        else
                            elev_max= tmp2;
                        end
                        elev_min    = elev_max - tmp1;
                        if (elev_min < elev_min_ref)
                            elev_min= elev_min_ref;
                        end
                        set(z_min_edit, 'string', sprintf('%4.0f', elev_min))
                        set(z_max_edit, 'string', sprintf('%4.0f', elev_max))
                        if (elev_min < get(z_min_slide, 'min'))
                            set(z_min_slide, 'value', get(z_min_slide, 'min'))
                        else
                            set(z_min_slide, 'value', elev_min)
                        end
                        if (elev_max > get(z_max_slide, 'max'))
                            set(z_max_slide, 'value', get(z_max_slide, 'max'))
                        else
                            set(z_max_slide, 'value', elev_max)
                        end
                    case {'depth' 'flat'}
                        tmp1        = depth_max - depth_min;
                        tmp2        = depth_min - (0.25 * tmp1);
                        if (tmp2 < depth_min_ref)
                            depth_min= depth_min_ref;
                        else
                            depth_min= tmp2;
                        end
                        depth_max   = depth_min + tmp1;
                        depth_min   = depth_max - tmp1;
                        set(z_min_edit, 'string', sprintf('%4.0f', depth_max))
                        set(z_max_edit, 'string', sprintf('%4.0f', depth_min))
                        if ((depth_max_ref - (depth_max - depth_min_ref)) < get(z_min_slide, 'min'))
                            set(z_min_slide, 'value', get(z_min_slide, 'min'))
                        elseif ((depth_max_ref - (depth_max - depth_min_ref)) > get(z_min_slide, 'max'))
                            set(z_min_slide, 'value', get(z_min_slide, 'max'))
                        else
                            set(z_min_slide, 'value', (depth_max_ref - (depth_max - depth_min_ref)))
                        end
                        if ((depth_max_ref - (depth_min - depth_min_ref)) < get(z_max_slide, 'min'))
                            set(z_max_slide, 'value', get(z_max_slide, 'min'))
                        elseif ((depth_max_ref - (depth_min - depth_min_ref)) > get(z_max_slide, 'max'))
                            set(z_max_slide, 'value', get(z_max_slide, 'max'))
                        else
                            set(z_max_slide, 'value', (depth_max_ref - (depth_min - depth_min_ref)))
                        end
                end
                update_z_range
            case 'space'
                switch disp_type
                    case 'elev.'
                        if flat_done
                            set(disp_group, 'selectedobject', disp_check(3))
                            disp_type = 'flat';
                            plot_flat
                        else
                            set(disp_group, 'selectedobject', disp_check(2))
                            disp_type = 'depth';
                            plot_depth
                        end
                    case 'depth'
                        if flat_done
                            set(disp_group, 'selectedobject', disp_check(3))
                            disp_type = 'flat';
                            plot_flat
                        else
                            set(disp_group, 'selectedobject', disp_check(1))
                            disp_type = 'elev.';
                            plot_elev
                        end
                    case 'flat'
                        set(disp_group, 'selectedobject', disp_check(1))
                        disp_type = 'elev.';
                        plot_elev
                end
        end
    end

%% Mouse wheel shortcut

    function wheel_zoom(~, eventdata)
        switch eventdata.VerticalScrollCount
            case -1
                zoom_in
            case 1
                zoom_out
        end
    end

%% Mouse click

    function mouse_click(source, eventdata)
        if ~merge_done
            return
        end
        tmp1                = get(source, 'currentpoint');
        tmp2                = get(mgui, 'position');
        tmp3                = get(ax_radar, 'position');
        tmp4                = [(tmp2(1) + (tmp2(3) * tmp3(1))) (tmp2(1) + (tmp2(3) * (tmp3(1) + tmp3(3)))); (tmp2(2) + (tmp2(4) * tmp3(2))) (tmp2(2) + (tmp2(4) * (tmp3(2) + tmp3(4))))];
        if ((tmp1(1) > (tmp4(1, 1))) && (tmp1(1) < (tmp4(1, 2))) && (tmp1(2) > (tmp4(2, 1))) && (tmp1(2) < (tmp4(2, 2))))
            switch disp_type
                case 'elev.'
                    tmp1    = [((tmp1(1) - tmp4(1, 1)) / diff(tmp4(1, :))) ((tmp1(2) - tmp4(2, 1)) / diff(tmp4(2, :)))];
                case {'depth' 'flat'}
                    tmp1    = [((tmp1(1) - tmp4(1, 1)) / diff(tmp4(1, :))) ((tmp4(2, 2) - tmp1(2)) / diff(tmp4(2, :)))];
            end
            tmp2            = [get(ax_radar, 'xlim'); get(ax_radar, 'ylim')];
            [ind_x_pk, ind_y_pk] ...
                            = deal(((tmp1(1) * diff(tmp2(1, :))) + tmp2(1, 1)), ((tmp1(2) * diff(tmp2(2, :))) + tmp2(2, 1)));
            pk_select_gui_breakout
        end
    end

%% Test something

    function misctest(source, eventdata)
                p_pkflat(pk.num_layer) ...
                            = plot(0, 0, '.', 'markersize', 12, 'color', colors(ii, :), 'visible', 'off');

    end

%%
end