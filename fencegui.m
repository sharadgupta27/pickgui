function fencegui
% FENCEGUI Interactive comparison of layer picks between intersecting radar transects.
%   
%   FENCEGUI loads a pair of GUIs (3D and 2D) for interactive comparison of
%   a master transect's radar layers with those from transects that
%   intersect it. These layers must have been traced previously across
%   individual blocks using PICKGUI and then merged using MERGEGUI. Refer
%   to manual for operation (pickgui_man.pdf).
%   
%   FENCEGUI requires that the functions INTERSECTI and TOPOCORR be
%   available within the user's path.
% 
% Joe MacGregor (UTIG)
% Last updated: 11/03/15

if ~exist('intersecti', 'file')
    error('fencegui:intersecti', 'Necessary function INTERSECTI is not available within this user''s path.')
end
if ~exist('topocorr', 'file')
    error('fencegui:topocorr', 'Necessary function TOPOCORR is not available within this user''s path.')
end

%% Intialize variables


% elevation/depth defaults
[elev_min_ref, elev_max_ref]= deal(0, 1);
elev_min                    = zeros(1, 2);
elev_max                    = ones(1, 2);
[depth_min_ref, depth_max_ref] ...
                            = deal(0, 1);
[depth_min, depth_max]      = deal(0, 1);

% x/y defaults
[x_min_ref, x_max_ref]      = deal(0, 1);
[y_min_ref, y_max_ref]      = deal(0, 1);
[dist_min_ref, dist_max_ref]= deal(zeros(1, 2), ones(1, 2));
[x_min, x_max]              = deal(x_min_ref, x_max_ref);
[y_min, y_max]              = deal(y_min_ref, y_max_ref);
[dist_min, dist_max]        = deal(dist_min_ref, dist_max_ref);

% dB default
[db_min_ref, db_max_ref]    = deal(repmat(-130, 1, 3), zeros(1, 3));
[db_min, db_max]            = deal(repmat(-80, 1, 3), repmat(-20, 1, 3));

disp_type                   = 'elev.';
aspect_ratio                = 10;

% some default values
speed_vacuum                = 299792458; % m/s
permitt_ice                 = 3.15;
speed_ice                   = speed_vacuum / sqrt(permitt_ice);
decim                       = [10 10]; % decimate radargram for display
cmaps                       = {'bone' 'jet'}';
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

% allocate a bunch of variables
p_beddepth                  = NaN(1, 2);
[core_done, int_done, match_done] ...
                            = deal(false);
[bed_avail, data_done, pk_done, surf_avail] ...
                            = deal(false(1, 2));
[amp_depth, amp_elev, colors, depth, dist_lin, elev, elev_bed, elev_smooth, elev_surf, file_data, file_pk, file_pk_short, ind_corr, ind_decim, ind_int_core, ind_layer, layer_str, p_coredepth, p_corenamedepth, p_pkdepth, path_data, path_pk, pk, twtt, x, y] ...
                            = deal(cell(1, 2));
p_int1                      = cell(2, 3);
[p_core, p_corename, p_int2, p_pk] ...
                            = deal(cell(2));
[curr_layer, curr_trans, curr_subtrans, curr_year, disp_check, dt, num_data, num_decim, num_int_core, num_sample] ...
                            = deal(zeros(1, 2));
[decim_edit, layer_list, p_bed, p_data, pk_check, p_surf] ...
                            = deal(NaN(2));
[curr_az2, curr_el2, curr_ind_int, ind_layer_match, ii, ind_x_pk, ind_y_pk, int_all, int_core, int_year, jj, kk, name_core, name_trans, name_year, num_int, num_trans, num_year, rad_threshold, tmp1, tmp2, tmp3, tmp4, tmp5, x_core, y_core] ...
                            = deal(0);
[curr_ax, curr_gui, curr_int, curr_rad] ...
                            = deal(1);
curr_rad_alt                = 2;
curr_dim                    = '3D';
[file_core, file_match, file_ref, path_core, path_match, path_ref, radar_type] ...
                            = deal('');
letters                     = 'a':'z';

%% draw first GUI

set(0, 'DefaultFigureWindowStyle', 'docked')
fgui(1)                     = figure('toolbar', 'figure', 'name', 'FENCEGUI 3D', 'menubar', 'none', 'keypressfcn', @keypress1);
ax(1)                       = subplot('position', [0.08 0.10 0.84 0.81]);
if ispc % windows switch
    size_font               = 14;
    width_slide             = 0.01;
else
    size_font               = 18;
    width_slide             = 0.02;
end

hold on
colormap(bone)
caxis([db_min(1) db_max(1)])
axis([x_min_ref x_max_ref y_min_ref y_max_ref elev_min_ref elev_max_ref])
box off
grid on
[curr_az3, curr_el3]        = view(3);
set(gca, 'fontsize', size_font, 'layer', 'top', 'dataaspectratio', [1 1 aspect_ratio])
xlabel('X (km)')
ylabel('Y (km)')
zlabel('Elevation (m)')
colorbar('fontsize', size_font)

% sliders
x_min_slide                 = uicontrol(fgui(1), 'style', 'slider', 'units', 'normalized', 'position', [0.11 0.04 0.24 0.02], 'callback', @slide_x_min, 'min', 0, 'max', 1, 'value', x_min_ref, 'sliderstep', [0.01 0.1]);
x_max_slide                 = uicontrol(fgui(1), 'style', 'slider', 'units', 'normalized', 'position', [0.11 0.01 0.24 0.02], 'callback', @slide_x_max, 'min', 0, 'max', 1, 'value', x_max_ref, 'sliderstep', [0.01 0.1]);
y_min_slide                 = uicontrol(fgui(1), 'style', 'slider', 'units', 'normalized', 'position', [0.62 0.04 0.24 0.02], 'callback', @slide_y_min, 'min', 0, 'max', 1, 'value', x_min_ref, 'sliderstep', [0.01 0.1]);
y_max_slide                 = uicontrol(fgui(1), 'style', 'slider', 'units', 'normalized', 'position', [0.62 0.01 0.24 0.02], 'callback', @slide_y_max, 'min', 0, 'max', 1, 'value', x_max_ref, 'sliderstep', [0.01 0.1]);
z_min_slide(1)              = uicontrol(fgui(1), 'style', 'slider', 'units', 'normalized', 'position', [0.005 0.07 width_slide 0.32], 'callback', @slide_z_min1, 'min', 0, 'max', 1, 'value', elev_min_ref, 'sliderstep', [0.01 0.1]);
z_max_slide(1)              = uicontrol(fgui(1), 'style', 'slider', 'units', 'normalized', 'position', [0.005 0.52 width_slide 0.32], 'callback', @slide_z_max1, 'min', 0, 'max', 1, 'value', elev_max_ref, 'sliderstep', [0.01 0.1]);
cb_min_slide(1)             = uicontrol(fgui(1), 'style', 'slider', 'units', 'normalized', 'position', [0.97 0.07 width_slide 0.32], 'callback', @slide_db_min1, 'min', db_min_ref(1), 'max', db_max_ref(1), 'value', db_min(1), 'sliderstep', [0.01 0.1]);
cb_max_slide(1)             = uicontrol(fgui(1), 'style', 'slider', 'units', 'normalized', 'position', [0.97 0.50 width_slide 0.32], 'callback', @slide_db_max1, 'min', db_min_ref(1), 'max', db_max_ref(1), 'value', db_max(1), 'sliderstep', [0.01 0.1]);

% slider values
cb_min_edit(1)              = annotation('textbox', [0.965 0.39 0.04 0.03], 'string', num2str(db_min(1)), 'fontsize', size_font, 'color', 'k', 'edgecolor', 'none');
cb_max_edit(1)              = annotation('textbox', [0.965 0.82 0.04 0.03], 'string', num2str(db_max(1)), 'fontsize', size_font, 'color', 'k', 'edgecolor', 'none');
x_min_edit                  = annotation('textbox', [0.07 0.045 0.04 0.03], 'string', num2str(x_min_ref), 'fontsize', size_font, 'color', 'k', 'edgecolor', 'none');
x_max_edit                  = annotation('textbox', [0.07 0.005 0.04 0.03], 'string', num2str(x_max_ref), 'fontsize', size_font, 'color', 'k', 'edgecolor', 'none');
y_min_edit                  = annotation('textbox', [0.90 0.045 0.04 0.03], 'string', num2str(y_min_ref), 'fontsize', size_font, 'color', 'k', 'edgecolor', 'none');
y_max_edit                  = annotation('textbox', [0.90 0.005 0.04 0.03], 'string', num2str(y_max_ref), 'fontsize', size_font, 'color', 'k', 'edgecolor', 'none');
z_min_edit(1)               = annotation('textbox', [0.005 0.39 0.04 0.03], 'string', num2str(elev_min_ref), 'fontsize', size_font, 'color', 'k', 'edgecolor', 'none');
z_max_edit(1)               = annotation('textbox', [0.005 0.84 0.04 0.03], 'string', num2str(elev_max_ref), 'fontsize', size_font, 'color', 'k', 'edgecolor', 'none');

% push buttons
uicontrol(fgui(1), 'style', 'pushbutton', 'string', 'Load master transect', 'units', 'normalized', 'position', [0.005 0.965 0.10 0.03], 'callback', @load_pk1, 'fontsize', size_font, 'foregroundcolor', 'b')
uicontrol(fgui(1), 'style', 'pushbutton', 'string', 'Next', 'units', 'normalized', 'position', [0.245 0.925 0.03 0.03], 'callback', @pk_next1, 'fontsize', size_font, 'foregroundcolor', 'm')
uicontrol(fgui(1), 'style', 'pushbutton', 'string', 'Next', 'units', 'normalized', 'position', [0.51 0.925 0.03 0.03], 'callback', @pk_next2, 'fontsize', size_font, 'foregroundcolor', 'm')
uicontrol(fgui(1), 'style', 'pushbutton', 'string', 'Last', 'units', 'normalized', 'position', [0.215 0.925 0.03 0.03], 'callback', @pk_last1, 'fontsize', size_font, 'foregroundcolor', 'm')
uicontrol(fgui(1), 'style', 'pushbutton', 'string', 'Last', 'units', 'normalized', 'position', [0.48 0.925 0.03 0.03], 'callback', @pk_last2, 'fontsize', size_font, 'foregroundcolor', 'm')
uicontrol(fgui(1), 'style', 'pushbutton', 'string', 'Test', 'units', 'normalized', 'position', [0.865 0.965 0.03 0.03], 'callback', @misctest, 'fontsize', size_font, 'foregroundcolor', 'r')
uicontrol(fgui(1), 'style', 'pushbutton', 'string', 'Save', 'units', 'normalized', 'position', [0.965 0.965 0.03 0.03], 'callback', @pk_save, 'fontsize', size_font, 'foregroundcolor', 'g')
uicontrol(fgui(1), 'style', 'pushbutton', 'string', 'Transects', 'units', 'normalized', 'position', [0.63 0.965 0.05 0.03], 'callback', @load_int, 'fontsize', size_font, 'foregroundcolor', 'b')
uicontrol(fgui(1), 'style', 'pushbutton', 'string', 'Cores', 'units', 'normalized', 'position', [0.695 0.965 0.03 0.03], 'callback', @load_core, 'fontsize', size_font, 'foregroundcolor', 'b')
uicontrol(fgui(1), 'style', 'pushbutton', 'string', 'Matching', 'units', 'normalized', 'position', [0.745 0.965 0.04 0.03], 'callback', @load_match, 'fontsize', size_font, 'foregroundcolor', 'b')
uicontrol(fgui(1), 'style', 'pushbutton', 'string', 'Reset x/y/z', 'units', 'normalized', 'position', [0.94 0.925 0.055 0.03], 'callback', @reset_xyz, 'fontsize', size_font, 'foregroundcolor', 'r')
uicontrol(fgui(1), 'style', 'pushbutton', 'string', 'Reset', 'units', 'normalized', 'position', [0.36 0.04 0.03 0.03], 'callback', @reset_x_min, 'fontsize', size_font, 'foregroundcolor', 'r')
uicontrol(fgui(1), 'style', 'pushbutton', 'string', 'Reset', 'units', 'normalized', 'position', [0.36 0.005 0.03 0.03], 'callback', @reset_x_max, 'fontsize', size_font, 'foregroundcolor', 'r')
uicontrol(fgui(1), 'style', 'pushbutton', 'string', 'Reset', 'units', 'normalized', 'position', [0.585 0.04 0.03 0.03], 'callback', @reset_y_min, 'fontsize', size_font, 'foregroundcolor', 'r')
uicontrol(fgui(1), 'style', 'pushbutton', 'string', 'Reset', 'units', 'normalized', 'position', [0.585 0.005 0.03 0.03], 'callback', @reset_y_max, 'fontsize', size_font, 'foregroundcolor', 'r')
uicontrol(fgui(1), 'style', 'pushbutton', 'string', 'Reset', 'units', 'normalized', 'position', [0.005 0.005 0.03 0.03], 'callback', @reset_z_min1, 'fontsize', size_font, 'foregroundcolor', 'r')
uicontrol(fgui(1), 'style', 'pushbutton', 'string', 'Reset', 'units', 'normalized', 'position', [0.005 0.48 0.03 0.03], 'callback', @reset_z_max1, 'fontsize', size_font, 'foregroundcolor', 'r')
uicontrol(fgui(1), 'style', 'pushbutton', 'string', 'Reset', 'units', 'normalized', 'position', [0.965 0.03 0.03 0.03], 'callback', @reset_db_min1, 'fontsize', size_font, 'foregroundcolor', 'r')
uicontrol(fgui(1), 'style', 'pushbutton', 'string', 'Reset', 'units', 'normalized', 'position', [0.965 0.46 0.03 0.03], 'callback', @reset_db_max1, 'fontsize', size_font, 'foregroundcolor', 'r')

% fixed text annotations
a(1)                        = annotation('textbox', [0.12 0.965 0.025 0.03], 'string', 'N_{decim}', 'fontsize', size_font, 'color', 'b', 'edgecolor', 'none');
a(2)                        = annotation('textbox', [0.37 0.965 0.025 0.03], 'string', 'N_{decim}', 'fontsize', size_font, 'color', 'b', 'edgecolor', 'none');
a(3)                        = annotation('textbox', [0.195 0.965 0.03 0.03], 'string', 'Layer', 'fontsize', size_font, 'color', 'm', 'edgecolor', 'none');
a(4)                        = annotation('textbox', [0.445 0.965 0.03 0.03], 'string', 'Layer', 'fontsize', size_font, 'color', 'm', 'edgecolor', 'none');
a(5)                        = annotation('textbox', [0.90 0.925 0.03 0.03], 'string', 'Grid', 'fontsize', size_font, 'color', 'k', 'edgecolor', 'none');
a(6)                        = annotation('textbox', [0.04 0.04 0.03 0.03], 'string', 'x_{min}', 'fontsize', size_font, 'color', 'k', 'edgecolor', 'none');
a(7)                        = annotation('textbox', [0.04 0.005 0.03 0.03], 'string', 'x_{max}', 'fontsize', size_font, 'color', 'k', 'edgecolor', 'none');
a(8)                        = annotation('textbox', [0.87 0.04 0.03 0.03], 'string', 'y_{min}', 'fontsize', size_font, 'color', 'k', 'edgecolor', 'none');
a(9)                        = annotation('textbox', [0.87 0.005 0.03 0.03], 'string', 'y_{max}', 'fontsize', size_font, 'color', 'k', 'edgecolor', 'none');
a(10)                       = annotation('textbox', [0.005 0.42 0.03 0.03], 'string', 'z_{min}', 'fontsize', size_font, 'color', 'k', 'edgecolor', 'none');
a(11)                       = annotation('textbox', [0.005 0.87 0.03 0.03], 'string', 'z_{max}', 'fontsize', size_font, 'color', 'k', 'edgecolor', 'none');
a(12)                       = annotation('textbox', [0.005 0.89 0.03 0.03], 'string', 'fix', 'fontsize', size_font, 'color', 'k', 'edgecolor', 'none');
a(13)                       = annotation('textbox', [0.395 0.005 0.03 0.03], 'string', 'fix', 'fontsize', size_font, 'color', 'k', 'edgecolor', 'none');
a(14)                       = annotation('textbox', [0.57 0.005 0.03 0.03], 'string', 'fix', 'fontsize', size_font, 'color', 'k', 'edgecolor', 'none');
a(15)                       = annotation('textbox', [0.28 0.965 0.10 0.03], 'string', 'Intersecting picks', 'fontsize', size_font, 'color', 'b', 'edgecolor', 'none');
a(16)                       = annotation('textbox', [0.545 0.965 0.12 0.03], 'string', 'Load intersections', 'fontsize', size_font, 'color', 'b', 'edgecolor', 'none');
a(17)                       = annotation('textbox', [0.17 0.925 0.04 0.03], 'string', 'data', 'fontsize', size_font, 'color', 'b', 'edgecolor', 'none');
a(18)                       = annotation('textbox', [0.44 0.925 0.04 0.03], 'string', 'data', 'fontsize', size_font, 'color', 'b', 'edgecolor', 'none');
a(19)                       = annotation('textbox', [0.965 0.42 0.03 0.03], 'string', 'dB_{min}', 'fontsize', size_font, 'color', 'k', 'edgecolor', 'none');
a(20)                       = annotation('textbox', [0.965 0.85 0.03 0.03], 'string', 'dB_{max}', 'fontsize', size_font, 'color', 'k', 'edgecolor', 'none');
a(21)                       = annotation('textbox', [0.95 0.88 0.03 0.03], 'string', 'fix 1', 'fontsize', size_font, 'color', 'k', 'edgecolor', 'none');
a(22)                       = annotation('textbox', [0.98 0.88 0.03 0.03], 'string', '2', 'fontsize', size_font, 'color', 'k', 'edgecolor', 'none');
a(23)                       = annotation('textbox', [0.805 0.965 0.04 0.03], 'string', 'aspect', 'fontsize', size_font, 'color', 'k', 'edgecolor', 'none');
if ~ispc
    set(a, 'fontweight', 'bold')
end

% variable text annotations
file_box(1)                 = annotation('textbox', [0.005 0.925 0.10 0.03], 'string', '', 'color', 'k', 'fontsize', size_font, 'backgroundcolor', 'w', 'edgecolor', 'k', 'interpreter', 'none', 'linewidth', 1);
status_box(1)               = annotation('textbox', [0.545 0.925 0.35 0.03], 'string', '', 'color', 'k', 'fontsize', size_font, 'backgroundcolor', 'w', 'edgecolor', 'k', 'interpreter', 'none', 'linewidth', 1);

dim_group                   = uibuttongroup('position', [0.90 0.965 0.06 0.03], 'selectionchangefcn', @choose_dim);
uicontrol(fgui(1), 'style', 'text', 'parent', dim_group, 'units', 'normalized', 'position', [0 0.6 0.9 0.3], 'fontsize', size_font)
dim_check(1)                = uicontrol(fgui(1), 'style', 'radio', 'string', '2D', 'units', 'normalized', 'position', [0.01 0.1 0.45 0.8], 'parent', dim_group, 'fontsize', size_font, 'handlevisibility', 'off');
dim_check(2)                = uicontrol(fgui(1), 'style', 'radio', 'string', '3D', 'units', 'normalized', 'position', [0.51 0.1 0.45 0.8], 'parent', dim_group, 'fontsize', size_font, 'handlevisibility', 'off');
set(dim_group, 'selectedobject', dim_check(2))

% value boxes
decim_edit(1, 1)            = uicontrol(fgui(1), 'style', 'edit', 'string', num2str(decim(1)), 'units', 'normalized', 'position', [0.16 0.965 0.03 0.03], 'fontsize', size_font, 'foregroundcolor', 'k', 'backgroundcolor', 'w', 'callback', @adj_decim1);
decim_edit(1, 2)            = uicontrol(fgui(1), 'style', 'edit', 'string', num2str(decim(2)), 'units', 'normalized', 'position', [0.405 0.965 0.03 0.03], 'fontsize', size_font, 'foregroundcolor', 'k', 'backgroundcolor', 'w', 'callback', @adj_decim2);
aspect_edit                 = uicontrol(fgui(1), 'style', 'edit', 'string', num2str(aspect_ratio), 'units', 'normalized', 'position', [0.84 0.965 0.02 0.03], 'fontsize', size_font, 'foregroundcolor', 'k', 'backgroundcolor', 'w', 'callback', @adj_aspect);

% menus
layer_list(1, 1)            = uicontrol(fgui(1), 'style', 'popupmenu', 'string', 'N/A', 'value', 1, 'units', 'normalized', 'position', [0.225 0.955 0.05 0.04], 'fontsize', size_font, 'foregroundcolor', 'k', 'callback', @pk_select1);
layer_list(1, 2)            = uicontrol(fgui(1), 'style', 'popupmenu', 'string', 'N/A', 'value', 1, 'units', 'normalized', 'position', [0.49 0.955 0.05 0.04], 'fontsize', size_font, 'foregroundcolor', 'k', 'callback', @pk_select2);
int_list                    = uicontrol(fgui(1), 'style', 'popupmenu', 'string', 'N/A', 'value', 1, 'units', 'normalized', 'position', [0.28 0.915 0.10 0.04], 'fontsize', size_font, 'foregroundcolor', 'k', 'callback', @load_pk2);
cmap_list(1)                = uicontrol(fgui(1), 'style', 'popupmenu', 'string', cmaps, 'value', 1, 'units', 'normalized', 'position', [0.945 0.005 0.05 0.03], 'callback', @change_cmap1, 'fontsize', size_font);
subtrans_list               = uicontrol(fgui(1), 'style', 'popupmenu', 'string', 'N/A', 'value', 1, 'units', 'normalized', 'position', [0.11 0.915 0.05 0.04], 'fontsize', size_font, 'foregroundcolor', 'k', 'callback', @load_subtrans);

% check boxes
xfix_check                  = uicontrol(fgui(1), 'style', 'checkbox', 'units', 'normalized', 'position', [0.415 0.005 0.01 0.02], 'fontsize', size_font, 'value', 0, 'backgroundcolor', get(fgui(1), 'color'));
yfix_check                  = uicontrol(fgui(1), 'style', 'checkbox', 'units', 'normalized', 'position', [0.56 0.005 0.01 0.02], 'fontsize', size_font, 'value', 0, 'backgroundcolor', get(fgui(1), 'color'));
zfix_check(1)               = uicontrol(fgui(1), 'style', 'checkbox', 'units', 'normalized', 'position', [0.02 0.89 0.01 0.02], 'fontsize', size_font, 'value', 0, 'backgroundcolor', get(fgui(1), 'color'));
grid_check(1)               = uicontrol(fgui(1), 'style', 'checkbox', 'units', 'normalized', 'position', [0.925 0.925 0.01 0.02], 'callback', @toggle_grid1, 'fontsize', size_font, 'value', 1, 'backgroundcolor', get(fgui(1), 'color'));
pk_check(1, 1)              = uicontrol(fgui(1), 'style', 'checkbox', 'units', 'normalized', 'position', [0.105 0.965 0.01 0.02], 'callback', @show_pk1, 'fontsize', size_font, 'value', 0, 'backgroundcolor', get(fgui(1), 'color'));
pk_check(1, 2)              = uicontrol(fgui(1), 'style', 'checkbox', 'units', 'normalized', 'position', [0.36 0.965 0.01 0.02], 'callback', @show_pk2, 'fontsize', size_font, 'value', 0, 'backgroundcolor', get(fgui(1), 'color'));
int_check(1)                = uicontrol(fgui(1), 'style', 'checkbox', 'units', 'normalized', 'position', [0.68 0.965 0.01 0.02], 'callback', @show_int1, 'fontsize', size_font, 'value', 0, 'backgroundcolor', get(fgui(1), 'color'));
core_check(1)               = uicontrol(fgui(1), 'style', 'checkbox', 'units', 'normalized', 'position', [0.73 0.965 0.01 0.02], 'callback', @show_core1, 'fontsize', size_font, 'value', 0, 'backgroundcolor', get(fgui(1), 'color'));
data_check(1, 1)            = uicontrol(fgui(1), 'style', 'checkbox', 'units', 'normalized', 'position', [0.20 0.925 0.01 0.02], 'callback', @show_data1, 'fontsize', size_font, 'value', 0, 'backgroundcolor', get(fgui(1), 'color'));
data_check(1, 2)            = uicontrol(fgui(1), 'style', 'checkbox', 'units', 'normalized', 'position', [0.465 0.925 0.01 0.02], 'callback', @show_data2, 'fontsize', size_font, 'value', 0, 'backgroundcolor', get(fgui(1), 'color'));
cbfix_check1(1)             = uicontrol(fgui(1), 'style', 'checkbox', 'units', 'normalized', 'position', [0.97 0.88 0.01 0.02], 'fontsize', size_font, 'value', 0, 'backgroundcolor', get(fgui(1), 'color'));
cbfix_check2(1)             = uicontrol(fgui(1), 'style', 'checkbox', 'units', 'normalized', 'position', [0.985 0.88 0.01 0.02], 'callback', @narrow_cb1, 'fontsize', size_font, 'value', 1, 'backgroundcolor', get(fgui(1), 'color'));
match_check                 = uicontrol(fgui(1), 'style', 'checkbox', 'units', 'normalized', 'position', [0.79 0.965 0.01 0.02], 'fontsize', size_font, 'value', 0, 'backgroundcolor', get(fgui(1), 'color'));

pause(0.5)

%% draw second GUI

fgui(2)                     = figure('toolbar', 'figure', 'name', 'FENCEGUI 2D', 'menubar', 'none', 'keypressfcn', @keypress2, 'windowbuttondownfcn', @mouse_click);
ax(2)                       = subplot('position', [0.065 0.06 0.41 0.81]);
ax(3)                       = subplot('position', [0.55 0.06 0.41 0.81]);

set(ax(2:3), 'fontsize', size_font, 'layer', 'top')

axes(ax(2))
hold on
colormap(bone)
caxis([db_min(2) db_max(2)])
axis([dist_min_ref(1) dist_max_ref(1) elev_min_ref elev_max_ref])
box on
grid off
ylabel('(m)');
colorbar('fontsize', size_font)
% pan/zoom callbacks
h_pan(1)                    = pan;
set(h_pan(1), 'actionpostcallback', @panzoom1)
h_zoom(1)                   = zoom;
set(h_zoom(1), 'actionpostcallback', @panzoom1)

axes(ax(3))
hold on
colormap(bone)
caxis([db_min(3) db_max(3)])
axis([dist_min_ref(2) dist_max_ref(2) elev_min_ref elev_max_ref])
box on
grid off
colorbar('fontsize', size_font)
% pan/zoom callbacks
h_pan(2)                    = pan;
set(h_pan(2), 'actionpostcallback', @panzoom2)
h_zoom(2)                   = zoom;
set(h_zoom(2), 'actionpostcallback', @panzoom2)

% sliders
cb_min_slide(2)             = uicontrol(fgui(2), 'style', 'slider', 'units', 'normalized', 'position', [0.475 0.07 width_slide 0.32], 'callback', @slide_db_min2, 'min', db_min_ref(2), 'max', db_max_ref(2), 'value', db_min(2), 'sliderstep', [0.01 0.1]);
cb_max_slide(2)             = uicontrol(fgui(2), 'style', 'slider', 'units', 'normalized', 'position', [0.475 0.50 width_slide 0.32], 'callback', @slide_db_max2, 'min', db_min_ref(2), 'max', db_max_ref(2), 'value', db_max(2), 'sliderstep', [0.01 0.1]);
cb_min_slide(3)             = uicontrol(fgui(2), 'style', 'slider', 'units', 'normalized', 'position', [0.97 0.07 width_slide 0.32], 'callback', @slide_db_min3, 'min', db_min_ref(3), 'max', db_max_ref(3), 'value', db_min(3), 'sliderstep', [0.01 0.1]);
cb_max_slide(3)             = uicontrol(fgui(2), 'style', 'slider', 'units', 'normalized', 'position', [0.97 0.50 width_slide 0.32], 'callback', @slide_db_max3, 'min', db_min_ref(3), 'max', db_max_ref(3), 'value', db_max(3), 'sliderstep', [0.01 0.1]);
dist_min_slide(1)           = uicontrol(fgui(2), 'style', 'slider', 'units', 'normalized', 'position', [0.10 0.005 0.12 0.02], 'callback', @slide_dist_min1, 'min', dist_min_ref(1), 'max', dist_max_ref(1), 'value', dist_min_ref(1), 'sliderstep', [0.01 0.1]);
dist_max_slide(1)           = uicontrol(fgui(2), 'style', 'slider', 'units', 'normalized', 'position', [0.33 0.005 0.12 0.02], 'callback', @slide_dist_max1, 'min', dist_min_ref(1), 'max', dist_max_ref(1), 'value', dist_max_ref(1), 'sliderstep', [0.01 0.1]);
dist_min_slide(2)           = uicontrol(fgui(2), 'style', 'slider', 'units', 'normalized', 'position', [0.58 0.005 0.12 0.02], 'callback', @slide_dist_min2, 'min', dist_min_ref(2), 'max', dist_max_ref(2), 'value', dist_min_ref(2), 'sliderstep', [0.01 0.1]);
dist_max_slide(2)           = uicontrol(fgui(2), 'style', 'slider', 'units', 'normalized', 'position', [0.81 0.005 0.12 0.02], 'callback', @slide_dist_max2, 'min', dist_min_ref(2), 'max', dist_max_ref(2), 'value', dist_max_ref(2), 'sliderstep', [0.01 0.1]);
z_min_slide(2)              = uicontrol(fgui(2), 'style', 'slider', 'units', 'normalized', 'position', [0.005 0.07 width_slide 0.32], 'callback', @slide_z_min2, 'min', elev_min_ref, 'max', elev_max_ref, 'value', elev_min_ref, 'sliderstep', [0.01 0.1]);
z_max_slide(2)              = uicontrol(fgui(2), 'style', 'slider', 'units', 'normalized', 'position', [0.005 0.50 width_slide 0.32], 'callback', @slide_z_max2, 'min', elev_min_ref, 'max', elev_max_ref, 'value', elev_max_ref, 'sliderstep', [0.01 0.1]);

% slider values
cb_min_edit(2)              = annotation('textbox', [0.48 0.39 0.04 0.03], 'string', num2str(db_min(1)), 'fontsize', size_font, 'color', 'k', 'edgecolor', 'none');
cb_min_edit(3)              = annotation('textbox', [0.965 0.39 0.04 0.03], 'string', num2str(db_min(2)), 'fontsize', size_font, 'color', 'k', 'edgecolor', 'none');
cb_max_edit(2)              = annotation('textbox', [0.48 0.82 0.04 0.03], 'string', num2str(db_max(1)), 'fontsize', size_font, 'color', 'k', 'edgecolor', 'none');
cb_max_edit(3)              = annotation('textbox', [0.965 0.82 0.04 0.03], 'string', num2str(db_max(2)), 'fontsize', size_font, 'color', 'k', 'edgecolor', 'none');
dist_min_edit(1)            = annotation('textbox', [0.07 0.005 0.04 0.03], 'string', num2str(dist_min_ref(1)), 'fontsize', size_font, 'color', 'k', 'edgecolor', 'none');
dist_min_edit(2)            = annotation('textbox', [0.55 0.005 0.04 0.03], 'string', num2str(dist_min_ref(2)), 'fontsize', size_font, 'color', 'k', 'edgecolor', 'none');
dist_max_edit(1)            = annotation('textbox', [0.295 0.005 0.04 0.03], 'string', num2str(dist_max_ref(1)), 'fontsize', size_font, 'color', 'k', 'edgecolor', 'none');
dist_max_edit(2)            = annotation('textbox', [0.775 0.005 0.04 0.03], 'string', num2str(dist_max_ref(2)), 'fontsize', size_font, 'color', 'k', 'edgecolor', 'none');
z_min_edit(2)               = annotation('textbox', [0.005 0.39 0.04 0.03], 'string', num2str(elev_min_ref), 'fontsize', size_font, 'color', 'k', 'edgecolor', 'none');
z_max_edit(2)               = annotation('textbox', [0.005 0.82 0.04 0.03], 'string', num2str(elev_min_ref), 'fontsize', size_font, 'color', 'k', 'edgecolor', 'none');

% push buttons
uicontrol(fgui(2), 'style', 'pushbutton', 'string', 'Load master data', 'units', 'normalized', 'position', [0.005 0.925 0.085 0.03], 'callback', @load_data1, 'fontsize', size_font, 'foregroundcolor', 'b')
uicontrol(fgui(2), 'style', 'pushbutton', 'string', 'Load intersecting data', 'units', 'normalized', 'position', [0.345 0.925 0.11 0.03], 'callback', @load_data2, 'fontsize', size_font, 'foregroundcolor', 'b')
uicontrol(fgui(2), 'style', 'pushbutton', 'string', 'Match', 'units', 'normalized', 'position', [0.645 0.925 0.04 0.03], 'callback', @pk_match, 'fontsize', size_font, 'foregroundcolor', 'm')
uicontrol(fgui(2), 'style', 'pushbutton', 'string', 'Unmatch', 'units', 'normalized', 'position', [0.69 0.925 0.05 0.03], 'callback', @pk_unmatch, 'fontsize', size_font, 'foregroundcolor', 'm')
uicontrol(fgui(2), 'style', 'pushbutton', 'string', 'Select', 'units', 'normalized', 'position', [0.17 0.925 0.045 0.03], 'callback', @pk_select_gui1, 'fontsize', size_font, 'foregroundcolor', 'm')
uicontrol(fgui(2), 'style', 'pushbutton', 'string', 'Select', 'units', 'normalized', 'position', [0.535 0.925 0.045 0.03], 'callback', @pk_select_gui2, 'fontsize', size_font, 'foregroundcolor', 'm')
uicontrol(fgui(2), 'style', 'pushbutton', 'string', 'Next', 'units', 'normalized', 'position', [0.245 0.925 0.03 0.03], 'callback', @pk_next3, 'fontsize', size_font, 'foregroundcolor', 'm')
uicontrol(fgui(2), 'style', 'pushbutton', 'string', 'Next', 'units', 'normalized', 'position', [0.61 0.925 0.03 0.03], 'callback', @pk_next4, 'fontsize', size_font, 'foregroundcolor', 'm')
uicontrol(fgui(2), 'style', 'pushbutton', 'string', 'Last', 'units', 'normalized', 'position', [0.215 0.925 0.03 0.03], 'callback', @pk_last3, 'fontsize', size_font, 'foregroundcolor', 'm')
uicontrol(fgui(2), 'style', 'pushbutton', 'string', 'Last', 'units', 'normalized', 'position', [0.58 0.925 0.03 0.03], 'callback', @pk_last4, 'fontsize', size_font, 'foregroundcolor', 'm')
uicontrol(fgui(2), 'style', 'pushbutton', 'string', 'Test', 'units', 'normalized', 'position', [0.91 0.925 0.03 0.03], 'callback', @misctest, 'fontsize', size_font, 'foregroundcolor', 'r')
uicontrol(fgui(2), 'style', 'pushbutton', 'string', 'Reset x/z', 'units', 'normalized', 'position', [0.41 0.885 0.05 0.03], 'callback', @reset_xz1, 'fontsize', size_font, 'foregroundcolor', 'r')
uicontrol(fgui(2), 'style', 'pushbutton', 'string', 'Reset x/z', 'units', 'normalized', 'position', [0.895 0.885 0.05 0.03], 'callback', @reset_xz2, 'fontsize', size_font, 'foregroundcolor', 'r')
uicontrol(fgui(2), 'style', 'pushbutton', 'string', 'Reset', 'units', 'normalized', 'position', [0.005 0.03 0.03 0.03], 'callback', @reset_z_min2, 'fontsize', size_font, 'foregroundcolor', 'r')
uicontrol(fgui(2), 'style', 'pushbutton', 'string', 'Reset', 'units', 'normalized', 'position', [0.005 0.46 0.03 0.03], 'callback', @reset_z_max2, 'fontsize', size_font, 'foregroundcolor', 'r')
uicontrol(fgui(2), 'style', 'pushbutton', 'string', 'Reset', 'units', 'normalized', 'position', [0.225 0.005 0.03 0.03], 'callback', @reset_dist_min1, 'fontsize', size_font, 'foregroundcolor', 'r')
uicontrol(fgui(2), 'style', 'pushbutton', 'string', 'Reset', 'units', 'normalized', 'position', [0.455 0.005 0.03 0.03], 'callback', @reset_dist_max1, 'fontsize', size_font, 'foregroundcolor', 'r')
uicontrol(fgui(2), 'style', 'pushbutton', 'string', 'Reset', 'units', 'normalized', 'position', [0.48 0.03 0.03 0.03], 'callback', @reset_db_min2, 'fontsize', size_font, 'foregroundcolor', 'r')
uicontrol(fgui(2), 'style', 'pushbutton', 'string', 'Reset', 'units', 'normalized', 'position', [0.48 0.46 0.03 0.03], 'callback', @reset_db_max2, 'fontsize', size_font, 'foregroundcolor', 'r')
uicontrol(fgui(2), 'style', 'pushbutton', 'string', 'Reset', 'units', 'normalized', 'position', [0.705 0.005 0.03 0.03], 'callback', @reset_dist_min2, 'fontsize', size_font, 'foregroundcolor', 'r')
uicontrol(fgui(2), 'style', 'pushbutton', 'string', 'Reset', 'units', 'normalized', 'position', [0.935 0.005 0.03 0.03], 'callback', @reset_dist_max2, 'fontsize', size_font, 'foregroundcolor', 'r')
uicontrol(fgui(2), 'style', 'pushbutton', 'string', 'Reset', 'units', 'normalized', 'position', [0.965 0.03 0.03 0.03], 'callback', @reset_db_min3, 'fontsize', size_font, 'foregroundcolor', 'r')
uicontrol(fgui(2), 'style', 'pushbutton', 'string', 'Reset', 'units', 'normalized', 'position', [0.965 0.46 0.03 0.03], 'callback', @reset_db_max3, 'fontsize', size_font, 'foregroundcolor', 'r')
uicontrol(fgui(2), 'style', 'pushbutton', 'string', 'Focus', 'units', 'normalized', 'position', [0.28 0.925 0.04 0.03], 'callback', @pk_focus1, 'fontsize', size_font, 'foregroundcolor', 'm')
uicontrol(fgui(2), 'style', 'pushbutton', 'string', 'Focus', 'units', 'normalized', 'position', [0.645 0.965 0.04 0.03], 'callback', @pk_focus2, 'fontsize', size_font, 'foregroundcolor', 'm')

% fixed text annotations
b(1)                        = annotation('textbox', [0.10 0.925 0.03 0.03], 'string', 'N_{decim}', 'fontsize', size_font, 'color', 'b', 'edgecolor', 'none');
b(2)                        = annotation('textbox', [0.465 0.925 0.03 0.03], 'string', 'N_{decim}', 'fontsize', size_font, 'color', 'b', 'edgecolor', 'none');
b(3)                        = annotation('textbox', [0.49 0.42 0.03 0.03], 'string', 'dB_{min}', 'fontsize', size_font, 'color', 'k', 'edgecolor', 'none');
b(4)                        = annotation('textbox', [0.49 0.85 0.03 0.03], 'string', 'dB_{max}', 'fontsize', size_font, 'color', 'k', 'edgecolor', 'none');
b(5)                        = annotation('textbox', [0.965 0.42 0.03 0.03], 'string', 'dB_{min}', 'fontsize', size_font, 'color', 'k', 'edgecolor', 'none');
b(6)                        = annotation('textbox', [0.965 0.85 0.03 0.03], 'string', 'dB_{max}', 'fontsize', size_font, 'color', 'k', 'edgecolor', 'none');
b(7)                        = annotation('textbox', [0.18 0.965 0.03 0.03], 'string', 'Layer', 'fontsize', size_font, 'color', 'm', 'edgecolor', 'none');
b(8)                        = annotation('textbox', [0.52 0.965 0.03 0.03], 'string', 'Layer', 'fontsize', size_font, 'color', 'm', 'edgecolor', 'none');
b(9)                        = annotation('textbox', [0.37 0.88 0.03 0.03], 'string', 'Grid', 'fontsize', size_font, 'color', 'k', 'edgecolor', 'none');
b(10)                       = annotation('textbox', [0.855 0.88 0.03 0.03], 'string', 'Grid', 'fontsize', size_font, 'color', 'k', 'edgecolor', 'none');
b(11)                       = annotation('textbox', [0.035 0.005 0.03 0.03], 'string', 'dist_{min}', 'fontsize', size_font, 'color', 'k', 'edgecolor', 'none');
b(12)                       = annotation('textbox', [0.515 0.005 0.03 0.03], 'string', 'dist_{min}', 'fontsize', size_font, 'color', 'k', 'edgecolor', 'none');
b(13)                       = annotation('textbox', [0.26 0.005 0.03 0.03], 'string', 'dist_{max}', 'fontsize', size_font, 'color', 'k', 'edgecolor', 'none');
b(14)                       = annotation('textbox', [0.74 0.005 0.03 0.03], 'string', 'dist_{max}', 'fontsize', size_font, 'color', 'k', 'edgecolor', 'none');
b(15)                       = annotation('textbox', [0.005 0.42 0.03 0.03], 'string', 'z_{min}', 'fontsize', size_font, 'color', 'k', 'edgecolor', 'none');
b(16)                       = annotation('textbox', [0.005 0.85 0.03 0.03], 'string', 'z_{max}', 'fontsize', size_font, 'color', 'k', 'edgecolor', 'none');
b(17)                       = annotation('textbox', [0.005 0.88 0.03 0.03], 'string', 'fix', 'fontsize', size_font, 'color', 'k', 'edgecolor', 'none');
b(18)                       = annotation('textbox', [0.485 0.005 0.03 0.03], 'string', 'fix', 'fontsize', size_font, 'color', 'k', 'edgecolor', 'none');
b(19)                       = annotation('textbox', [0.965 0.005 0.03 0.03], 'string', 'fix', 'fontsize', size_font, 'color', 'k', 'edgecolor', 'none');
b(20)                       = annotation('textbox', [0.95 0.88 0.03 0.03], 'string', 'fix 1', 'fontsize', size_font, 'color', 'k', 'edgecolor', 'none');
b(21)                       = annotation('textbox', [0.98 0.88 0.03 0.03], 'string', '2', 'fontsize', size_font, 'color', 'k', 'edgecolor', 'none');
b(22)                       = annotation('textbox', [0.465 0.88 0.03 0.03], 'string', 'fix 1', 'fontsize', size_font, 'color', 'k', 'edgecolor', 'none');
b(23)                       = annotation('textbox', [0.4925 0.88 0.03 0.03], 'string', '2', 'fontsize', size_font, 'color', 'k', 'edgecolor', 'none');
b(24)                       = annotation('textbox', [0.04 0.88 0.08 0.03], 'string', 'Intersection #', 'fontsize', size_font, 'color', 'b', 'edgecolor', 'none');
b(25)                       = annotation('textbox', [0.15 0.88 0.08 0.03], 'string', 'Core', 'fontsize', size_font, 'color', 'b', 'edgecolor', 'none');
b(26)                       = annotation('textbox', [0.56 0.88 0.08 0.03], 'string', 'Intersections', 'fontsize', size_font, 'color', 'b', 'edgecolor', 'none');
b(27)                       = annotation('textbox', [0.635 0.88 0.08 0.03], 'string', 'Core', 'fontsize', size_font, 'color', 'b', 'edgecolor', 'none');
b(28)                       = annotation('textbox', [0.74 0.925 0.08 0.03], 'string', 'Nearest', 'fontsize', size_font, 'color', 'm', 'edgecolor', 'none');
b(29)                       = annotation('textbox', [0.79 0.925 0.08 0.03], 'string', 'Match', 'fontsize', size_font, 'color', 'm', 'edgecolor', 'none');
if ~ispc
    set(b, 'fontweight', 'bold')
end

% variable text annotations
file_box(2)                 = annotation('textbox', [0.005 0.965 0.16 0.03], 'string', '', 'color', 'k', 'fontsize', size_font, 'backgroundcolor', 'w', 'edgecolor', 'k', 'interpreter', 'none', 'linewidth', 1);
file_box(3)                 = annotation('textbox', [0.345 0.965 0.16 0.03], 'string', '', 'color', 'k', 'fontsize', size_font, 'backgroundcolor', 'w', 'edgecolor', 'k', 'interpreter', 'none', 'linewidth', 1);
status_box(2)               = annotation('textbox', [0.69 0.965 0.30 0.03], 'string', '', 'color', 'k', 'fontsize', size_font, 'backgroundcolor', 'w', 'edgecolor', 'k', 'interpreter', 'none', 'linewidth', 1);

rad_group                   = uibuttongroup('position', [0.84 0.925 0.06 0.03], 'selectionchangefcn', @rad_radio);
uicontrol(fgui(2), 'style', 'text', 'parent', rad_group, 'units', 'normalized', 'position', [0 0.6 0.9 0.3], 'fontsize', size_font)
rad_check(1)                = uicontrol(fgui(2), 'style', 'radio', 'string', 'M', 'units', 'normalized', 'position', [0.01 0.1 0.45 0.8], 'parent', rad_group, 'fontsize', size_font, 'handlevisibility', 'off');
rad_check(2)                = uicontrol(fgui(2), 'style', 'radio', 'string', 'I', 'units', 'normalized', 'position', [0.51 0.1 0.45 0.8], 'parent', rad_group, 'fontsize', size_font, 'handlevisibility', 'off');
set(rad_group, 'selectedobject', rad_check(1))

disp_group                  = uibuttongroup('position', [0.265 0.965 0.075 0.03], 'selectionchangefcn', @disp_radio);
uicontrol(fgui(2), 'style', 'text', 'parent', disp_group, 'units', 'normalized', 'position', [0 0.6 0.9 0.3], 'fontsize', size_font)
disp_check(1)               = uicontrol(fgui(2), 'style', 'radio', 'string', 'elev.', 'units', 'normalized', 'position', [0.01 0.1 0.45 0.8], 'parent', disp_group, 'fontsize', size_font, 'handlevisibility', 'off');
disp_check(2)               = uicontrol(fgui(2), 'style', 'radio', 'string', 'depth', 'units', 'normalized', 'position', [0.5 0.1 0.45 0.8], 'parent', disp_group, 'fontsize', size_font, 'handlevisibility', 'off', 'visible', 'off');
set(disp_group, 'selectedobject', disp_check(1))

% value boxes
decim_edit(2, 1)            = uicontrol(fgui(2), 'style', 'edit', 'string', num2str(decim(1)), 'units', 'normalized', 'position', [0.135 0.925 0.03 0.03], 'fontsize', size_font, 'foregroundcolor', 'k', 'backgroundcolor', 'w', 'callback', @adj_decim3);
decim_edit(2, 2)            = uicontrol(fgui(2), 'style', 'edit', 'string', num2str(decim(2)), 'units', 'normalized', 'position', [0.50 0.925 0.03 0.03], 'fontsize', size_font, 'foregroundcolor', 'k', 'backgroundcolor', 'w', 'callback', @adj_decim4);
% menus
cmap_list(2)                = uicontrol(fgui(2), 'style', 'popupmenu', 'string', cmaps, 'value', 1, 'units', 'normalized', 'position', [0.945 0.925 0.05 0.03], 'callback', @change_cmap2, 'fontsize', size_font);
layer_list(2, 1)            = uicontrol(fgui(2), 'style', 'popupmenu', 'string', 'N/A', 'value', 1, 'units', 'normalized', 'position', [0.21 0.955 0.05 0.04], 'fontsize', size_font, 'foregroundcolor', 'k', 'callback', @pk_select3);
layer_list(2, 2)            = uicontrol(fgui(2), 'style', 'popupmenu', 'string', 'N/A', 'value', 1, 'units', 'normalized', 'position', [0.55 0.955 0.05 0.04], 'fontsize', size_font, 'foregroundcolor', 'k', 'callback', @pk_select4);
intnum_list                 = uicontrol(fgui(2), 'style', 'popupmenu', 'string', 'N/A', 'value', 1, 'units', 'normalized', 'position', [0.10 0.86 0.04 0.05], 'fontsize', size_font, 'foregroundcolor', 'k', 'callback', @change_int);
data_list(1)                = uicontrol(fgui(2), 'style', 'popupmenu', 'string', 'N/A', 'value', 1, 'units', 'normalized', 'position', [0.19 0.86 0.175 0.05], 'fontsize', size_font, 'foregroundcolor', 'k');
data_list(2)                = uicontrol(fgui(2), 'style', 'popupmenu', 'string', 'N/A', 'value', 1, 'units', 'normalized', 'position', [0.68 0.86 0.175 0.05], 'fontsize', size_font, 'foregroundcolor', 'k');

% check boxes
distfix_check(1)            = uicontrol(fgui(2), 'style', 'checkbox', 'units', 'normalized', 'position', [0.50 0.005 0.01 0.02], 'fontsize', size_font, 'value', 0, 'backgroundcolor', get(fgui(2), 'color'));
distfix_check(2)            = uicontrol(fgui(2), 'style', 'checkbox', 'units', 'normalized', 'position', [0.98 0.005 0.01 0.02], 'fontsize', size_font, 'value', 0, 'backgroundcolor', get(fgui(2), 'color'));
zfix_check(2)               = uicontrol(fgui(2), 'style', 'checkbox', 'units', 'normalized', 'position', [0.02 0.88 0.01 0.02], 'fontsize', size_font, 'value', 0, 'backgroundcolor', get(fgui(2), 'color'));
cbfix_check1(2)             = uicontrol(fgui(2), 'style', 'checkbox', 'units', 'normalized', 'position', [0.485 0.88 0.01 0.02], 'fontsize', size_font, 'value', 0, 'backgroundcolor', get(fgui(2), 'color'));
cbfix_check1(3)             = uicontrol(fgui(2), 'style', 'checkbox', 'units', 'normalized', 'position', [0.97 0.88 0.01 0.02], 'fontsize', size_font, 'value', 0, 'backgroundcolor', get(fgui(2), 'color'));
cbfix_check2(2)             = uicontrol(fgui(2), 'style', 'checkbox', 'units', 'normalized', 'position', [0.50 0.88 0.01 0.02], 'callback', @narrow_cb2, 'fontsize', size_font, 'value', 1, 'backgroundcolor', get(fgui(2), 'color'));
cbfix_check2(3)             = uicontrol(fgui(2), 'style', 'checkbox', 'units', 'normalized', 'position', [0.985 0.88 0.01 0.02], 'callback', @narrow_cb3, 'fontsize', size_font, 'value', 1, 'backgroundcolor', get(fgui(2), 'color'));
grid_check(2)               = uicontrol(fgui(2), 'style', 'checkbox', 'units', 'normalized', 'position', [0.39 0.88 0.01 0.02], 'callback', @toggle_grid2, 'fontsize', size_font, 'value', 0, 'backgroundcolor', get(fgui(2), 'color'));
grid_check(3)               = uicontrol(fgui(2), 'style', 'checkbox', 'units', 'normalized', 'position', [0.88 0.88 0.01 0.02], 'callback', @toggle_grid3, 'fontsize', size_font, 'value', 0, 'backgroundcolor', get(fgui(2), 'color'));
pk_check(2, 1)              = uicontrol(fgui(2), 'style', 'checkbox', 'units', 'normalized', 'position', [0.17 0.965 0.01 0.02], 'callback', @show_pk3, 'fontsize', size_font, 'value', 0, 'backgroundcolor', get(fgui(2), 'color'));
pk_check(2, 2)              = uicontrol(fgui(2), 'style', 'checkbox', 'units', 'normalized', 'position', [0.51 0.965 0.01 0.02], 'callback', @show_pk4, 'fontsize', size_font, 'value', 0, 'backgroundcolor', get(fgui(2), 'color'));
data_check(2, 1)            = uicontrol(fgui(2), 'style', 'checkbox', 'units', 'normalized', 'position', [0.09 0.925 0.01 0.02], 'callback', @show_data3, 'fontsize', size_font, 'value', 0, 'backgroundcolor', get(fgui(2), 'color'));
data_check(2, 2)            = uicontrol(fgui(2), 'style', 'checkbox', 'units', 'normalized', 'position', [0.455 0.925 0.01 0.02], 'callback', @show_data4, 'fontsize', size_font, 'value', 0, 'backgroundcolor', get(fgui(2), 'color'));
int_check(2)                = uicontrol(fgui(2), 'style', 'checkbox', 'units', 'normalized', 'position', [0.14 0.88 0.01 0.02], 'callback', @show_int2, 'fontsize', size_font, 'value', 0, 'backgroundcolor', get(fgui(2), 'color'));
int_check(3)                = uicontrol(fgui(2), 'style', 'checkbox', 'units', 'normalized', 'position', [0.625 0.88 0.01 0.02], 'callback', @show_int3, 'fontsize', size_font, 'value', 0, 'backgroundcolor', get(fgui(2), 'color'));
core_check(2)               = uicontrol(fgui(2), 'style', 'checkbox', 'units', 'normalized', 'position', [0.175 0.88 0.01 0.02], 'callback', @show_core2, 'fontsize', size_font, 'value', 0, 'backgroundcolor', get(fgui(2), 'color'));
core_check(3)               = uicontrol(fgui(2), 'style', 'checkbox', 'units', 'normalized', 'position', [0.66 0.88 0.01 0.02], 'callback', @show_core3, 'fontsize', size_font, 'value', 0, 'backgroundcolor', get(fgui(2), 'color'));
nearest_check               = uicontrol(fgui(2), 'style', 'checkbox', 'units', 'normalized', 'position', [0.775 0.925 0.01 0.02], 'fontsize', size_font, 'value', 0, 'backgroundcolor', get(fgui(2), 'color'));
match_check                 = uicontrol(fgui(2), 'style', 'checkbox', 'units', 'normalized', 'position', [0.825 0.925 0.01 0.02], 'fontsize', size_font, 'value', 1, 'backgroundcolor', get(fgui(2), 'color'));

figure(fgui(1))

linkprop(layer_list(:, 1), {'value' 'string'});
linkprop(layer_list(:, 2), {'value' 'string'});
linkaxes(ax(2:3), 'y')

%% Clear plots

    function clear_plots(source, eventdata)
        delete([p_bed(ishandle(p_bed(:, curr_rad)), curr_rad); p_coredepth{curr_rad}(ishandle(p_coredepth{curr_rad}))'; p_corenamedepth{curr_rad}(ishandle(p_corenamedepth{curr_rad}))'; p_data(ishandle(p_data(:, curr_rad)), curr_rad); p_pkdepth{curr_rad}(ishandle(p_pkdepth{curr_rad}))'; ...
                p_surf(ishandle(p_surf(:, curr_rad)), curr_rad)])
        if ishandle(p_beddepth(curr_rad))
            delete(p_beddepth(curr_rad))
        end
        for ii = 1:2
            for jj = 1:3
                delete(p_int1{ii, jj}(ishandle(p_int1{ii, jj})))
            end
            for jj = 1:2
                delete(p_int2{ii, jj}(ishandle(p_int2{ii, jj})))
            end
            delete([p_core{ii, curr_rad}(ishandle(p_core{ii, curr_rad})) p_corename{ii, curr_rad}(ishandle(p_corename{ii, curr_rad})) p_pk{ii, curr_rad}(ishandle(p_pk{ii, curr_rad}))])
        end
        set(file_box(1 + curr_rad), 'string', '')
        if (curr_rad == 1)
            set(file_box(1), 'string', '')
        end
        set([pk_check(:, curr_rad); data_check(:, curr_rad); int_check'], 'value', 0)
        set([layer_list(:, curr_rad); intnum_list; data_list(curr_rad)], 'string', 'N/A', 'value', 1)
        set(disp_check(2), 'visible', 'off')
        axes(ax(curr_ax))
    end

%% Clear data and picks

    function clear_data(source, eventdata)
        [bed_avail(curr_rad), data_done(curr_rad), pk_done(curr_rad), surf_avail(curr_rad)] ...
                            = deal(false);
        [amp_elev{curr_rad}, colors{curr_rad}, depth{curr_rad}, dist_lin{curr_rad}, elev{curr_rad}, elev_bed{curr_rad}, elev_smooth{curr_rad}, elev_surf{curr_rad}, file_pk_short{curr_rad}, ind_decim{curr_rad}, ind_corr{curr_rad}, ind_int_core{curr_rad}, ind_layer{curr_rad}, layer_str{curr_rad}, ...
         pk{curr_rad}, twtt{curr_rad}, x{curr_rad}, y{curr_rad}] ...
                            = deal([]);
        [curr_layer(curr_rad), curr_trans(curr_rad), curr_subtrans(curr_rad), curr_year(curr_rad), dt(curr_rad), num_data(curr_rad), num_decim(curr_rad), num_sample(curr_rad), curr_ind_int, ii, ind_x_pk, ind_y_pk, jj, num_int, tmp1, tmp2, tmp3, tmp4, tmp5] ...
                            = deal(0);
        [p_bed(1, curr_rad), p_bed(2, curr_rad), p_beddepth(curr_rad), p_core{1, curr_rad}, p_core{2, curr_rad}, p_coredepth{curr_rad}, p_corename{1, curr_rad}, p_corename{2, curr_rad}, p_corenamedepth{curr_rad}, p_data(1, curr_rad), p_data(2, curr_rad), p_int1{1, 1}, p_int1{1, 2}, ...
         p_int1{1, 3}, p_int1{2, 1}, p_int1{2, 2}, p_int1{2, 3}, p_int2{1, 1}, p_int2{1, 2}, p_int2{2, 1}, p_int2{2, 2}, p_pk{1, curr_rad}, p_pk{2, curr_rad}, p_pkdepth{curr_rad}, p_surf(1, curr_rad), p_surf(2, curr_rad)]...
                            = deal(NaN);
    end

%% Load intersection data

    function load_int(source, eventdata)
        set(fgui, 'keypressfcn', '', 'windowbuttondownfcn', '')
        [curr_gui, curr_ax] = deal(1);
        if int_done
            set(status_box(1), 'string', 'Transect intersections already loaded.')
            set(fgui(1), 'keypressfcn', @keypress1)
            set(fgui(2), 'keypressfcn', @keypress2, 'windowbuttondownfcn', @mouse_click)
            return
        end
        if isempty(radar_type)
            set(status_box(1), 'string', 'Deep (D) or accumulation (A) radar?...')
            waitforbuttonpress
            switch get(fgui(1), 'currentcharacter')
                case {'d' 'D'}
                    radar_type ...
                            = 'deep';
                case {'a' 'A'}
                    radar_type ...
                            = 'accum';
                otherwise
                    set(fgui(1), 'keypressfcn', @keypress1)
                    set(status_box(1), 'string', 'Choice unclear. Try again.')
                    set(fgui(1), 'keypressfcn', @keypress1)
                    set(fgui(2), 'keypressfcn', @keypress2, 'windowbuttondownfcn', @mouse_click)
                    return
            end
        end
        if ispc
            if exist('\\melt\icebridge\data\mat\', 'dir')
                path_ref    = '\\melt\icebridge\data\mat\';
            end
        elseif exist('/Volumes/icebridge/data/mat/', 'dir')
            path_ref        = '/Volumes/icebridge/data/mat/';
        end
        switch radar_type
            case 'deep'
                tmp1        = 'merge_xy_int.mat';
            case 'accum'
                tmp1        = 'merge_xy_int_accum.mat';
        end
        if (~isempty(path_ref) && exist([path_ref tmp1], 'file'))
            file_ref       = tmp1;
        else
            % Dialog box to choose picks file to load
            if ~isempty(path_ref)
                [file_ref, path_ref] = uigetfile('*.mat', ['Load intersection data (' tmp1 '):'], path_ref);
            elseif ~isempty(path_pk{curr_rad})
                [file_ref, path_ref] = uigetfile('*.mat', ['Load intersection data (' tmp1 '):'], path_pk{curr_rad});
            elseif ~isempty(path_data{curr_rad})
                [file_ref, path_ref] = uigetfile('*.mat', ['Load intersection data (' tmp1 '):'], path_data{curr_rad});
            else
                [file_ref, path_ref] = uigetfile('*.mat', ['Load intersection data (' tmp1 '):']);
            end
            if isnumeric(file_ref)
                [file_ref, path_ref] = deal('');
            end
        end
        if ~isempty(file_ref)
            set(status_box(1), 'string', 'Loading transect intersection data...')
            pause(0.1)
            tmp1            = load([path_ref file_ref]);
            try
                [name_trans, name_year, int_all, num_year, num_trans] ...
                            = deal(tmp1.name_trans, tmp1.name_year, tmp1.int_all, tmp1.num_year, tmp1.num_trans);
            catch
               set(status_box(1), 'string', 'Chosen file does not contain expected intersection data.')
               return
            end
            int_done        = true;
            set(status_box(1), 'string', 'Intersection data loaded.')
        else
            set(status_box(1), 'string', 'No intersection data loaded.')
        end
        set(fgui(1), 'keypressfcn', @keypress1)
        set(fgui(2), 'keypressfcn', @keypress2, 'windowbuttondownfcn', @mouse_click)
    end

%% Load core intersection data

    function load_core(source, eventdata)
        set(fgui, 'keypressfcn', '', 'windowbuttondownfcn', '')
        [curr_gui, curr_ax] = deal(1);
        if core_done
            set(status_box(1), 'string', 'Core intersections already loaded.')
            set(fgui(1), 'keypressfcn', @keypress1)
            set(fgui(2), 'keypressfcn', @keypress2, 'windowbuttondownfcn', @mouse_click)
            return
        end
        if ~int_done
            set(status_box(1), 'string', 'Load transect intersections first.')
            set(fgui(1), 'keypressfcn', @keypress1)
            set(fgui(2), 'keypressfcn', @keypress2, 'windowbuttondownfcn', @mouse_click)
            return
        end
        switch radar_type
            case 'deep'
                tmp1        = 'core_int.mat';
            case 'accum'
                tmp1        = 'core_int_accum.mat';
        end
        if (~isempty(path_ref) && exist([path_ref tmp1], 'file'))
            [file_core, path_core] ...
                            = deal(tmp1, path_ref);
        elseif ~isempty(path_core)
            [file_core, path_core] = uigetfile('*.mat', ['Load core intersections (' tmp1 '):'], path_core);
        elseif ~isempty(path_ref)
            [file_core, path_core] = uigetfile('*.mat', ['Load core intersections (' tmp1 '):'], path_ref);
        elseif ~isempty(path_pk)
            [file_core, path_core] = uigetfile('*.mat', ['Load core intersections (' tmp1 '):'], path_pk);
        elseif ~isempty(path_data)
            [file_core, path_core] = uigetfile('*.mat', ['Load core intersections (' tmp1 '):'], path_data);
        else
            [file_core, path_core] = uigetfile('*.mat', ['Load core intersections (' tmp1 '):']);
        end
        
        if isnumeric(file_core)
            [file_core, path_core] = deal('');
        end
        
        if ~isempty(file_core)
            
            set(status_box(1), 'string', 'Loading core intersections...')
            pause(0.1)
            
            % load core intersection file
            tmp1        = load([path_core file_core]);
            try
                [int_core, name_core, rad_threshold, x_core, y_core] ...
                        = deal(tmp1.int_core, tmp1.name_core, tmp1.rad_threshold, tmp1.x_core, tmp1.y_core);
            catch % give up, force restart
                set(status_box(1), 'string', [file_core ' does not contain the expected variables. Try again.'])
                set(fgui(1), 'keypressfcn', @keypress1)
                set(fgui(2), 'keypressfcn', @keypress2, 'windowbuttondownfcn', @mouse_click)
                return
            end
            
            core_done   = true;
            set(status_box(1), 'string', 'Core intersection data loaded.')
        else
            set(status_box(1), 'string', 'No core intersections loaded.')
        end
        set(fgui(1), 'keypressfcn', @keypress1)
        set(fgui(2), 'keypressfcn', @keypress2, 'windowbuttondownfcn', @mouse_click)
    end

%% Load core breakout

    function load_core_breakout(source, eventdata)
        
        for ii = 1:2
            for jj = 1:2
                delete([p_core{jj, ii}(ishandle(p_core{jj, ii})) p_corename{jj, ii}(ishandle(p_corename{jj, ii}))])
            end
            delete([p_coredepth{ii}(ishandle(p_coredepth{ii})) p_corenamedepth{ii}(ishandle(p_corenamedepth{ii}))])
        end
        
        for ii = 1:2
            
            if isempty(int_core{curr_year(ii)}{curr_trans(ii)})
                continue
            end
            
            ind_int_core{ii}= [];
            for jj = 1:size(int_core{curr_year(ii)}{curr_trans(ii)}, 1)
                try %#ok<TRYNC>
                    [tmp1, tmp2] ...
                            = min(sqrt(((pk{ii}.x - int_core{curr_year(ii)}{curr_trans(ii)}(jj, 4)) .^ 2) + ((pk{ii}.y - int_core{curr_year(ii)}{curr_trans(ii)}(jj, 5)) .^ 2)));
                    if (tmp1 < rad_threshold)
                        ind_int_core{ii} ...
                            = [ind_int_core{ii} tmp2];
                    end
                end
            end
            
            if isempty(ind_int_core{ii})
                continue
            else
                num_int_core(ii) ...
                            = length(ind_int_core{ii});
            end
            
            for jj = 1:2
                [p_core{jj, ii}, p_corename{jj, ii}] ...
                            = deal(NaN(1, num_int_core(ii)));
                for kk = 1:num_int_core(ii)
                    if (jj == 1)
                        axes(ax(1))
                        p_core{jj, ii}(kk) ...
                            = plot3(repmat(x_core(int_core{curr_year(ii)}{curr_trans(ii)}(kk, 3)), 1, 2), repmat(y_core(int_core{curr_year(ii)}{curr_trans(ii)}(kk, 3)), 1, 2), [elev_min_ref elev_max_ref], 'color', 'k', 'linewidth', 2, 'visible', 'off');
                        p_corename{jj, ii}(kk) ...
                            = text(double(x_core(int_core{curr_year(ii)}{curr_trans(ii)}(kk, 3)) + 1), double(y_core(int_core{curr_year(ii)}{curr_trans(ii)}(kk, 3)) + 1), ...
                                   double(elev_max_ref - 50), name_core{int_core{curr_year(ii)}{curr_trans(ii)}(kk, 3)}, 'color', 'k', 'fontsize', size_font, 'visible', 'off');
                    else
                        axes(ax(ii + 1))
                        p_core{jj, ii}(kk) ...
                            = plot(repmat(double(pk{ii}.dist_lin(ind_int_core{ii}(kk))), 1, 2), [elev_min_ref elev_max_ref], 'color', [0.5 0.5 0.5], 'linewidth', 2, 'visible', 'off');
                        p_corename{jj, ii}(kk) ...
                            = text(double(pk{ii}.dist_lin(ind_int_core{ii}(kk)) + 1), double(elev_max_ref - 50), name_core{int_core{curr_year(ii)}{curr_trans(ii)}(kk, 3)}, 'color', [0.5 0.5 0.5], 'fontsize', size_font, 'visible', 'off');
                    end
                end
            end
            [p_coredepth{ii}, p_corenamedepth{ii}] ...
                            = deal(NaN(1, num_int_core(ii)));
            for jj = 1:num_int_core(ii)
                p_coredepth{ii}(jj) ...
                            = plot(repmat(double(pk{ii}.dist_lin(ind_int_core{ii}(jj))), 1, 2), [depth_min_ref depth_max_ref], 'color', [0.5 0.5 0.5], 'linewidth', 2, 'visible', 'off');
                p_corenamedepth{ii}(jj) ...
                            = text(double(pk{ii}.dist_lin(ind_int_core{ii}(jj)) + 1), double(depth_min_ref + 50), name_core{int_core{curr_year(ii)}{curr_trans(ii)}(jj, 3)}, 'color', [0.5 0.5 0.5], 'fontsize', size_font, 'visible', 'off');
            end
        end
        
        set(status_box, 'string', ['Core intersections loaded. ' num2str(num_int_core(1)) '/' num2str(num_int_core(2)) ' for these transects within ' num2str(rad_threshold) ' km.'])
        core_done           = true;
        set(core_check, 'value', 1)
        show_core3
        show_core2
        show_core1
    end

%% Load matching layer list

    function load_match(source, eventdata)
        
        set(fgui, 'keypressfcn', '', 'windowbuttondownfcn', '')
        
        [curr_gui, curr_ax] = deal(1);
                
        if (~int_done || ~core_done)
            set(status_box(1), 'string', 'Load transect and core intersections first.')
            set(fgui(1), 'keypressfcn', @keypress1)
            set(fgui(2), 'keypressfcn', @keypress2, 'windowbuttondownfcn', @mouse_click)
            return
        end
        
        if match_done
            set(status_box(1), 'string', 'Matching layer list already loaded.')
            set(fgui(1), 'keypressfcn', @keypress1)
            set(fgui(2), 'keypressfcn', @keypress2, 'windowbuttondownfcn', @mouse_click)
            return
        end
        
        switch radar_type
            case 'deep'
                tmp1        = 'ind_layer_match.mat';
            case 'accum'
                tmp1        = 'ind_layer_match_accum.mat';
        end
        
        if (~isempty(path_ref) && exist([path_ref tmp1], 'file'))
            [file_match, path_match] ...
                            = deal(tmp1, path_ref);
        elseif ~isempty(path_core)
            [file_match, path_match] = uigetfile('*.mat', ['Load matching layer list (' tmp1 '):'], path_core);
        elseif ~isempty(path_ref)
            [file_match, path_match] = uigetfile('*.mat', ['Load matching layer list (' tmp1 '):'], path_ref);
        elseif ~isempty(path_pk)
            [file_match, path_match] = uigetfile('*.mat', ['Load matching layer list (' tmp1 '):'], path_pk);
        elseif ~isempty(path_data)
            [file_match, path_match] = uigetfile('*.mat', ['Load matching layer list (' tmp1 '):'], path_data);
        else
            [file_match, path_match] = uigetfile('*.mat', ['Load matching layer list (' tmp1 '):']);
        end
        
        if isnumeric(file_match)
            [file_match, path_match] ...
                            = deal('');
            set(status_box(1), 'string', 'No matching layer list found.')
            set(fgui(1), 'keypressfcn', @keypress1)
            set(fgui(2), 'keypressfcn', @keypress2, 'windowbuttondownfcn', @mouse_click)
            return
        else
            try
                tmp1        = load([path_match file_match]);
                ind_layer_match ...
                            = tmp1.ind_layer_match;
                match_done  = true;
                set(match_check, 'value', 1)
                set(status_box(1), 'string', 'Matching layer list loaded.')
            catch
                set(status_box(1), 'string', 'Selected matching layer list does not contain the expected variable. Re-locate.')
                match_done  = false;
                set(fgui(1), 'keypressfcn', @keypress1)
                set(fgui(2), 'keypressfcn', @keypress2, 'windowbuttondownfcn', @mouse_click)
                return
            end
        end
        
        set(fgui(1), 'keypressfcn', @keypress1)
        set(fgui(2), 'keypressfcn', @keypress2, 'windowbuttondownfcn', @mouse_click)
    end

%% Load picks for this transect

    function load_pk1(source, eventdata)
        [curr_gui, curr_ax, curr_rad, curr_rad_alt] ...
                            = deal(1, 1, 1, 2);
        tmp1                = 'trans';
        set(fgui, 'keypressfcn', '', 'windowbuttondownfcn', '')
        load_pk
        set(fgui(1), 'keypressfcn', @keypress1)
        set(fgui(2), 'keypressfcn', @keypress2, 'windowbuttondownfcn', @mouse_click)
    end

    function load_pk2(source, eventdata)
        [curr_gui, curr_ax, curr_rad, curr_rad_alt] ...
                            = deal(1, 1, 2, 1);
        tmp1                = 'trans';
        tmp2                = get(int_list, 'string');
        file_pk{2}          = [tmp2{get(int_list, 'value')} '_pk_merge.mat'];
        set(fgui, 'keypressfcn', '', 'windowbuttondownfcn', '')
        load_pk
        set(fgui(1), 'keypressfcn', @keypress1)
        set(fgui(2), 'keypressfcn', @keypress2, 'windowbuttondownfcn', @mouse_click)
    end

    function load_subtrans(source, eventdata)
        if ~strcmp(get(subtrans_list, 'string'), 'N/A')
            [curr_gui, curr_ax, curr_rad, curr_rad_alt] ...
                            = deal(1, 1, 1, 2);
            tmp1            = get(subtrans_list, 'string');
            file_pk{1}      = [file_pk{1}(1:11) tmp1{get(subtrans_list, 'value')} file_pk{1}(13:end)];
            tmp1            = 'subtrans';
            set(fgui, 'keypressfcn', '', 'windowbuttondownfcn', '')
            load_pk
            set(fgui(1), 'keypressfcn', @keypress1)
            set(fgui(2), 'keypressfcn', @keypress2, 'windowbuttondownfcn', @mouse_click)
        end
    end

    function load_pk(source, eventdata)
        
        set(rad_group, 'selectedobject', rad_check(curr_rad))
        
        if ~int_done
            set(status_box(1), 'string', 'Load transect intersection data before loading master picks.')
            return
        end
        if ~core_done
            set(status_box(1), 'string', 'Load core intersection data before loading picks.')
            return
        end
        if ~match_done
            set(status_box(1), 'string', 'Load matching layer list before loading picks.')
            return
        end        
        if ((curr_rad == 2) && ~pk_done(1))
            set(status_box(1), 'string', 'Load master transect before intersecting transect.')
            return
        end
        
        if strcmp(tmp1, 'trans')
            
            if (curr_rad == 2)
                if ispc
                    if exist([path_core '..\' name_year{int_year(get(int_list, 'value'))} '\merge\' file_pk{2}], 'file')
                        clear_plots
                        clear_data
                        path_pk{2} ...
                            = [path_core '..\' name_year{int_year(get(int_list, 'value'))} '\merge\'];
                        tmp1= 'skip';
                    elseif exist([path_core '..\' name_year{int_year(get(int_list, 'value'))} '\merge\' file_pk{2}(1:11) 'a' file_pk{2}(12:end)], 'file')
                        clear_plots
                        clear_data
                        [file_pk{2}, path_pk{2}] ...
                            = deal([file_pk{2}(1:11) 'a' file_pk{2}(12:end)], [path_core '..\' name_year{int_year(get(int_list, 'value'))} '\merge\']);
                        tmp1= 'skip';
                    end
                else
                    if exist([path_core '../' name_year{int_year(get(int_list, 'value'))} '/merge/' file_pk{2}], 'file')
                        clear_plots
                        clear_data
                        path_pk{2} ...
                            = [path_core '../' name_year{int_year(get(int_list, 'value'))} '/merge/'];
                        tmp1= 'skip';
                    elseif exist([path_core '../' name_year{int_year(get(int_list, 'value'))} '/merge/' file_pk{2}(1:11) 'a' file_pk{2}(12:end)], 'file')
                        clear_plots
                        clear_data
                        [file_pk{2}, path_pk{2}] ...
                            = deal([file_pk{2}(1:11) 'a' file_pk{2}(12:end)], [path_core '../' name_year{int_year(get(int_list, 'value'))} '/merge/']);
                        tmp1= 'skip';
                    end
                end
            end
            
            if ~strcmp(tmp1, 'skip')
                % Dialog box to choose picks file to load
                if ~isempty(path_pk{curr_rad})
                    [file_pk{curr_rad}, path_pk{curr_rad}] ...
                            = uigetfile('*.mat', 'Load merged picks:', path_pk{curr_rad});
                elseif ~isempty(path_pk{curr_rad_alt})
                    [file_pk{curr_rad}, path_pk{curr_rad}] ...
                            = uigetfile('*.mat', 'Load merged picks:', path_pk{curr_rad_alt});
                elseif ~isempty(path_data{curr_rad})
                    [file_pk{curr_rad}, path_pk{curr_rad}] ...
                            = uigetfile('*.mat', 'Load merged picks:', path_data{curr_rad});
                elseif ~isempty(path_data{curr_rad_alt})
                    [file_pk{curr_rad}, path_pk{curr_rad}] ...
                            = uigetfile('*.mat', 'Load merged picks:', path_data{curr_rad_alt});
                elseif ~isempty(path_ref)
                    [file_pk{curr_rad}, path_pk{curr_rad}] ...
                            = uigetfile('*.mat', 'Load merged picks:', path_ref);
                else
                    [file_pk{curr_rad}, path_pk{curr_rad}] ...
                            = uigetfile('*.mat', 'Load merged picks:');
                end
                if isnumeric(file_pk{curr_rad})
                    [file_pk{curr_rad}, path_pk{curr_rad}] ...
                            = deal('');
                end
                
                if isempty(file_pk{curr_rad})
                    set(status_box(1), 'string', 'No picks loaded.')
                    return
                end
                
                % get rid of radargrams if present
                clear_plots
                clear_data
                set(subtrans_list, 'string', 'N/A', 'value', 1)
                if ((curr_rad == 1) && pk_done(2))
                    curr_rad= 2;
                    clear_plots
                    clear_data
                    set(int_list, 'string', 'N/A', 'value', 1)
                    set(int_list, 'string', 'N/A', 'value', 1)
                    curr_rad= 1;
                end
            end
            
            if (curr_rad == 1)
                set(subtrans_list, 'value', 1, 'string', 'N/A')
                % check for sub-transects, populate list if present
                if (length(dir([path_pk{curr_rad} file_pk{curr_rad}(1:11) '*.mat'])) > 1)
                    tmp1    = dir([path_pk{curr_rad} file_pk{curr_rad}(1:11) '*.mat']);
                    tmp2    = cell(length(tmp1), 1);
                    for ii = 1:length(tmp1)
                        tmp2{ii} = tmp1(ii).name(12);
                        if (tmp2{ii} == file_pk{1}(12))
                            tmp3 = ii;
                        end
                    end
                    set(subtrans_list, 'string', tmp2, 'value', tmp3)
                    set(status_box(1), 'string', ['Multiple sub-transects (' num2str(length(tmp1)) ' present for this transect.'])
                end
            end
            
            if ((curr_rad == 1) && pk_done(1))
                tmp1        = get(int_list, 'string');
                if ~strcmp(tmp1{get(int_list, 'value')}, file_pk{1}(1:11))
                    set(status_box(1), 'string', 'Chosen picks filename does not match selected transect. Continue loading? Y: yes; otherwise: no...')
                    waitforbuttonpress
                    if ~strcmpi(get(fgui(1), 'currentcharacter'), 'Y')
                        set(status_box(1), 'string', 'Loading of picks file cancelled.')
                        return
                    end
                end
                % check for sub-transects, populate list if present
                if (length(dir([path_pk{1} tmp1{get(int_list, 'value')} '*.mat'])) > 1)
                    tmp1   = dir([path_pk{1} tmp1{get(int_list, 'value')} '*.mat']);
                    tmp2   = cell(length(tmp1), 1);
                    for ii = 1:length(tmp1)
                        tmp2{ii} ...
                            = tmp1(ii).name(12);
                    end
                    set(status_box(1), 'string', ['Multiple sub-transects (' num2str(length(tmp1)) ' present for this transect.'])
                end
            end
            
        else
            % get rid of radargrams if present
            clear_plots
            clear_data
            if ((curr_rad == 1) && pk_done(2))
                curr_rad    = 2;
                clear_plots
                clear_data
                set(int_list, 'string', 'N/A', 'value', 1)
                curr_rad    = 1;
            end
        end
        
        axes(ax(curr_ax))
        
        pause(0.1)
        
        % load picks file
        set(status_box(1), 'string', ['Loading ' file_pk{curr_rad}(1:(end - 4)) '...'])
        pause(0.1)
        try
            tmp1            = load([path_pk{curr_rad} file_pk{curr_rad}], 'pk');
            pk{curr_rad}    = tmp1.pk;
            tmp1            = 0;
            if ~isfield(pk{curr_rad}, 'merge_flag')
                set(status_box(1), 'string', 'Load merged picks files only.')
                return
            end
                [dist_lin{curr_rad}, elev_bed{curr_rad}, elev_smooth{curr_rad}, elev_surf{curr_rad}, x{curr_rad}, y{curr_rad}] ...
                            = deal(pk{curr_rad}.dist_lin, pk{curr_rad}.elev_bed_gimp, pk{curr_rad}.elev_smooth_gimp, pk{curr_rad}.elev_surf_gimp, pk{curr_rad}.x, pk{curr_rad}.y);
        catch % give up, force restart
            set(status_box(1), 'string', [file_pk{curr_rad} ' does not contain a pk structure. Try again.'])
            return
        end
                
        % extract date and best name from pk files
        [tmp1, tmp2]        = strtok(file_pk{curr_rad}, '_');
        file_pk_short{curr_rad} ...
                            = [tmp1 tmp2(1:3)];
        if ~strcmp(tmp2(4), '_')
            file_pk_short{curr_rad} ...
                            = [file_pk_short{curr_rad} tmp2(4)];
        end
        if (curr_rad == 1)
            set(file_box(1), 'string', file_pk_short{curr_rad}(1:11))
            set(file_box(2), 'string', file_pk_short{curr_rad})
        else
            set(file_box(3), 'string', file_pk_short{curr_rad})
        end
        
        % decimated vectors for display
        if (decim(curr_rad) > 1)
            ind_decim{curr_rad} ...
                            = (1 + ceil(decim(curr_rad) / 2)):decim(curr_rad):(pk{curr_rad}.num_trace_tot - ceil(decim(curr_rad) / 2));
        else
            ind_decim{curr_rad} ...
                            = 1:pk{curr_rad}.num_trace_tot;
        end
        num_decim(curr_rad) = length(ind_decim{curr_rad});
        
        % check to see if surface and bed picks are available
        if isfield(pk{curr_rad}, 'elev_surf')
            if any(~isnan(elev_surf{curr_rad}(ind_decim{curr_rad})))
                surf_avail(curr_rad) ...
                            = true;
            end
        end
        if isfield(pk{curr_rad}, 'elev_bed')
            if any(~isnan(elev_bed{curr_rad}(ind_decim{curr_rad})))
                bed_avail(curr_rad) ...
                            = true;
            end
        end
        
        if ~surf_avail(curr_rad)
            set(status_box(1), 'string', 'Surface pick not included in pick file, which will create problems.')
        end
        
        % determine current year/transect
        tmp1                = file_pk_short{curr_rad};
        tmp2                = 'fail';
        if (isnan(str2double(tmp1(end))) || ~isreal(str2double(tmp1(end))))
            tmp1            = tmp1(1:(end - 1));
        end
        for ii = 1:num_year
            for jj = 1:num_trans(ii)
                if strcmp(tmp1, name_trans{ii}{jj})
                    break
                end
            end
            if strcmp(tmp1, name_trans{ii}{jj})
                tmp2        = 'success';
                break
            end
        end
        
        if strcmp(tmp2, 'fail')
            set(status_box(1), 'string', 'Transect not identified. Try again.')
            clear_data
            return
        end
        
        % fix for 2011 P3/TO ambiguity
        if (strcmp(radar_type, 'deep') && (ii == 17))
            set(status_box(1), 'string', '2011 TO (press T)?')
            waitforbuttonpress
            if strcmpi(get(fgui(1), 'currentcharacter'), 'T')
                tmp2        = 'fail';
                ii          = 18;
                for jj = 1:num_trans(ii)
                    if strcmp(tmp1, name_trans{ii}{jj})
                        tmp2= 'success';
                        break
                    end
                end
                if strcmp(tmp2, 'fail')
                    set(status_box(1), 'string', 'Transect incorrectly identified as 2011 TO. Try again.')
                    clear_data
                    return
                end
            end
        end
        
        switch curr_rad
            case 1
                curr_year(curr_rad) ...
                            = ii;
            case 2
                curr_year(curr_rad) ...
                            = int_year(get(int_list, 'value'));
        end
        curr_trans(curr_rad)= jj;
        for ii = 1:length(tmp1)
            if strcmp(file_pk{curr_rad}(12), letters(ii))
                curr_subtrans(curr_rad) ...
                            = ii;
                break
            end
        end
        
        % list matches
        tmp1                = find(ismember(ind_layer_match(:, 1:3), [curr_year(curr_rad) curr_trans(curr_rad) curr_subtrans(curr_rad)], 'rows'));
        tmp2                = find(ismember(ind_layer_match(:, 5:7), [curr_year(curr_rad) curr_trans(curr_rad) curr_subtrans(curr_rad)], 'rows'));
        if (~isempty(tmp1) || ~isempty(tmp2))
            ind_layer{curr_rad} ...
                            = unique([ind_layer_match(tmp1, 4:8); ind_layer_match(tmp2, [8 1:4])], 'rows');
        else
            ind_layer{curr_rad} ...
                            = NaN(0, 5);
        end
        
        % find intersections for primary transect
        switch curr_rad
            
            case 1 % master
                
                tmp1        = find(ismember(int_all(:, 1:3), [curr_year(1) curr_trans(1) curr_subtrans(1)], 'rows'));
                tmp2        = find(ismember(int_all(:, 6:8), [curr_year(1) curr_trans(1) curr_subtrans(1)], 'rows'));
                tmp3        = cell((length(tmp1) + length(tmp2)), 1);
                if ~isempty(tmp1)
                    for ii = 1:length(tmp1)
                        if ~int_all(tmp1(ii), 8)
                            tmp3{ii} ...
                            = [name_trans{int_all(tmp1(ii), 6)}{int_all(tmp1(ii), 7)}];
                        else
                            tmp3{ii} ...
                            = [name_trans{int_all(tmp1(ii), 6)}{int_all(tmp1(ii), 7)} letters(int_all(tmp1(ii), 8))];
                        end
                    end
                end
                if ~isempty(tmp2)
                    for ii = 1:length(tmp2)
                        if ~int_all(tmp2(ii), 3)
                            tmp3{ii + length(tmp1)} ...
                            = [name_trans{int_all(tmp2(ii), 1)}{int_all(tmp2(ii), 2)}];
                        else
                            tmp3{ii + length(tmp1)} ...
                            = [name_trans{int_all(tmp2(ii), 1)}{int_all(tmp2(ii), 2)} letters(int_all(tmp2(ii), 3))];
                        end
                    end
                end
                [tmp3, tmp4]= unique(tmp3);
                int_year    = [int_all(tmp1, 6); int_all(tmp2, 1)];
                int_year    = int_year(tmp4);
                set(int_list, 'string', tmp3, 'value', 1)
                
            case 2 % figure out intersections
                
                tmp1        = find(ismember(int_all(:, [1:3 6:8]), [curr_year(1) curr_trans(1) curr_subtrans(1) curr_year(2) curr_trans(2) curr_subtrans(2)], 'rows'));
                tmp2        = find(ismember(int_all(:, [6:8 1:3]), [curr_year(1) curr_trans(1) curr_subtrans(1) curr_year(2) curr_trans(2) curr_subtrans(2)], 'rows'));
                curr_ind_int= [int_all(tmp1, 4) int_all(tmp1, 9); int_all(tmp2, 9) int_all(tmp2, 4)];
                num_int     = size(curr_ind_int, 1);
                set(intnum_list, 'string', num2cell(1:num_int), 'value', 1)
        end
        
        set(data_list(curr_rad), 'string', pk{curr_rad}.file_block, 'value', 1)
        axes(ax(curr_ax))
        
        % display merged picks
        colors{curr_rad}    = repmat(colors_def, ceil(pk{curr_rad}.num_layer / size(colors_def, 1)), 1); % extend predefined color pattern
        colors{curr_rad}    = colors{curr_rad}(1:pk{curr_rad}.num_layer, :);
        [p_pk{1, curr_rad}, p_pk{2, curr_rad}, p_pkdepth{curr_rad}] ...
                            = deal(NaN(1, pk{curr_rad}.num_layer));
        layer_str{curr_rad} = num2cell(1:pk{curr_rad}.num_layer);
        for ii = 1:pk{curr_rad}.num_layer %#ok<*FXUP>
            if all(isnan(elev_smooth{curr_rad}(ii, ind_decim{curr_rad})))
                p_pk{1, curr_rad}(ii) ...
                            = plot3(0, 0, 0, 'w.', 'markersize', 1, 'visible', 'off');
                layer_str{curr_rad}{ii} ...
                            = [num2str(ii) ' H'];
            else
                p_pk{1, curr_rad}(ii) ...
                            = plot3(x{curr_rad}(ind_decim{curr_rad}(~isnan(elev_smooth{curr_rad}(ii, ind_decim{curr_rad})))), y{curr_rad}(ind_decim{curr_rad}(~isnan(elev_smooth{curr_rad}(ii, ind_decim{curr_rad})))), ...
                                    elev_smooth{curr_rad}(ii, ind_decim{curr_rad}(~isnan(elev_smooth{curr_rad}(ii, ind_decim{curr_rad})))), '.', 'color', colors{curr_rad}(ii, :), 'markersize', 12, 'visible', 'off');
            end
        end
        
        curr_layer(curr_rad)= 1;
        set(layer_list(:, curr_rad), 'string', layer_str{curr_rad}, 'value', 1)
        axes(ax(curr_ax))
        
        % display surface and bed
        if surf_avail(curr_rad)
            p_surf(curr_gui, curr_rad) ...
                            = plot3(x{curr_rad}(ind_decim{curr_rad}(~isnan(elev_surf{curr_rad}(ind_decim{curr_rad})))), y{curr_rad}(ind_decim{curr_rad}(~isnan(elev_surf{curr_rad}(ind_decim{curr_rad})))), ...
                                    elev_surf{curr_rad}(ind_decim{curr_rad}(~isnan(elev_surf{curr_rad}(ind_decim{curr_rad})))), 'm.', 'markersize', 12, 'visible', 'off');
        end
        if bed_avail(curr_rad)
            p_bed(curr_gui, curr_rad) ...
                            = plot3(x{curr_rad}(ind_decim{curr_rad}(~isnan(elev_bed{curr_rad}(ind_decim{curr_rad})))), y{curr_rad}(ind_decim{curr_rad}(~isnan(elev_bed{curr_rad}(ind_decim{curr_rad})))), ...
                                    elev_bed{curr_rad}(ind_decim{curr_rad}(~isnan(elev_bed{curr_rad}(ind_decim{curr_rad})))), 'm.', 'markersize', 12, 'visible', 'off');
        end
        
        % display picks, surface and bed in 2D GUI
        axes(ax(curr_ax + curr_rad))
        for ii = 1:pk{curr_rad}.num_layer
            if all(isnan(elev_smooth{curr_rad}(ii, ind_decim{curr_rad})))
                [p_pk{2, curr_rad}(ii), p_pkdepth{curr_rad}(ii)] ...
                            = deal(plot(0, 0, 'w.', 'markersize', 1, 'visible', 'off'));
            else
                p_pk{2, curr_rad}(ii) ...
                            = plot(dist_lin{curr_rad}(ind_decim{curr_rad}(~isnan(elev_smooth{curr_rad}(ii, ind_decim{curr_rad})))), elev_smooth{curr_rad}(ii, ind_decim{curr_rad}(~isnan(elev_smooth{curr_rad}(ii, ind_decim{curr_rad})))), ...
                                   '.', 'color', colors{curr_rad}(ii, :), 'markersize', 12, 'visible', 'off');
                p_pkdepth{curr_rad}(ii) ...
                            = plot(dist_lin{curr_rad}(ind_decim{curr_rad}(~isnan(elev_smooth{curr_rad}(ii, ind_decim{curr_rad})))), pk{curr_rad}.depth_smooth(ii, ind_decim{curr_rad}(~isnan(pk{curr_rad}.depth_smooth(ii, ind_decim{curr_rad})))), ...
                                   '.', 'color', colors{curr_rad}(ii, :), 'markersize', 12, 'visible', 'off');
            end
        end
        if surf_avail(curr_rad)
            p_surf(2, curr_rad) ...
                            = plot(dist_lin{curr_rad}(ind_decim{curr_rad}(~isnan(elev_surf{curr_rad}(ind_decim{curr_rad})))), elev_surf{curr_rad}(ind_decim{curr_rad}(~isnan(elev_surf{curr_rad}(ind_decim{curr_rad})))), 'm--', 'linewidth', 2, 'visible', 'off');
            if any(isnan(elev_surf{curr_rad}(ind_decim{curr_rad}(~isnan(elev_surf{curr_rad}(ind_decim{curr_rad}))))))
                set(p_surf(2, curr_rad), 'marker', '.', 'linestyle', 'none', 'markersize', 12)
            end
        end
        if bed_avail(curr_rad)
            p_bed(2, curr_rad) ...
                            = plot(dist_lin{curr_rad}(ind_decim{curr_rad}(~isnan(elev_bed{curr_rad}(ind_decim{curr_rad})))), elev_bed{curr_rad}(ind_decim{curr_rad}(~isnan(elev_bed{curr_rad}(ind_decim{curr_rad})))), 'm--', 'linewidth', 2, 'visible', 'off');
            if any(isnan(elev_bed{curr_rad}(ind_decim{curr_rad}(~isnan(elev_bed{curr_rad}(ind_decim{curr_rad}))))))
                set(p_bed(2, curr_rad), 'marker', '.', 'linestyle', 'none', 'markersize', 12)
            end
            if surf_avail(curr_rad)
                tmp1        = find(~isnan(elev_bed{curr_rad}(ind_decim{curr_rad})) & ~isnan(elev_surf{curr_rad}(ind_decim{curr_rad})));
                p_beddepth(curr_rad) ...
                            = plot(dist_lin{curr_rad}(ind_decim{curr_rad}(tmp1)), (elev_bed{curr_rad}(ind_decim{curr_rad}(tmp1)) - elev_surf{curr_rad}(ind_decim{curr_rad}(tmp1))), 'm--', 'linewidth', 2, 'visible', 'off');
                if (length(tmp1) < length(ind_decim{curr_rad}))
                    set(p_beddepth(curr_rad), 'marker', '.', 'linestyle', 'none', 'markersize', 12)
                end
            end
        end
        axes(ax(curr_ax))
        
        % get new min/max limits for 3D display
        [dist_min_ref(curr_rad), dist_max_ref(curr_rad), dist_min(curr_rad), dist_max(curr_rad)] ...
                            = deal(min(dist_lin{curr_rad}), max(dist_lin{curr_rad}), min(dist_lin{curr_rad}), max(dist_lin{curr_rad}));
        
        if (curr_rad == 2)
            [tmp1, tmp2, tmp3, tmp4, tmp5] ...
                            = deal([x{1}(~isinf(x{1})) x{2}(~isinf(x{2}))], [y{1}(~isinf(y{1})) y{2}(~isinf(y{2}))], ...
                                   [elev_surf{1}(~isinf(elev_surf{1})) elev_surf{2}(~isinf(elev_surf{2}))], [elev_bed{1}(~isinf(elev_bed{1})) elev_bed{2}(~isinf(elev_bed{2}))], [elev_smooth{1}(:); elev_smooth{2}(:)]);
            tmp5            = tmp5(~isinf(tmp5));
            [x_min_ref, x_max_ref, x_min, x_max] ...
                            = deal(min(tmp1, [], 'omitnan'), max(tmp1, [], 'omitnan'), min(tmp1, [], 'omitnan'), max(tmp1, [], 'omitnan'));
            [y_min_ref, y_max_ref, y_min, y_max] ...
                            = deal(min(tmp2, [], 'omitnan'), max(tmp2, [], 'omitnan'), min(tmp2, [], 'omitnan'), max(tmp2, [], 'omitnan'));
            if all(surf_avail)
                [elev_max_ref, elev_max(1:2)] ...
                            = deal(max(tmp3, [], 'omitnan'));
            else
                [elev_max_ref, elev_max(1:2)] ...
                            = deal(max(tmp5, [], 'omitnan') + 200);
            end
            if all(bed_avail)
                [elev_min_ref, elev_min(1:2)] ...
                            = deal(min(tmp4, [], 'omitnan'));
            else
                [elev_min_ref, elev_min(1:2)] ...
                            = deal(min(tmp5, [], 'omitnan') - 200);
            end
        else
            [x_min_ref, x_max_ref, x_min, x_max] ...
                            = deal(min(x{curr_rad}(~isinf(x{curr_rad})), [], 'omitnan'), max(x{curr_rad}(~isinf(x{curr_rad})), [], 'omitnan'), min(x{curr_rad}(~isinf(x{curr_rad})), [], 'omitnan'), max(x{curr_rad}(~isinf(x{curr_rad})), [], 'omitnan'));
            [y_min_ref, y_max_ref, y_min, y_max] ...
                            = deal(min(y{curr_rad}(~isinf(y{curr_rad})), [], 'omitnan'), max(y{curr_rad}(~isinf(y{curr_rad})), [], 'omitnan'), min(y{curr_rad}(~isinf(y{curr_rad})), [], 'omitnan'), max(y{curr_rad}(~isinf(y{curr_rad})), [], 'omitnan'));
            if surf_avail(curr_rad)
                [elev_max_ref, elev_max(1:2)] ...
                            = deal(max(elev_surf{curr_rad}(~isinf(elev_surf{curr_rad})), [], 'omitnan'));
            else
                [elev_max_ref, elev_max(1:2)] ...
                            = deal(max(elev_smooth{curr_rad}(~isinf(elev_smooth{curr_rad}(:))), [], 'omitnan') + 200);
            end
            if bed_avail(curr_rad)
                [elev_min_ref, elev_min(1:2)] ...
                            = deal(min(elev_bed{curr_rad}(~isinf(elev_bed{curr_rad})), [], 'omitnan'));
            else
                [elev_min_ref, elev_min(1:2)] ...
                            = deal(min(elev_smooth{curr_rad}(~isinf(elev_smooth{curr_rad}(:))), [], 'omitnan') - 200);
            end
        end
        
        set(x_min_slide, 'min', x_min_ref, 'max', x_max_ref, 'value', x_min_ref)
        set(x_max_slide, 'min', x_min_ref, 'max', x_max_ref, 'value', x_max_ref)
        set(y_min_slide, 'min', y_min_ref, 'max', y_max_ref, 'value', y_min_ref)
        set(y_max_slide, 'min', y_min_ref, 'max', y_max_ref, 'value', y_max_ref)
        set(dist_min_slide(curr_rad), 'min', dist_min_ref(curr_rad), 'max', dist_max_ref(curr_rad), 'value', dist_min_ref(curr_rad))
        set(dist_max_slide(curr_rad), 'min', dist_min_ref(curr_rad), 'max', dist_max_ref(curr_rad), 'value', dist_max_ref(curr_rad))
        set(z_min_slide, 'min', elev_min_ref, 'max', elev_max_ref, 'value', elev_min_ref)
        set(z_max_slide, 'min', elev_min_ref, 'max', elev_max_ref, 'value', elev_max_ref)
        set(x_min_edit, 'string', sprintf('%4.1f', x_min_ref))
        set(x_max_edit, 'string', sprintf('%4.1f', x_max_ref))
        set(y_min_edit, 'string', sprintf('%4.1f', y_min_ref))
        set(y_max_edit, 'string', sprintf('%4.1f', y_max_ref))
        set(dist_min_edit(curr_rad), 'string', sprintf('%4.1f', dist_min_ref(curr_rad)))
        set(dist_max_edit(curr_rad), 'string', sprintf('%4.1f', dist_max_ref(curr_rad)))
        set(z_min_edit, 'string', sprintf('%4.0f', elev_min_ref))
        set(z_max_edit, 'string', sprintf('%4.0f', elev_max_ref))
        
        pk_done(curr_rad)   = true;
        set(pk_check(:, curr_rad), 'value', 1)
        
        % intersection plots
        if (curr_rad == 2)
            for ii = 1:2
                for jj = 1:3
                    p_int1{ii, jj} ...
                            = NaN(1, num_int);
                end
                p_int2{ii, 1} ...
                            = NaN(1, pk{2}.num_layer);
                p_int2{ii, 2} ...
                            = NaN(1, pk{1}.num_layer);
            end
            axes(ax(1))
            for ii = 1:num_int
                p_int1{1, 1}(ii) ...
                            = plot3(repmat(x{1}(curr_ind_int(ii, 1)), 1, 2), repmat(y{1}(curr_ind_int(ii, 1)), 1, 2), [elev_min_ref elev_max_ref], 'm--', 'linewidth', 2, 'visible', 'off');
            end
            axes(ax(2))
            for ii = 1:num_int
                p_int1{1, 2}(ii) ...
                            = plot(repmat(dist_lin{1}(curr_ind_int(ii, 1)), 1, 2), [elev_min_ref elev_max_ref], 'm--', 'linewidth', 2, 'visible', 'off');
                p_int1{2, 2}(ii) ...
                            = plot(repmat(dist_lin{1}(curr_ind_int(ii, 1)), 1, 2), [depth_min_ref depth_max_ref], 'm--', 'linewidth', 2, 'visible', 'off');
            end
            for ii = 1:pk{2}.num_layer
                p_int2{1, 1}(ii) ...
                            = plot(dist_lin{1}(curr_ind_int(:, 1)), elev_smooth{2}(ii, curr_ind_int(:, 2)), 'ko', 'linewidth', 1, 'markersize', 8, 'markerfacecolor', colors{2}(ii, :), 'visible', 'off');
                p_int2{2, 1}(ii) ...
                            = plot(dist_lin{1}(curr_ind_int(:, 1)), pk{2}.depth_smooth(ii, curr_ind_int(:, 2)), 'ko', 'linewidth', 1, 'markersize', 8, 'markerfacecolor', colors{2}(ii, :), 'visible', 'off');
            end
            axes(ax(3))
            for ii = 1:num_int
                p_int1{1, 3}(ii) ...
                            = plot(repmat(dist_lin{2}(curr_ind_int(ii, 2)), 1, 2), [elev_min_ref elev_max_ref], 'm--', 'linewidth', 2, 'visible', 'off');
                p_int1{2, 3}(ii) ...
                            = plot(repmat(dist_lin{2}(curr_ind_int(ii, 2)), 1, 2), [depth_min_ref depth_max_ref], 'm--', 'linewidth', 2, 'visible', 'off');
            end
            for ii = 1:pk{1}.num_layer
                p_int2{1, 2}(ii) ...
                            = plot(dist_lin{2}(curr_ind_int(:, 2)), elev_smooth{1}(ii, curr_ind_int(:, 1)), 'ko', 'linewidth', 1, 'markersize', 8, 'markerfacecolor', colors{1}(ii, :), 'visible', 'off');
                p_int2{2, 2}(ii) ...
                            = plot(dist_lin{2}(curr_ind_int(:, 2)), pk{1}.depth_smooth(ii, curr_ind_int(:, 1)), 'ko', 'linewidth', 1, 'markersize', 8, 'markerfacecolor', colors{1}(ii, :), 'visible', 'off');
            end
            
            if ~isempty(ind_layer{1})
                set([p_int2{1, 2}(ind_layer{1}(:, 1)) p_int2{2, 2}(ind_layer{1}(:, 1))], 'marker', 's')
            end
            if ~isempty(ind_layer{2})
                set([p_int2{1, 1}(ind_layer{2}(:, 1)) p_int2{2, 1}(ind_layer{2}(:, 1))], 'marker', 's')
            end
            
            for ii = 1:size(ind_layer{1}, 1)
                if ((ind_layer{1}(ii, 2) == curr_year(2)) && (ind_layer{1}(ii, 3) == curr_trans(2)) && (ind_layer{1}(ii, 4) == curr_subtrans(2))) % match to current transect
                    if (length(find((ind_layer{1}(:, end) == ind_layer{1}(ii, end)))) > 1)
                        tmp1= find((ind_layer{1}(:, end) == ind_layer{1}(ii, end)));
                        colors{1}(ind_layer{1}(tmp1(2:end), 1), :) ...
                            = repmat(colors{1}(ind_layer{1}(tmp1(1), 1), :), length(tmp1(2:end)), 1);
                        set([p_pk{1, 1}(ind_layer{1}(ii, 1)) p_pk{2, 1}(ind_layer{1}(ii, 1)) p_pkdepth{1}(ind_layer{1}(ii, 1))], 'color', colors{1}(ind_layer{1}(tmp1(1), 1), :))
                    end
                    set([p_int2{1}(ind_layer{1}(ii, 5)) p_int2{1, 2}(ind_layer{1}(ii, 1)) p_int2{2, 2}(ind_layer{1}(ii, 1))], 'marker', '^', 'markerfacecolor', colors{1}(ind_layer{1}(ii, 1), :))
                    set([p_pk{1, 2}(ind_layer{1}(ii, 5)) p_pk{2, 2}(ind_layer{1}(ii, 5)) p_pkdepth{2}(ind_layer{1}(ii, 5))], 'color', colors{1}(ind_layer{1}(ii, 1), :))
                end
            end
            set(int_check, 'value', 1)
            show_int1
            show_int2
            show_int3
        end
        
        disp_type           = 'elev.';
        set(disp_group, 'selectedobject', disp_check(1))
        
        % show gui2 display items
        switch curr_rad
            case 1
                [curr_gui, curr_ax] ...
                            = deal(2);
            case 2
                [curr_gui, curr_ax] ...
                            = deal(2, 3);
        end
        axes(ax(curr_ax))
        update_z_range
        update_dist_range
        switch curr_rad
            case 1
                show_pk3
                show_pk1
            case 2
                show_pk4
                show_pk2
        end
        axes(ax(curr_ax))
        
        if (core_done && all(pk_done))
            load_core_breakout
        end
        
        if all(pk_done)
            set(intnum_list, 'value', 1)
            change_int
        end
        reset_xyz
        
        set(status_box(1), 'string', ['Loaded ' file_pk_short{curr_rad} '.'])
    end

%% Load radar data

    function load_data1(source, eventdata)
        [curr_gui, curr_ax, curr_rad, curr_rad_alt] ...
                            = deal(2, 2, 1, 2);
        set(fgui, 'keypressfcn', '', 'windowbuttondownfcn', '')
        load_data
        set(fgui(1), 'keypressfcn', @keypress1)
        set(fgui(2), 'keypressfcn', @keypress2, 'windowbuttondownfcn', @mouse_click)
    end

    function load_data2(source, eventdata)
        [curr_gui, curr_ax, curr_rad, curr_rad_alt] ...
                            = deal(2, 3, 2, 1);
        set(fgui, 'keypressfcn', '', 'windowbuttondownfcn', '')
        load_data
        set(fgui(1), 'keypressfcn', @keypress1)
        set(fgui(2), 'keypressfcn', @keypress2, 'windowbuttondownfcn', @mouse_click)
    end

    function load_data(source, eventdata) %#ok<*INUSD>
        
        set(rad_group, 'selectedobject', rad_check(curr_rad))
        
        if ~pk_done(curr_rad)
            set(status_box(2), 'string', 'Load picks before data.')
            return
        end
        
        % check if data are in expected location based on picks' filename
        tmp1                = file_pk_short{curr_rad};
        if (isnan(str2double(tmp1(end))) || ~isreal(str2double(tmp1(end)))) % check for a/b/c/etc in file_pk_short
            tmp2            = tmp1(1:(end - 1));
        else
            tmp2            = tmp1;
        end
        
        if ispc
            if ~strcmp(tmp1, tmp2)
                if (~isempty(path_pk{curr_rad}) && exist([path_pk{curr_rad} '..\block\' tmp2 '\' tmp1(end) '\'], 'dir'))
                    path_data{curr_rad} ...
                            = [path_pk{curr_rad}(1:strfind(path_pk{curr_rad}, '\merge')) 'block\' tmp2 '\' tmp1(end) '\'];
                elseif (~isempty(path_pk{curr_rad}) && exist([path_pk{curr_rad} '..\block\' tmp2 '\'], 'dir'))
                    path_data{curr_rad} ...
                            = [path_pk{curr_rad}(1:strfind(path_pk{curr_rad}, '\merge')) 'block\' tmp2 '\'];
                end
            elseif (~isempty(path_pk{curr_rad}) && exist([path_pk{curr_rad} '..\block\' tmp2 '\'], 'dir'))
                path_data{curr_rad} ...
                            = [path_pk{curr_rad}(1:strfind(path_pk{curr_rad}, '\merge')) 'block\' tmp2 '\'];
            end
        else
            if ~strcmp(tmp1, tmp2)
                if (~isempty(path_pk{curr_rad}) && exist([path_pk{curr_rad} '../block/' tmp2 '/' tmp1(end) '/'], 'dir'))
                    path_data{curr_rad} ...
                            = [path_pk{curr_rad}(1:strfind(path_pk{curr_rad}, '/merge')) 'block/' tmp2 '/' tmp1(end) '/'];
                elseif (~isempty(path_pk{curr_rad}) && exist([path_pk{curr_rad} '../block/' tmp2 '/'], 'dir'))
                    path_data{curr_rad} ...
                            = [path_pk{curr_rad}(1:strfind(path_pk{curr_rad}, '/merge')) 'block/' tmp2 '/'];
                end
            elseif (~isempty(path_pk{curr_rad}) && exist([path_pk{curr_rad} '../block/' tmp2 '/'], 'dir'))
                path_data{curr_rad} ...
                            = [path_pk{curr_rad}(1:strfind(path_pk{curr_rad}, '/merge')) 'block/' tmp2 '/'];
            end
        end
        
        if (~isempty(path_data{curr_rad}) && exist([path_data{curr_rad} pk{curr_rad}.file_block{1} '.mat'], 'file'))
            file_data{curr_rad} ...
                            = pk{curr_rad}.file_block;
            for ii = 1:length(file_data{curr_rad})
                file_data{curr_rad}{ii} ...
                            = [file_data{curr_rad}{ii} '.mat'];
            end
        elseif ~isempty(path_data{curr_rad}) % Dialog box to choose radar data file to load
            [file_data{curr_rad}, path_data{curr_rad}] ...
                            = uigetfile('*.mat', 'Load radar data:', path_data{curr_rad}, 'multiselect', 'on');
        elseif ~isempty(path_data{curr_rad_alt})
            [file_data{curr_rad}, path_data{curr_rad}] ...
                            = uigetfile('*.mat', 'Load radar data:', path_data{curr_rad_alt}, 'multiselect', 'on');
        elseif ~isempty(path_pk{curr_rad})
            [file_data{curr_rad}, path_data{curr_rad}] ...
                            = uigetfile('*.mat', 'Load radar data:', path_pk{curr_rad}, 'multiselect', 'on');
        elseif ~isempty(path_pk{curr_rad_alt})
            [file_data{curr_rad}, path_data{curr_rad}] ...
                            = uigetfile('*.mat', 'Load radar data:', path_pk{curr_rad_alt}, 'multiselect', 'on');
        else
            [file_data{curr_rad}, path_data{curr_rad}] ...
                            = uigetfile('*.mat', 'Load radar data:', 'multiselect', 'on');
        end
        
        if isnumeric(file_data{curr_rad})
            [file_data{curr_rad}, path_data{curr_rad}] ...
                            = deal('');
        end
        
        if isempty(file_data{curr_rad})
            set(status_box(2), 'string', 'No radar data loaded.')
            return
        end
        
        pause(0.1)
        
        if ischar(file_data{curr_rad})
            file_data{curr_rad} ...
                            = {file_data(curr_rad)};
        end
        
        num_data(curr_rad)  = length(file_data{curr_rad});
        if (num_data(curr_rad) ~= length(pk{curr_rad}.file_block))
            set(status_box(2), 'string', ['Number of data blocks selected (' num2str(num_data(curr_rad)) ') does not match number of blocks in intersection list (' num2str(length(pk{curr_rad}.file_block)) ').'])
            return
        end
        
        if (~strcmp(file_data{curr_rad}{1}, [pk{curr_rad}.file_block{1} '.mat']) && ~isempty(pk{curr_rad}.file_block{1}))
            set(status_box(2), 'string', 'Correct intersecting blocks may not have been selected. Try again.')
            return
        end
        
        % get rid of all data handle if somehow present
        if data_done(curr_rad)
            data_done(curr_rad) ...
                            = false;
        end
        
        load_data_breakout
    end

    function load_data_breakout(source, eventdata)
        
        axes(ax(curr_ax))
        
        % attempt to load data
        set(status_box(2), 'string', 'Loading radar data...')
        pause(0.1)
        
        for ii = 1:num_data(curr_rad)
            
            if iscell(file_data{curr_rad}{ii})
                file_data{curr_rad}{ii} ...
                            = file_data{curr_rad}{ii}{1};
            end
            set(status_box(2), 'string', ['Loading ' file_data{curr_rad}{ii}(1:(end - 4)) ' (' num2str(ii) ' / ' num2str(num_data(curr_rad)) ')...'])
            pause(0.1)
            tmp1            = load([path_data{curr_rad} file_data{curr_rad}{ii}]);
            try
                tmp1        = tmp1.block;
            catch %#ok<*CTCH>
                set(status_box(2), 'string', [file_data{curr_rad}{ii} ' does not contain a block structure. Try again.'])
                return
            end
            
            if (ii == 1) % start decimation
                
                [dt(curr_rad), twtt{curr_rad}, num_sample(curr_rad)] ...
                            = deal(tmp1.dt, tmp1.twtt, tmp1.num_sample);
                amp_elev{curr_rad} ...
                            = NaN(num_sample(curr_rad), num_decim(curr_rad));
                tmp2        = (1 + ceil(decim(curr_rad) / 2)):decim(curr_rad):(pk{curr_rad}.num_trace(ii) - ceil(decim(curr_rad) / 2));
                tmp3        = floor(decim(curr_rad) / 2);
                for jj = 1:length(tmp2)
                    amp_elev{curr_rad}(:, jj) ...
                            = mean(tmp1.amp(:, (tmp2(jj) - tmp3):(tmp2(jj) + tmp3)), 2, 'omitnan');
                end
                
            else % middle/end
                
                tmp2        = repmat((pk{curr_rad}.ind_trace_start(ii) + pk{curr_rad}.ind_overlap(ii, 1)), 1, 2);
                tmp2(2)     = tmp2(2) + pk{curr_rad}.num_trace(ii) - pk{curr_rad}.ind_overlap(ii, 1) - 1;
                if (ii < num_data(curr_rad))
                    tmp3    = (find((tmp2(1) > ind_decim{curr_rad}), 1, 'last') + 1):find((tmp2(2) <= ind_decim{curr_rad}), 1);
                else
                    tmp3    = (find((tmp2(1) > ind_decim{curr_rad}), 1, 'last') + 1):num_decim(curr_rad);
                end
                if (ii == 2)
                    tmp3    = [(tmp3(1) - 2) (tmp3(1) - 1) tmp3]; %#ok<AGROW> % correct weirdness for first block
                end
                tmp2        = ind_decim{curr_rad}(tmp3) - pk{curr_rad}.ind_trace_start(ii) + 1;
                tmp4        = tmp2 - floor(decim(curr_rad) / 2);
                tmp5        = tmp2 + floor(decim(curr_rad) / 2);
                tmp4(tmp4 < 1) ...
                            = 1;
                tmp5(tmp5 > pk{curr_rad}.num_trace(ii)) ...
                            = pk{curr_rad}.num_trace(ii);
                if (size(amp_elev{curr_rad}, 1) > size(tmp1.amp, 1))
                    for jj = 1:length(tmp3)
                        amp_elev{curr_rad}(:, tmp3(jj)) ...
                            = [mean(tmp1.amp(:, tmp4(jj):tmp5(jj)), 2, 'omitnan'); NaN((size(amp_elev{curr_rad}, 1) - size(tmp1.amp, 1)), 1)];
                    end
                elseif (size(amp_elev{curr_rad}, 1) < size(tmp1.amp, 1))
                    for jj = 1:length(tmp3)
                        amp_elev{curr_rad}(:, tmp3(jj)) ...
                            = mean(tmp1.amp(1:size(amp_elev{curr_rad}, 1, 'omitnan'), tmp4(jj):tmp5(jj)), 2);
                    end
                else
                    for jj = 1:length(tmp3)
                        amp_elev{curr_rad}(:, tmp3(jj)) ...
                            = mean(tmp1.amp(:, tmp4(jj):tmp5(jj)), 2, 'omitnan');
                    end
                end
            end
            
            tmp1            = 0;
            
        end
        
        % convert to dB
        amp_elev{curr_rad}(isinf(amp_elev{curr_rad})) ...
                            = NaN;
        amp_elev{curr_rad}  = 10 .* log10(abs(amp_elev{curr_rad}));
        num_sample(curr_rad)= size(amp_elev{curr_rad}, 1);
        depth{curr_rad}     = ((speed_ice / 2) .* twtt{curr_rad}); % simple monotonically increasing depth vector
        if surf_avail(curr_rad)
            tmp2            = interp1(twtt{curr_rad}, 1:num_sample(curr_rad), pk{curr_rad}.twtt_surf(ind_decim{curr_rad}), 'nearest', 'extrap'); % surface traveltime indices
            if any(isnan(tmp2))
                tmp2(isnan(tmp2)) ...
                            = round(interp1(find(~isnan(tmp2)), tmp2(~isnan(tmp2)), find(isnan(tmp2)), 'linear', 'extrap'));
            end
            tmp2(tmp2 < 1)  = 1;
            tmp2(tmp2 > num_sample(curr_rad)) ...
                            = num_sample(curr_rad);
        else
            tmp2            = ones(1, num_decim(curr_rad));
        end
        tmp3                = elev_surf{curr_rad}(ind_decim{curr_rad});
        if any(isnan(tmp3))
            tmp3(isnan(tmp3)) ...
                            = interp1(find(~isnan(tmp3)), tmp3(~isnan(tmp3)), find(isnan(tmp3)), 'linear', 'extrap');
        end
        amp_depth{curr_rad} = NaN(size(amp_elev{curr_rad}), 'single');
        for ii = 1:num_decim(curr_rad)
            amp_depth{curr_rad}(1:(num_sample(curr_rad) - tmp2(ii) + 1), ii) ...
                            = amp_elev{curr_rad}(tmp2(ii):num_sample(curr_rad), ii); % shift data up to surface
        end
        [amp_elev{curr_rad}, ind_corr{curr_rad}] ...
                            = topocorr(amp_depth{curr_rad}, depth{curr_rad}, tmp3); % topographically correct data
        
        if strcmp(radar_type, 'deep')
            amp_depth{curr_rad} ...
                            = 0;
        end
        
        amp_elev{curr_rad}  = flipud(amp_elev{curr_rad}); % flip for axes
        ind_corr{curr_rad}  = max(ind_corr{curr_rad}) - ind_corr{curr_rad} + 1;
        depth{curr_rad}     = (speed_ice / 2) .* (0:dt(curr_rad):((num_sample(curr_rad) - 1) * dt(curr_rad)))'; % simple monotonically increasing depth vector
        elev{curr_rad}      = flipud(max(elev_surf{curr_rad}(ind_decim{curr_rad})) - depth{curr_rad}); % elevation vector
        
        % assign traveltime and distance reference values/sliders based on data
        [db_min_ref(curr_ax), db_max_ref(curr_ax), db_min(curr_ax), db_max(curr_ax), depth_min, depth_max] ...
                            = deal(min(amp_elev{curr_rad}(~isinf(amp_elev{curr_rad}(:))), [], 'omitnan'), max(amp_elev{curr_rad}(~isinf(amp_elev{curr_rad}(:))), [], 'omitnan'), min(amp_elev{curr_rad}(~isinf(amp_elev{curr_rad}(:))), [], 'omitnan'), ...
                                   max(amp_elev{curr_rad}(~isinf(amp_elev{curr_rad}(:))), [], 'omitnan'), min(depth{curr_rad}), max(depth{curr_rad}));
        if data_done(curr_rad_alt)
            [depth_min_ref, depth_max_ref] ...
                            = deal(min([depth{1}; depth{2}]), max([depth{1}; depth{2}]));
        else
            [depth_min_ref, depth_max_ref] ...
                            = deal(min(depth{curr_rad}), max(depth{curr_rad}));
        end
        set(cb_min_slide(curr_ax), 'min', db_min_ref(curr_ax), 'max', db_max_ref(curr_ax), 'value', db_min_ref(curr_ax))
        set(cb_max_slide(curr_ax), 'min', db_min_ref(curr_ax), 'max', db_max_ref(curr_ax), 'value', db_max_ref(curr_ax))
        set(cb_min_edit(curr_ax), 'string', sprintf('%3.0f', db_min_ref(curr_ax)))
        set(cb_max_edit(curr_ax), 'string', sprintf('%3.0f', db_max_ref(curr_ax)))
        
        if all(pk_done)
            for ii = 1:3
                if (ii == 1)
                    set(p_int1{1, ii}(ishandle(p_int1{1, ii})), 'zdata', [elev_min_ref elev_max_ref])
                else
                    set(p_int1{1, ii}(ishandle(p_int1{1, ii})), 'ydata', [elev_min_ref elev_max_ref])
                end
            end
            for ii = 2:3
                set(p_int1{2, ii}(ishandle(p_int1{2, ii})), 'ydata', [depth_min_ref depth_max_ref])
            end
        end
        
        if core_done
            for ii = 1:2
                if (ii == 1)
                    set(p_core{ii, curr_rad}(ishandle(p_core{ii, curr_rad})), 'zdata', [elev_min_ref elev_max_ref])
                else
                    set(p_core{ii, curr_rad}(ishandle(p_core{ii, curr_rad})), 'ydata', [elev_min_ref elev_max_ref])
                end
                for jj = 1:length(p_corename{ii, curr_rad})
                    if ishandle(p_corename{ii, curr_rad}(jj))
                        tmp1 = get(p_corename{ii, curr_rad}(jj), 'position');
                        set(p_corename{ii, curr_rad}(jj), 'position', [tmp1(1:2) (elev_max_ref - 50)])
                    end
                end
            end
            set(p_coredepth{curr_rad}(ishandle(p_coredepth{curr_rad})), 'ydata', [depth_min_ref depth_max_ref])
            for ii = 1:length(p_corenamedepth{curr_rad})
                if ishandle(p_corenamedepth{curr_rad}(ii))
                    tmp1    = get(p_corenamedepth{curr_rad}(ii), 'position');
                    set(p_corenamedepth{curr_rad}(ii), 'position', [tmp1(1:2) (depth_max_ref + 50)])
                end
            end
        end
        
        % plot data
        data_done(curr_rad) = true;
        set(data_check(curr_gui, curr_rad), 'value', 1)
        disp_type           = 'elev.';
        set(disp_group, 'selectedobject', disp_check(1))
        if surf_avail
            set(disp_check(2), 'visible', 'on')
        end
        plot_elev
        if (curr_rad == 2)
            set(intnum_list, 'value', 1)
            change_int
        end
        set(status_box(2), 'string', 'Transect radar data loaded.')
    end

%% Select current layer

    function pk_select1(source, eventdata)
        [curr_gui, curr_ax, curr_rad, curr_rad_alt] ...
                        = deal(1, 1, 1, 2);
        pk_select
    end

    function pk_select2(source, eventdata)
        [curr_gui, curr_ax, curr_rad, curr_rad_alt] ...
                        = deal(1, 1, 2, 1);
        pk_select
    end

    function pk_select3(source, eventdata)
        [curr_gui, curr_ax, curr_rad, curr_rad_alt] ...
                        = deal(2, 2, 1, 2);
        pk_select
    end

    function pk_select4(source, eventdata)
        [curr_gui, curr_ax, curr_rad, curr_rad_alt] ...
                        = deal(2, 3, 2, 1);
        pk_select
    end

    function pk_select(source, eventdata)
        set(rad_group, 'selectedobject', rad_check(curr_rad))
        curr_layer(curr_rad)= get(layer_list(curr_gui, curr_rad), 'value');
        if pk_done(curr_rad)
            set(layer_list(:, curr_rad), 'value', curr_layer(curr_rad))
            for ii = 1:2
                set(p_pk{ii, curr_rad}(ishandle(p_pk{ii, curr_rad})), 'markersize', 12)
                set(p_int2{ii, curr_rad_alt}(ishandle(p_int2{ii, curr_rad_alt})), 'markersize', 8)
                if ishandle(p_pk{ii, curr_rad}(curr_layer(curr_rad)))
                    set(p_pk{ii, curr_rad}(curr_layer(curr_rad)), 'markersize', 24)
                end
                if all(pk_done)
                    if ishandle(p_int2{ii, curr_rad_alt}(curr_layer(curr_rad)))
                        set(p_int2{ii, curr_rad_alt}(curr_layer(curr_rad)), 'markersize', 16)
                    end
                end
            end
            set(p_pkdepth{curr_rad}(ishandle(p_pk{ii, curr_rad})), 'markersize', 12)
            set(p_pkdepth{curr_rad}(curr_layer(curr_rad)), 'markersize', 24)
        end
        if ischar(tmp1)
            if strcmp(tmp1, 'reselect')
                return
            end
        end
        tmp1                = '';
        if (all(pk_done) && ~isempty(ind_layer{2}) && get(match_check, 'value'))
            switch curr_rad
                case 1
                    if ~isempty(find(((ind_layer{2}(:, 5) == curr_layer(1)) & (ind_layer{2}(:, 2) == curr_year(1)) & (ind_layer{2}(:, 3) == curr_trans(1)) & (ind_layer{2}(:, 4) == curr_subtrans(1))), 1))
                        curr_layer(2) = ind_layer{2}(find(((ind_layer{2}(:, 5) == curr_layer(1)) & (ind_layer{2}(:, 2) == curr_year(1)) & (ind_layer{2}(:, 3) == curr_trans(1)) & (ind_layer{2}(:, 4) == curr_subtrans(1))), 1), 1);
                        for ii = 1:2
                            set(p_pk{ii, 2}(ishandle(p_pk{ii, 2})), 'markersize', 12)
                            set(p_pk{ii, 2}(curr_layer(2)), 'markersize', 24)
                            for jj = 1:2
                                set(p_int2{ii, jj}(ishandle(p_int2{ii, jj})), 'markersize', 8)
                            end
                            if ishandle(p_int2{ii, 1}(curr_layer(2)))
                                set(p_int2{ii, 1}(curr_layer(2)), 'markersize', 16)
                            end
                            if ishandle(p_int2{ii, 2}(curr_layer(1)))
                                set(p_int2{ii, 2}(curr_layer(1)), 'markersize', 16)
                            end
                        end
                        set(p_pkdepth{2}(ishandle(p_pkdepth{2})), 'markersize', 12)
                        if ishandle(p_pkdepth{2}(curr_layer(2)))
                            set(p_pkdepth{2}(curr_layer(2)), 'markersize', 24)
                        end
                        tmp1 = 'matched';
                    end
                    set(layer_list(:, 2), 'value', curr_layer(2))
                case 2
                    if ~isempty(find(((ind_layer{2}(:, 1) == curr_layer(2)) & (ind_layer{2}(:, 2) == curr_year(1)) & (ind_layer{2}(:, 3) == curr_trans(1)) & (ind_layer{2}(:, 4) == curr_subtrans(1))), 1))
                        curr_layer(1) = ind_layer{2}(find(((ind_layer{2}(:, 1) == curr_layer(2)) & (ind_layer{2}(:, 2) == curr_year(1)) & (ind_layer{2}(:, 3) == curr_trans(1)) & (ind_layer{2}(:, 4) == curr_subtrans(1))), 1), 5);
                        for ii = 1:2
                            set(p_pk{ii, 1}(ishandle(p_pk{ii, 1})), 'markersize', 12)
                            if ishandle(p_pk{ii, 1}(curr_layer(1)))
                                set(p_pk{ii, 1}(curr_layer(1)), 'markersize', 24)
                            end
                            for jj = 1:2
                                set(p_int2{ii, jj}(ishandle(p_int2{ii, jj})), 'markersize', 8)
                            end
                            if ishandle(p_int2{ii, 1}(curr_layer(2)))
                                set(p_int2{ii, 1}(curr_layer(2)), 'markersize', 16)
                            end
                            if ishandle(p_int2{ii, 2}(curr_layer(1)))
                                set(p_int2{ii, 2}(curr_layer(1)), 'markersize', 16)
                            end
                        end
                        set(p_pkdepth{1}(ishandle(p_pkdepth{1})), 'markersize', 12)
                        if ishandle(p_pkdepth{1}(curr_layer(1)))
                            set(p_pkdepth{1}(curr_layer(1)), 'markersize', 24)
                        end
                        tmp1 = 'matched';
                    end
                    set(layer_list(:, 1), 'value', curr_layer(1))
            end
        end
        if (get(nearest_check, 'value') && all(pk_done) && isempty(tmp1))
            if any(~isnan(elev_smooth{curr_rad_alt}(:, curr_ind_int(curr_int, curr_rad_alt))))
                [~, curr_layer(curr_rad_alt)] ...
                            = min(abs(elev_smooth{curr_rad}(curr_layer(curr_rad), curr_ind_int(curr_int, curr_rad)) - elev_smooth{curr_rad_alt}(:, curr_ind_int(curr_int, curr_rad_alt))));
                [curr_rad, curr_rad_alt] ...
                            = deal(curr_rad_alt, curr_rad);
                set(layer_list(curr_gui, curr_rad), 'value', curr_layer(curr_rad))
                tmp1        = 'reselect';
                pk_select
            end
        else
            set(status_box, 'string', ['Layer #' num2str(curr_layer(curr_rad)) ' selected.'])
        end
    end

%% Select a layer interactively

    function pk_select_gui1(source, eventdata)
        [curr_gui, curr_ax, curr_rad, curr_rad_alt] ...
                        = deal(2, 2, 1, 2);
        pk_select_gui
    end

    function pk_select_gui2(source, eventdata)
        [curr_gui, curr_ax, curr_rad, curr_rad_alt] ...
                        = deal(2, 3, 2, 1);
        pk_select_gui
    end

    function pk_select_gui(source, eventdata)
        set(rad_group, 'selectedobject', rad_check(curr_rad))
        if ~pk_done(curr_rad)
            set(status_box(curr_gui), 'string', 'No layers to focus on.')
            return
        end
        if ~get(pk_check(2, curr_rad), 'value')
            set(pk_check(2, curr_rad), 'value', 1)
            show_pk
        end
        set(status_box(2), 'string', 'Choose a layer to select...')
        [ind_x_pk, ind_y_pk]= ginput(1);
        pk_select_gui_breakout
    end

    function pk_select_gui_breakout(source, eventdata)
        switch disp_type
            case 'elev.'
                [tmp1, tmp2]= unique(elev_smooth{curr_rad}(:, interp1(dist_lin{curr_rad}(ind_decim{curr_rad}), ind_decim{curr_rad}, ind_x_pk, 'nearest', 'extrap')));
            case 'depth'
                [tmp1, tmp2]= unique(pk{curr_rad}.depth_smooth(:, interp1(dist_lin{curr_rad}(ind_decim{curr_rad}), ind_decim{curr_rad}, ind_x_pk, 'nearest', 'extrap')));
        end
        if (length(tmp1(~isnan(tmp1))) > 1)
            curr_layer(curr_rad) ...
                            = interp1(tmp1(~isnan(tmp1)), tmp2(~isnan(tmp1)), ind_y_pk, 'nearest', 'extrap');
        elseif (length(tmp1(~isnan(tmp1))) == 1)
            curr_layer(curr_rad) ...
                            = tmp2(find(~isnan(tmp1), 1));
        else
            set(status_box(2), 'string', 'Layer choice unclear.')
            return
        end
        set(layer_list(:, curr_rad), 'value', curr_layer(curr_rad))
        pk_select
        set(status_box(curr_gui), 'string', ['Layer #' num2str(curr_layer(curr_rad)) ' selected.'])
    end

%% Focus on a layer

    function pk_focus1(source, eventdata)
        [curr_gui, curr_ax, curr_rad, curr_rad_alt] ...
                        = deal(2, 2, 1, 2);
        pk_focus
    end

    function pk_focus2(source, eventdata)
        [curr_gui, curr_ax, curr_rad, curr_rad_alt] ...
                        = deal(2, 3, 2, 1);
        pk_focus
    end

    function pk_focus(source, eventdata)
        if ~any(~isnan(pk{curr_rad}.elev_smooth(curr_layer(curr_rad), ind_decim{curr_rad})))
            set(status_box(2), 'string', 'Cannot focus on a layer that is hidden.')
            return
        end
        axes(ax(curr_ax))
        xlim([pk{curr_rad}.dist_lin(find(~isnan(pk{curr_rad}.elev_smooth_gimp(curr_layer(curr_rad), :)), 1)) pk{curr_rad}.dist_lin(find(~isnan(pk{curr_rad}.elev_smooth_gimp(curr_layer(curr_rad), :)), 1, 'last'))])
        tmp1                = get(ax(curr_ax), 'xlim');
        [tmp1(1), tmp1(2)]  = deal((tmp1(1) - diff(tmp1)), (tmp1(2) + diff(tmp1)));
        if (tmp1(1) < dist_min_ref(curr_rad))
            tmp1(1)         = dist_min_ref(curr_rad);
        end
        if (tmp1(2) > dist_max_ref(curr_rad))
            tmp1(2)         = dist_max_ref(curr_rad);
        end
        xlim(tmp1)
        [dist_min(curr_rad), dist_max(curr_rad)] ...
                            = deal(tmp1(1), tmp1(2));
        if (dist_min(curr_rad) < get(dist_min_slide(curr_rad), 'min'))
            set(dist_min_slide(curr_rad), 'value', get(dist_min_slide(curr_rad), 'min'))
        elseif (dist_min(curr_rad) > get(dist_min_slide(curr_rad), 'max'))
            set(dist_min_slide(curr_rad), 'value', get(dist_min_slide(curr_rad), 'max'))
        else
            set(dist_min_slide(curr_rad), 'value', dist_min(curr_rad))
        end
        if (dist_max(curr_rad) < get(dist_max_slide(curr_rad), 'min'))
            set(dist_max_slide(curr_rad), 'value', get(dist_max_slide(curr_rad), 'min'))
        elseif (dist_max(curr_rad) > get(dist_max_slide(curr_rad), 'max'))
            set(dist_max_slide(curr_rad), 'value', get(dist_max_slide(curr_rad), 'max'))
        else
            set(dist_max_slide(curr_rad), 'value', dist_max(curr_rad))
        end
        set(dist_min_edit(curr_rad), 'string', sprintf('%3.1f', dist_min(curr_rad)))
        set(dist_max_edit(curr_rad), 'string', sprintf('%3.1f', dist_max(curr_rad)))
        switch disp_type
            case 'elev.'
                ylim([min(elev_smooth{curr_rad}(curr_layer(curr_rad), ind_decim{curr_rad})) max(elev_smooth{curr_rad}(curr_layer(curr_rad), ind_decim{curr_rad}))])
                tmp1        = get(ax(curr_ax), 'ylim');
                [tmp1(1), tmp1(2)] ...
                            = deal((tmp1(1) - diff(tmp1)), (tmp1(2) + diff(tmp1)));
                if (tmp1(1) < elev_min_ref)
                    tmp1(1) = elev_min_ref;
                end
                if (tmp1(2) > elev_max_ref)
                    tmp1(2) = elev_max_ref;
                end
                ylim(tmp1)
                [elev_min(curr_gui), elev_max(curr_gui)] ...
                            = deal(tmp1(1), tmp1(2));
                if (elev_min(curr_gui) < get(z_min_slide(curr_gui), 'min'))
                    set(z_min_slide(curr_gui), 'value', get(z_min_slide(curr_gui), 'min'))
                elseif (elev_min(curr_gui) > get(z_min_slide(curr_gui), 'max'))
                    set(z_min_slide(curr_gui), 'value', get(z_min_slide(curr_gui), 'max'))
                else
                    set(z_min_slide(curr_gui), 'value', elev_min(curr_gui))
                end
                if (elev_max(curr_gui) < get(z_max_slide(curr_gui), 'min'))
                    set(z_max_slide(curr_gui), 'value', get(z_max_slide(curr_gui), 'min'))
                elseif (elev_max(curr_gui) > get(z_max_slide(curr_gui), 'max'))
                    set(z_max_slide(curr_gui), 'value', get(z_max_slide(curr_gui), 'max'))
                else
                    set(z_max_slide(curr_gui), 'value', elev_max(curr_gui))
                end
                set(z_min_edit(curr_gui), 'string', sprintf('%4.0f', elev_min(curr_gui)))
                set(z_max_edit(curr_gui), 'string', sprintf('%4.0f', elev_max(curr_gui)))
            case 'depth'
                ylim([min(pk{curr_rad}.depth_smooth(curr_layer(curr_rad), ind_decim{curr_rad})) max(pk{curr_rad}.depth_smooth(curr_layer(curr_rad), ind_decim{curr_rad}))])
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
                if ((depth_max_ref - (depth_max - depth_min_ref)) < get(z_min_slide(curr_gui), 'min'))
                    set(z_min_slide(curr_gui), 'value', get(z_min_slide(curr_gui), 'min'))
                elseif ((depth_max_ref - (depth_max - depth_min_ref)) > get(z_min_slide(curr_gui), 'max'))
                    set(z_min_slide(curr_gui), 'value', get(z_min_slide(curr_gui), 'max'))
                else
                    set(z_min_slide(curr_gui), 'value', (depth_max_ref - (depth_max - depth_min_ref)))
                end
                if ((depth_max_ref - (depth_min - depth_min_ref)) < get(z_max_slide(curr_gui), 'min'))
                    set(z_max_slide(curr_gui), 'value', get(z_max_slide(curr_gui), 'min'))
                elseif ((depth_max_ref - (depth_min - depth_min_ref)) > get(z_max_slide(curr_gui), 'max'))
                    set(z_max_slide(curr_gui), 'value', get(z_max_slide(curr_gui), 'max'))
                else
                    set(z_max_slide(curr_gui), 'value', (depth_max_ref - (depth_min - depth_min_ref)))
                end
                set(z_min_edit(curr_gui), 'string', sprintf('%4.0f', depth_max))
                set(z_max_edit(curr_gui), 'string', sprintf('%4.0f', depth_min))
        end
        narrow_cb
        set(status_box(2), 'string', ['Focused on layer #' num2str(curr_layer(curr_rad)) '.'])
    end

%% Switch to previous layer in list

    function pk_last1(source, eventdata)
        [curr_gui, curr_ax, curr_rad, curr_rad_alt] ...
                        = deal(1, 1, 1, 2);
        pk_last
    end

    function pk_last2(source, eventdata)
        [curr_gui, curr_ax, curr_rad, curr_rad_alt] ...
                        = deal(1, 1, 2, 1);
        pk_last
    end

    function pk_last3(source, eventdata)
        [curr_gui, curr_ax, curr_rad, curr_rad_alt] ...
                        = deal(2, 2, 1, 2);
        pk_last
    end

    function pk_last4(source, eventdata)
        [curr_gui, curr_ax, curr_rad, curr_rad_alt] ...
                        = deal(2, 3, 2, 1);
        pk_last
    end

    function pk_last(source, eventdata)
        set(rad_group, 'selectedobject', rad_check(curr_rad))
        if (pk_done(curr_rad) && (curr_layer(curr_rad) > 1))
            curr_layer(curr_rad) ...
                            = curr_layer(curr_rad) - 1;
            set(layer_list(:, curr_rad), 'value', curr_layer(curr_rad))
            pk_select
        end
    end

%% Switch to next layer in the list

    function pk_next1(source, eventdata)
        [curr_gui, curr_ax, curr_rad, curr_rad_alt] ...
                        = deal(1, 1, 1, 2);
        pk_next
    end

    function pk_next2(source, eventdata)
        [curr_gui, curr_ax, curr_rad, curr_rad_alt] ...
                        = deal(1, 1, 2, 1);
        pk_next
    end

    function pk_next3(source, eventdata)
        [curr_gui, curr_ax, curr_rad, curr_rad_alt] ...
                        = deal(2, 2, 1, 2);
        pk_next
    end

    function pk_next4(source, eventdata)
        [curr_gui, curr_ax, curr_rad, curr_rad_alt] ...
                        = deal(2, 3, 2, 1);
        pk_next
    end

    function pk_next(source, eventdata)
        set(rad_group, 'selectedobject', rad_check(curr_rad))
        if (pk_done(curr_rad) && (curr_layer(curr_rad) < pk{curr_rad}.num_layer))
            curr_layer(curr_rad) ...
                            = curr_layer(curr_rad) + 1;
            set(layer_list(:, curr_rad), 'value', curr_layer(curr_rad))
            pk_select
        end
    end

%% Match two intersecting layers

    function pk_match(source, eventdata)
        
        set(fgui, 'keypressfcn', '', 'windowbuttondownfcn', '')
        
        curr_gui            = 2;
        
        if ~all(pk_done)
            set(status_box(curr_gui), 'string', 'Picks must be loaded for both master and intersecting transects.')
            set(fgui(1), 'keypressfcn', @keypress1)
            set(fgui(2), 'keypressfcn', @keypress2, 'windowbuttondownfcn', @mouse_click)
            return
        end
        
        % check if the intersecting layer is already matched to a master layer
        if ~isempty(ind_layer{1})
            if ~isempty(find(ismember(ind_layer{1}(:, 2:5), [curr_year(2) curr_trans(2) curr_subtrans(2) curr_layer(2)], 'rows'), 1))
                tmp1        = find(ismember(ind_layer{1}(:, 2:5), [curr_year(2) curr_trans(2) curr_subtrans(2) curr_layer(2), 'rows']));
                tmp2        = colors{1}(ind_layer{1}(tmp1(1), 1), :);
            else
                tmp2        = colors{1}(curr_layer(1), :);
            end
        else
            tmp2            = colors{1}(curr_layer(1), :);
        end
        
        % check for existing match
        if ~isempty(ind_layer{2})
            if ~isempty(find(ismember(ind_layer{2}, [curr_layer(2) curr_year(1) curr_trans(1) curr_subtrans(1) curr_layer(1)], 'rows'), 1))
                set(status_box(2), 'string', 'This layer pair is already matched.')
                set(fgui(1), 'keypressfcn', @keypress1)
                set(fgui(2), 'keypressfcn', @keypress2, 'windowbuttondownfcn', @mouse_click)
                return
            end
        end
        
        % colorize then verify
        for ii = 1:2
            if ishandle(p_pk{ii, 2}(curr_layer(2)))
                set(p_pk{ii, 2}(curr_layer(2)), 'color', tmp2)
            end
            if ishandle(p_pkdepth{2}(curr_layer(2)))
                set(p_pkdepth{2}(curr_layer(2)), 'color', tmp2)
            end
            if ishandle(p_int2{ii, 1}(curr_layer(2)))
                set(p_int2{ii, 1}(curr_layer(2)), 'markerfacecolor', tmp2)
            end
            if ishandle(p_int2{ii, 2}(curr_layer(1)))
                set(p_int2{ii, 2}(curr_layer(1)), 'markerfacecolor', tmp2)
            end
        end
        
        set(status_box(2), 'string', ['Matching master transect layer #' num2str(curr_layer(1)) ' with intersecting transect layer #' num2str(curr_layer(2)) '...'])
        
        pause(0.1)
        
        % reassign master color to first master color if a master layer is matched to multiple intersecting transects
        if ~isempty(ind_layer{1})
            if ~isempty(find(ismember(ind_layer{1}(:, 2:5), [curr_year(2) curr_trans(2) curr_subtrans(2) curr_layer(2)], 'rows'), 1))
                colors{1}(ind_layer{1}(tmp1, 1), :) ...
                            = repmat(tmp2, length(tmp1), 1);
                for ii = 1:2
                    set(p_pk{ii, 1}(ind_layer{1}(tmp1, 1)), 'color', tmp2)
                    set(p_pkdepth{1}(ind_layer{1}(tmp1, 1)), 'color', tmp2)
                    set(p_int2{ii, 2}(ind_layer{1}(tmp1, 1)), 'markerfacecolor', tmp2)
                end
            end
        end
        
        % add each layer to the other's list
        ind_layer{1}     = [ind_layer{1}; [curr_layer(1) curr_year(2) curr_trans(2) curr_subtrans(2) curr_layer(2)]];
        ind_layer{2}     = [ind_layer{2}; [curr_layer(2) curr_year(1) curr_trans(1) curr_subtrans(1) curr_layer(1)]];
        
        for ii = 1:2
            if ishandle(p_int2{ii, 1}(curr_layer(2)))
                set(p_int2{ii, 1}(curr_layer(2)), 'marker', '^')
            end
            if ishandle(p_int2{ii, 2}(curr_layer(1)))
                set(p_int2{ii, 2}(curr_layer(1)), 'marker', '^')
            end
        end
        
        set(status_box(2), 'string', ['Intersecting transect layer #' num2str(curr_layer(2)) ' matched to master transect layer #' num2str(curr_layer(1)) '.'])
        set(fgui(1), 'keypressfcn', @keypress1)
        set(fgui(2), 'keypressfcn', @keypress2, 'windowbuttondownfcn', @mouse_click)
    end

%% Unmatch two intersecting layers

    function pk_unmatch(source, eventdata)
        
        set(fgui, 'keypressfcn', '', 'windowbuttondownfcn', '')
        curr_gui            = 2;
        
        if ~all(pk_done)
            set(status_box(2), 'string', 'Picks must be loaded for both master and intersecting transects.')
            set(fgui(1), 'keypressfcn', @keypress1)
            set(fgui(2), 'keypressfcn', @keypress2, 'windowbuttondownfcn', @mouse_click)
            return
        end
        
        set(status_box(2), 'string', 'Unmatch current pair? (Y: yes; otherwise: cancel)...')
        waitforbuttonpress
        
        if ~strcmpi(get(fgui(2), 'currentcharacter'), 'Y')
            set(status_box(2), 'string', 'Unmatching cancelled.')
            set(fgui(1), 'keypressfcn', @keypress1)
            set(fgui(2), 'keypressfcn', @keypress2, 'windowbuttondownfcn', @mouse_click)
            return
        end
        
        set(status_box(2), 'string', ['Unmatching master transect layer #' num2str(curr_layer(1)) ' from intersecting transect layer # ' num2str(curr_layer(2)) '...'])
        pause(0.1)
        
        if (~isempty(find(ismember(ind_layer{1}(:, [1 5]), [curr_layer(1) curr_layer(2)], 'rows'), 1)) && ~isempty(find(ismember(ind_layer{2}(:, [1 5]), [curr_layer(2) curr_layer(1)], 'rows'), 1)))
            ind_layer{1} = ind_layer{1}(setdiff(1:size(ind_layer{1}, 1), find(((ind_layer{1}(:, 1) == curr_layer(1)) & (ind_layer{1}(:, 5) == curr_layer(2))))), :);
            ind_layer{2} = ind_layer{2}(setdiff(1:size(ind_layer{2}, 1), find(((ind_layer{2}(:, 1) == curr_layer(2)) & (ind_layer{2}(:, 5) == curr_layer(1))))), :);
        else
            set(status_box(2), 'string', 'Current layer pair not matched. Unmatching cancelled.')
            set(fgui(1), 'keypressfcn', @keypress1)
            set(fgui(2), 'keypressfcn', @keypress2, 'windowbuttondownfcn', @mouse_click)
            return
        end
        
        for ii = 1:2
            if ishandle(p_pk{ii, 2}(curr_layer(2)))
                set(p_pk{ii, 2}(curr_layer(2)), 'color', colors{2}(curr_layer(2), :))
            end
            if ishandle(p_int2{ii, 1}(curr_layer(2)))
                set(p_int2{ii, 1}(curr_layer(2)), 'markerfacecolor', colors{2}(curr_layer(2), :))
            end
            if ishandle(p_int2{ii, 2}(curr_layer(1)))
                set(p_int2{ii, 2}(curr_layer(1)), 'markerfacecolor', colors{1}(curr_layer(1), :))
            end
        end
        if ishandle(p_pkdepth{2}(curr_layer(2)))
            set(p_pkdepth{2}(curr_layer(2)), 'color', colors{2}(curr_layer(2), :))
        end
        
        if ~isempty(find((ind_layer{1}(:, 1) == curr_layer(1)), 1))
            for ii = 1:2
                if ishandle(p_int2{ii, 2}(curr_layer(1)))
                    set(p_int2{ii, 2}(curr_layer(1)), 'marker', 's')
                end
            end
        else
            for ii = 1:2
                if ishandle(p_int2{ii, 2}(curr_layer(1)))
                    set(p_int2{ii, 2}(curr_layer(1)), 'marker', 'o')
                end
            end
        end
        if isempty(find((ind_layer{1}(:, 5) == curr_layer(2)), 1))
            for ii = 1:2
                if ishandle(p_int2{ii, 2}(curr_layer(1)))
                    set(p_int2{ii, 2}(curr_layer(1)), 'marker', 'o')
                end
            end
        end
        if ~isempty(find((ind_layer{2}(:, 1) == curr_layer(2)), 1))
            for ii = 1:2
                if ishandle(p_int2{ii, 1}(curr_layer(2)))
                    set(p_int2{ii, 1}(curr_layer(2)), 'marker', 's')
                end
            end
        else
            for ii = 1:2
                if ishandle(p_int2{ii, 1}(curr_layer(2)))
                    set(p_int2{ii, 1}(curr_layer(2)), 'marker', 'o')
                end
            end
        end
        if isempty(find((ind_layer{2}(:, 5) == curr_layer(1)), 1))
            for ii = 1:2
                if ishandle(p_int2{ii, 1}(curr_layer(2)))
                    set(p_int2{ii, 1}(curr_layer(2)), 'marker', 'o')
                end
            end
        end
        
        set(status_box(2), 'string', ['Intersecting layer # ' num2str(curr_layer(2)) ' unmatched from master layer #' num2str(curr_layer(1)) '.'])
        set(fgui(1), 'keypressfcn', @keypress1)
        set(fgui(2), 'keypressfcn', @keypress2, 'windowbuttondownfcn', @mouse_click)
    end

%% Save merged picks

    function pk_save(source, eventdata)
        
        set(fgui, 'keypressfcn', '', 'windowbuttondownfcn', '')
        
        [curr_gui, curr_ax, curr_rad, curr_rad_alt] ...
                            = deal(1, 1, 2, 1);
        
        % want everything done before saving
        if ~all(pk_done)
            set(status_box(1), 'string', 'Intersecting picks not loaded yet.')
            set(fgui(1), 'keypressfcn', @keypress1)
            set(fgui(2), 'keypressfcn', @keypress2, 'windowbuttondownfcn', @mouse_click)
            return
        end
        
        if (~ischar(file_pk{1}) || ~ischar(file_pk{2}))
            [file_pk{1}, path_pk{1}, file_pk{2}, path_pk{2}] ...
                            = deal(tmp1, tmp2, tmp3, tmp4);
            set(status_box(1), 'string', 'Picks'' locations not all assigned. Saving cancelled.')
            set(fgui(1), 'keypressfcn', @keypress1)
            set(fgui(2), 'keypressfcn', @keypress2, 'windowbuttondownfcn', @mouse_click)
            return
        end
        
        set(status_box(1), 'string', 'Preparing matches for saving...')
        pause(0.1)
        
        % remove earlier set for these sub-transects
        ind_layer_match     = ind_layer_match((~ismember(ind_layer_match(:, 1:3), [curr_year(1) curr_trans(1) curr_subtrans(1)], 'rows') & ~ismember(ind_layer_match(:, 5:7), [curr_year(1) curr_trans(1) curr_subtrans(1)], 'rows') & ...
                                               ~ismember(ind_layer_match(:, 1:3), [curr_year(2) curr_trans(2) curr_subtrans(2)], 'rows') & ~ismember(ind_layer_match(:, 5:7), [curr_year(2) curr_trans(2) curr_subtrans(2)], 'rows')), :);
        
        % add new match set for these sub-transects, then reorder and remove any repeated rows
        ind_layer_match     = [ind_layer_match; repmat([curr_year(1) curr_trans(1) curr_subtrans(1)], size(ind_layer{1}, 1), 1) ind_layer{1}; repmat([curr_year(2) curr_trans(2) curr_subtrans(2)], size(ind_layer{2}, 1), 1) ind_layer{2}];
        
        for ii = 1:size(ind_layer_match, 1)
            if ((ind_layer_match(ii, 1) > ind_layer_match(ii, 5)) || ((ind_layer_match(ii, 1) == ind_layer_match(ii, 5)) && (ind_layer_match(ii, 2) > ind_layer_match(ii, 6))) || ...
               ((ind_layer_match(ii, 1) == ind_layer_match(ii, 5)) && (ind_layer_match(ii, 2) == ind_layer_match(ii, 6)) && (ind_layer_match(ii, 3) > ind_layer_match(ii, 7))) || ...
               ((ind_layer_match(ii, 1) == ind_layer_match(ii, 5)) && (ind_layer_match(ii, 2) == ind_layer_match(ii, 6)) && (ind_layer_match(ii, 3) == ind_layer_match(ii, 7)) && (ind_layer_match(ii, 4) > ind_layer_match(ii, 8))))
                 ind_layer_match(ii, :) ...
                            = ind_layer_match(ii, [5:8 1:4]);
            end
        end
        ind_layer_match     = unique(ind_layer_match, 'rows');
        ind_layer_match     = sortrows(ind_layer_match, [1:3 5:7 4 8]);
        
        set(status_box(1), 'string', 'Saving master layer ID list...')
        pause(0.1)
        try
            save([path_match file_match], '-v7.3', 'ind_layer_match')
            set(status_box(1), 'string', ['Saved matching layer list as ' file_match ' in ' path_match '. Saving complete.'])
        catch
            set(status_box(1), 'string', 'MATCHING LAYER LIST DID NOT SAVE. Try saving again shortly. Do not perform any other operation.')
            set(fgui(1), 'keypressfcn', @keypress1)
            set(fgui(2), 'keypressfcn', @keypress2, 'windowbuttondownfcn', @mouse_click)
            return
        end
        
        % move on to next intersecting file
        if (get(int_list, 'value') < length(get(int_list, 'string')))
            set(int_list, 'value', (get(int_list, 'value') + 1))
            load_pk2
        else
            set(fgui(1), 'keypressfcn', @keypress1)
            set(fgui(2), 'keypressfcn', @keypress2, 'windowbuttondownfcn', @mouse_click)
        end
    end

%% Update minimum dB/x/y/z/dist

    function slide_db_min1(source, eventdata)
        [curr_gui, curr_ax, curr_rad, curr_rad_alt] ...
                            = deal(1, 1, 1, 2);
        slide_db_min
    end

    function slide_db_min2(source, eventdata)
        [curr_gui, curr_ax, curr_rad, curr_rad_alt] ...
                            = deal(2, 2, 1, 2);
        slide_db_min
    end

    function slide_db_min3(source, eventdata)
        [curr_gui, curr_ax, curr_rad, curr_rad_alt] ...
                            = deal(2, 3, 2, 1);
        slide_db_min
    end

    function slide_db_min(source, eventdata)
        if (get(cb_min_slide(curr_ax), 'value') < db_max(curr_ax))
            if get(cbfix_check1(curr_ax), 'value')
                tmp1        = db_max(curr_ax) - db_min(curr_ax);
            end
            db_min(curr_ax) = get(cb_min_slide(curr_ax), 'value');
            if get(cbfix_check1(curr_ax), 'value')
                db_max(curr_ax) = db_min(curr_ax) + tmp1;
                if (db_max(curr_ax) > db_max_ref(curr_ax))
                    db_max(curr_ax) = db_max_ref(curr_ax);
                    db_min(curr_ax) = db_max(curr_ax) - tmp1;
                    if (db_min(curr_ax) < db_min_ref(curr_ax))
                        db_min(curr_ax) = db_min_ref(curr_ax);
                    end
                    if (db_min(curr_ax) < get(cb_min_slide(curr_ax), 'min'))
                        set(cb_min_slide(curr_ax), 'value', get(cb_min_slide(curr_ax), 'min'))
                    else
                        set(cb_min_slide(curr_ax), 'value', db_min(curr_ax))
                    end
                end
                set(cb_max_edit(curr_ax), 'string', sprintf('%3.0f', db_max(curr_ax)))
                if (db_max(curr_ax) > get(cb_max_slide(curr_ax), 'max'))
                    set(cb_max_slide(curr_ax), 'value', get(cb_max_slide(curr_ax), 'max'))
                else
                    set(cb_max_slide(curr_ax), 'value', db_max(curr_ax))
                end
            end
            set(cb_min_edit(curr_ax), 'string', sprintf('%3.0f', db_min(curr_ax)))
            update_db_range
        else
            if (db_min(curr_ax) < get(cb_min_slide(curr_ax), 'min'))
                set(cb_min_slide(curr_ax), 'value', get(cb_min_slide(curr_ax), 'min'))
            else
                set(cb_min_slide(curr_ax), 'value', db_min(curr_ax))
            end
        end
        set(cb_min_slide(curr_ax), 'enable', 'off')
        drawnow
        set(cb_min_slide(curr_ax), 'enable', 'on')
    end

    function slide_dist_min1(source, eventdata)
        [curr_gui, curr_ax, curr_rad, curr_rad_alt] ...
                            = deal(2, 2, 1, 2);
        slide_dist_min
    end

    function slide_dist_min2(source, eventdata)
        [curr_gui, curr_ax, curr_rad, curr_rad_alt] ...
                            = deal(2, 3, 2, 1);
        slide_dist_min
    end

    function slide_dist_min(source, eventdata)
        if (get(dist_min_slide(curr_rad), 'value') < dist_max(curr_rad))
            if get(distfix_check(curr_rad), 'value')
                tmp1        = dist_max(curr_rad) - dist_min(curr_rad);
            end
            dist_min(curr_rad) = get(dist_min_slide(curr_rad), 'value');
            if get(distfix_check(curr_rad), 'value')
                dist_max(curr_rad) = dist_min(curr_rad) + tmp1;
                if (dist_max(curr_rad) > dist_max_ref(curr_rad))
                    dist_max(curr_rad) = dist_max_ref(curr_rad);
                    dist_min(curr_rad) = dist_max(curr_rad) - tmp1;
                    if (dist_min(curr_rad) < dist_min_ref(curr_rad))
                        dist_min(curr_rad) = dist_min_ref(curr_rad);
                    end
                    if (dist_min(curr_rad) < get(dist_min_slide(curr_rad), 'min'))
                        set(dist_min_slide(curr_rad), 'value', get(dist_min_slide(curr_rad), 'min'))
                    else
                        set(dist_min_slide(curr_rad), 'value', dist_min(curr_rad))
                    end
                end
                set(dist_max_edit(curr_rad), 'string', sprintf('%3.0f', dist_max(curr_rad)))
                if (dist_max(curr_rad) > get(dist_max_slide(curr_rad), 'max'))
                    set(dist_max_slide(curr_rad), 'value', get(dist_max_slide(curr_rad), 'max'))
                else
                    set(dist_max_slide(curr_rad), 'value', dist_max(curr_rad))
                end
            end
            set(dist_min_edit(curr_rad), 'string', sprintf('%3.0f', dist_min(curr_rad)))
            update_dist_range
        else
            if (dist_min(curr_rad) < get(dist_min_slide(curr_rad), 'min'))
                set(dist_min_slide(curr_rad), 'value', get(dist_min_slide(curr_rad), 'min'))
            else
                set(dist_min_slide(curr_rad), 'value', dist_min(curr_rad))
            end
        end
        set(dist_min_slide(curr_rad), 'enable', 'off')
        drawnow
        set(dist_min_slide(curr_rad), 'enable', 'on')
    end

    function slide_x_min(source, eventdata)
        [curr_gui, curr_ax] = deal(1);
        if (get(x_min_slide, 'value') < x_max)
            if get(xfix_check, 'value')
                tmp1        = x_max - x_min;
            end
            x_min           = get(x_min_slide, 'value');
            if get(xfix_check, 'value')
                x_max       = x_min + tmp1;
                if (x_max > x_max_ref)
                    x_max   = x_max_ref;
                    x_min   = x_max - tmp1;
                    if (x_min < x_min_ref)
                        x_min = x_min_ref;
                    end
                    if (x_min < get(x_min_slide, 'min'))
                        set(x_min_slide, 'value', get(x_min_slide, 'min'))
                    else
                        set(x_min_slide, 'value', x_min)
                    end
                end
                if (x_max > get(x_max_slide, 'max'))
                    set(x_max_slide, 'value', get(x_max_slide, 'max'))
                else
                    set(x_max_slide, 'value', x_max)
                end
                set(x_max_edit, 'string', sprintf('%4.1f', x_max))
            end
            set(x_min_edit, 'string', sprintf('%4.1f', x_min))
            update_x_range
        else
            if (x_min < get(x_min_slide, 'min'))
                set(x_min_slide, 'value', get(x_min_slide, 'min'))
            else
                set(x_min_slide, 'value', x_min)
            end
        end
        set(x_min_slide, 'enable', 'off')
        drawnow
        set(x_min_slide, 'enable', 'on')
    end

    function slide_y_min(source, eventdata)
        [curr_gui, curr_ax] = deal(1);
        if (get(y_min_slide, 'value') < y_max)
            if get(yfix_check, 'value')
                tmp1        = y_max - y_min;
            end
            y_min           = get(y_min_slide, 'value');
            if get(yfix_check, 'value')
                y_max       = y_min + tmp1;
                if (y_max > y_max_ref)
                    y_max   = y_max_ref;
                    y_min   = y_max - tmp1;
                    if (y_min < y_min_ref)
                        y_min = y_min_ref;
                    end
                    if (y_min < get(y_min_slide, 'min'))
                        set(y_min_slide, 'value', get(y_min_slide, 'min'))
                    else
                        set(y_min_slide, 'value', y_min)
                    end
                end
                if (y_max > get(y_max_slide, 'max'))
                    set(y_max_slide, 'value', get(y_max_slide, 'max'))
                else
                    set(y_max_slide, 'value', y_max)
                end
                set(y_max_edit, 'string', sprintf('%4.1f', y_max))
            end
            set(y_min_edit, 'string', sprintf('%4.1f', y_min))
            update_y_range
        else
            if (y_min < get(y_min_slide, 'min'))
                set(y_min_slide, 'value', get(y_min_slide, 'min'))
            else
                set(y_min_slide, 'value', y_min)
            end
        end
        set(y_min_slide, 'enable', 'off')
        drawnow
        set(y_min_slide, 'enable', 'on')
    end

    function slide_z_min1(source, eventdata)
        [curr_gui, curr_ax] = deal(1);
        slide_z_min
    end

    function slide_z_min2(source, eventdata)
        [curr_gui, curr_ax, curr_rad, curr_rad_alt] ...
                            = deal(2, 2, 1, 2);
        slide_z_min
    end

    function slide_z_min(source, eventdata)
        if ((curr_gui == 1) || strcmp(disp_type, 'elev.'))
            if (get(z_min_slide(curr_gui), 'value') < elev_max(curr_gui))
                if get(zfix_check(curr_gui), 'value')
                    tmp1    = elev_max(curr_gui) - elev_min(curr_gui);
                end
                elev_min(curr_gui) = get(z_min_slide(curr_gui), 'value');
                if get(zfix_check(curr_gui), 'value')
                    elev_max(curr_gui) = elev_min(curr_gui) + tmp1;
                    if (elev_max(curr_gui) > elev_max_ref)
                        elev_max(curr_gui) = elev_max_ref;
                        elev_min(curr_gui) = elev_max(curr_gui) - tmp1;
                        if (elev_min(curr_gui) < elev_min_ref)
                            elev_min(curr_gui) = elev_min_ref;
                        end
                        if (elev_min(curr_gui) < get(z_min_slide(curr_gui), 'min'))
                            set(z_min_slide(curr_gui), 'value', get(z_min_slide(curr_gui), 'min'))
                        else
                            set(z_min_slide(curr_gui), 'value', elev_min(curr_gui))
                        end
                    end
                    set(z_max_edit(curr_gui), 'string', sprintf('%4.0f', elev_max(curr_gui)))
                    if (elev_max(curr_gui) > get(z_max_slide(curr_gui), 'max'))
                        set(z_max_slide(curr_gui), 'value', get(z_max_slide(curr_gui), 'max'))
                    else
                        set(z_max_slide(curr_gui), 'value', elev_max(curr_gui))
                    end
                end
                set(z_min_edit(curr_gui), 'string', sprintf('%4.0f', elev_min(curr_gui)))
                update_z_range
            else
                if (elev_min(curr_gui) < get(z_min_slide(curr_gui), 'min'))
                    set(z_min_slide(curr_gui), 'value', get(z_min_slide(curr_gui), 'min'))
                else
                    set(z_min_slide(curr_gui), 'value', elev_min(curr_gui))
                end
            end
        elseif((depth_max_ref - (get(z_min_slide(curr_gui), 'value') - depth_min_ref)) > depth_min)
            if get(zfix_check(curr_gui), 'value')
                tmp1        = depth_max - depth_min;
            end
            depth_max = depth_max_ref - (get(z_min_slide(curr_gui), 'value') - depth_min_ref);
            if get(zfix_check(curr_gui), 'value')
                depth_min = depth_max - tmp1;
                if (depth_min < depth_min_ref)
                    depth_min = depth_min_ref;
                    depth_max = depth_min + tmp1;
                    if (depth_max > depth_max_ref)
                        depth_max = depth_max_ref;
                    end
                    if ((depth_max_ref - (depth_max - depth_min_ref)) < get(z_min_slide(curr_gui), 'min'))
                        set(z_min_slide(curr_gui), 'value', get(z_min_slide(curr_gui), 'min'))
                    elseif ((depth_max_ref - (depth_max - depth_min_ref)) > get(z_min_slide(curr_gui), 'max'))
                        set(z_min_slide(curr_gui), 'value', get(z_min_slide(curr_gui), 'max'))
                    else
                        set(z_min_slide(curr_gui), 'value', (depth_max_ref - (depth_max - depth_min_ref)))
                    end
                end
                set(z_min_edit(curr_gui), 'string', sprintf('%4.0f', depth_max))
                if ((depth_max_ref - (depth_min - depth_min_ref)) < get(z_max_slide(curr_gui), 'min'))
                    set(z_max_slide(curr_gui), 'value', get(z_max_slide(curr_gui), 'min'))
                elseif ((depth_max_ref - (depth_min - depth_min_ref)) > get(z_max_slide(curr_gui), 'max'))
                    set(z_max_slide(curr_gui), 'value', get(z_max_slide(curr_gui), 'max'))
                else
                    set(z_max_slide(curr_gui), 'value', (depth_max_ref - (depth_min - depth_min_ref)))
                end
            end
            set(z_min_edit(curr_gui), 'string', sprintf('%4.0f', depth_max))
            update_z_range
        else
            if ((depth_max_ref - (depth_max - depth_min_ref)) < get(z_min_slide(curr_gui), 'min'))
                set(z_min_slide(curr_gui), 'value', get(z_min_slide(curr_gui), 'min'))
            elseif ((depth_max_ref - (depth_max - depth_min_ref)) > get(z_min_slide(curr_gui), 'max'))
                set(z_min_slide(curr_gui), 'value', get(z_min_slide(curr_gui), 'max'))
            else
                set(z_min_slide(curr_gui), 'value', (depth_max_ref - (depth_max - depth_min_ref)))
            end
        end
        set(z_min_slide(curr_gui), 'enable', 'off')
        drawnow
        set(z_min_slide(curr_gui), 'enable', 'on')
    end

%% Update maximum dB/x/y/z/dist

    function slide_db_max1(source, eventdata)
        [curr_gui, curr_ax, curr_rad, curr_rad_alt] ...
                            = deal(1, 1, 1, 2);
        slide_db_max
    end

    function slide_db_max2(source, eventdata)
        [curr_gui, curr_ax, curr_rad, curr_rad_alt] ...
                            = deal(2, 2, 1, 2);
        slide_db_max
    end

    function slide_db_max3(source, eventdata)
        [curr_gui, curr_ax, curr_rad, curr_rad_alt] ...
                            = deal(2, 3, 2, 1);
        slide_db_max
    end

    function slide_db_max(source, eventdata)
        if (get(cb_max_slide(curr_ax), 'value') > db_min(curr_ax))
            if get(cbfix_check1(curr_ax), 'value')
                tmp1        = db_max(curr_ax) - db_min(curr_ax);
            end
            db_max(curr_ax) = get(cb_max_slide(curr_ax), 'value');
            if get(cbfix_check1(curr_ax), 'value')
                db_min(curr_ax) = db_max(curr_ax) - tmp1;
                if (db_min(curr_ax) < db_min_ref(curr_ax))
                    db_min(curr_ax) = db_min_ref(curr_ax);
                    db_max(curr_ax) = db_min(curr_ax) + tmp1;
                    if (db_max(curr_ax) > db_max_ref(curr_ax))
                        db_max(curr_ax) = db_max_ref(curr_ax);
                    end
                    if (db_max(curr_ax) > get(cb_max_slide(curr_ax), 'max'))
                        set(cb_max_slide(curr_ax), 'value', get(cb_max_slide(curr_ax), 'max'))
                    else
                        set(cb_max_slide(curr_ax), 'value', db_max(curr_ax))
                    end
                end
                set(cb_min_edit(curr_ax), 'string', sprintf('%3.0f', db_min(curr_ax)))
                if (db_min(curr_ax) < get(cb_min_slide(curr_ax), 'min'))
                    set(cb_min_slide(curr_ax), 'value', get(cb_min_slide(curr_ax), 'min'))
                else
                    set(cb_min_slide(curr_ax), 'value', db_min(curr_ax))
                end
            end
            set(cb_max_edit(curr_ax), 'string', sprintf('%3.0f', db_max(curr_ax)))
            update_db_range
        else
            if (db_max(curr_ax) > get(cb_max_slide(curr_ax), 'max'))
                set(cb_max_slide(curr_ax), 'value', get(cb_max_slide(curr_ax), 'max'))
            else
                set(cb_max_slide(curr_ax), 'value', db_max(curr_ax))
            end
        end
        set(cb_max_slide(curr_ax), 'enable', 'off')
        drawnow
        set(cb_max_slide(curr_ax), 'enable', 'on')
    end

    function slide_dist_max1(source, eventdata)
        [curr_gui, curr_ax, curr_rad, curr_rad_alt] ...
                            = deal(2, 2, 1, 2);
        slide_dist_max
    end

    function slide_dist_max2(source, eventdata)
        [curr_gui, curr_ax, curr_rad, curr_rad_alt] ...
                            = deal(2, 3, 2, 1);
        slide_dist_max
    end

    function slide_dist_max(source, eventdata)
        if (get(dist_max_slide(curr_rad), 'value') > dist_min(curr_rad))
            if get(distfix_check(curr_rad), 'value')
                tmp1        = dist_max(curr_rad) - dist_min(curr_rad);
            end
            dist_max(curr_rad) = get(dist_max_slide(curr_rad), 'value');
            if get(distfix_check(curr_rad), 'value')
                dist_min(curr_rad) = dist_max(curr_rad) - tmp1;
                if (dist_min(curr_rad) < dist_min_ref(curr_rad))
                    dist_min(curr_rad) = dist_min_ref(curr_rad);
                    dist_max(curr_rad) = dist_min(curr_rad) + tmp1;
                    if (dist_max(curr_rad) > dist_max_ref(curr_rad))
                        dist_max(curr_rad) = dist_max_ref(curr_rad);
                    end
                    if (dist_max(curr_rad) > get(dist_max_slide(curr_rad), 'max'))
                        set(dist_max_slide(curr_rad), 'value', get(dist_max_slide(curr_rad), 'max'))
                    else
                        set(dist_max_slide(curr_rad), 'value', dist_max(curr_rad))
                    end
                end
                set(dist_min_edit(curr_rad), 'string', sprintf('%3.0f', dist_min(curr_rad)))
                if (dist_min(curr_rad) < get(dist_min_slide(curr_rad), 'min'))
                    set(dist_min_slide(curr_rad), 'value', get(dist_min_slide(curr_rad), 'min'))
                else
                    set(dist_min_slide(curr_rad), 'value', dist_min(curr_rad))
                end
            end
            set(dist_max_edit(curr_rad), 'string', sprintf('%3.0f', dist_max(curr_rad)))
            update_dist_range
        else
            if (dist_max(curr_rad) > get(dist_max_slide(curr_rad), 'max'))
                set(dist_max_slide(curr_rad), 'value', get(dist_max_slide(curr_rad), 'max'))
            else
                set(dist_max_slide(curr_rad), 'value', dist_max(curr_rad))
            end
        end
        set(dist_max_slide(curr_rad), 'enable', 'off')
        drawnow
        set(dist_max_slide(curr_rad), 'enable', 'on')
    end

    function slide_x_max(source, eventdata)
        [curr_gui, curr_ax] = deal(1);
        if (get(x_max_slide, 'value') > x_min)
            if get(xfix_check, 'value')
                tmp1        = x_max - x_min;
            end
            x_max           = get(x_max_slide, 'value');
            if get(xfix_check, 'value')
                x_min       = x_max - tmp1;
                if (x_min < x_min_ref)
                    x_min   = x_min_ref;
                    x_max   = x_min + tmp1;
                    if (x_max > x_max_ref)
                        x_max = x_max_ref;
                    end
                    if (x_max > get(x_max_slide, 'max'))
                        set(x_max_slide, 'value', get(x_max_slide, 'max'))
                    else
                        set(x_max_slide, 'value', x_max)
                    end
                end
                if (x_min < get(x_min_slide, 'min'))
                    set(x_min_slide, 'value', get(x_min_slide, 'min'))
                else
                    set(x_min_slide, 'value', x_min)
                end
                set(x_min_edit, 'string', sprintf('%4.1f', x_min))
            end
            set(x_max_edit, 'string', sprintf('%4.1f', x_max))
            update_x_range
        else
            if (x_max > get(x_max_slide, 'max'))
                set(x_max_slide, 'value', get(x_max_slide, 'max'))
            else
                set(x_max_slide, 'value', x_max)
            end
        end
        set(x_max_slide, 'enable', 'off')
        drawnow
        set(x_max_slide, 'enable', 'on')
    end

    function slide_y_max(source, eventdata)
        [curr_gui, curr_ax] = deal(1);
        if (get(y_max_slide, 'value') > y_min)
            if get(yfix_check, 'value')
                tmp1        = y_max - y_min;
            end
            y_max           = get(y_max_slide, 'value');
            if get(yfix_check, 'value')
                y_min       = y_max - tmp1;
                if (y_min < y_min_ref)
                    y_min   = y_min_ref;
                    y_max   = y_min + tmp1;
                    if (y_max > y_max_ref)
                        y_max = y_max_ref;
                    end
                    if (y_max > get(y_max_slide, 'max'))
                        set(y_max_slide, 'value', get(y_max_slide, 'max'))
                    else
                        set(y_max_slide, 'value', y_max)
                    end
                end
                if (y_min < get(y_min_slide, 'min'))
                    set(y_min_slide, 'value', get(y_min_slide, 'min'))
                else
                    set(y_min_slide, 'value', y_min)
                end
                set(y_min_edit, 'string', sprintf('%4.1f', y_min))
            end
            set(y_max_edit, 'string', sprintf('%4.1f', y_max))
            update_y_range
        else
            if (y_max > get(y_max_slide, 'max'))
                set(y_max_slide, 'value', get(y_max_slide, 'max'))
            else
                set(y_max_slide, 'value', y_max)
            end
        end
        set(y_max_slide, 'enable', 'off')
        drawnow
        set(y_max_slide, 'enable', 'on')
    end

    function slide_z_max1(source, eventdata)
        [curr_gui, curr_ax] = deal(1);
        slide_z_max
    end

    function slide_z_max2(source, eventdata)
        [curr_gui, curr_ax, curr_rad, curr_rad_alt] ...
                            = deal(2, 2, 1, 2);
        slide_z_max
    end

    function slide_z_max(source, eventdata)
        if ((curr_gui == 1) || strcmp(disp_type, 'elev.'))
            if (get(z_max_slide(curr_gui), 'value') > elev_min(curr_gui))
                if get(zfix_check(curr_gui), 'value')
                    tmp1    = elev_max(curr_gui) - elev_min(curr_gui);
                end
                elev_max(curr_gui) = get(z_max_slide(curr_gui), 'value');
                if get(zfix_check(curr_gui), 'value')
                    elev_min(curr_gui) = elev_max(curr_gui) - tmp1;
                    if (elev_min(curr_gui) < elev_min_ref)
                        elev_min(curr_gui) = elev_min_ref;
                        elev_max(curr_gui) = elev_min(curr_gui) + tmp1;
                        if (elev_max(curr_gui) > get(z_max_slide(curr_gui), 'max'))
                            set(z_max_slide(curr_gui), 'value', get(z_max_slide(curr_gui), 'max'))
                        else
                            set(z_max_slide(curr_gui), 'value', elev_max(curr_gui))
                        end
                    end
                    set(z_min_edit(curr_gui), 'string', sprintf('%4.0f', elev_min(curr_gui)))
                    if (elev_min(curr_gui) < get(z_min_slide(curr_gui), 'min'))
                        set(z_min_slide(curr_gui), 'value', get(z_min_slide(curr_gui), 'min'))
                    else
                        set(z_min_slide(curr_gui), 'value', elev_min(curr_gui))
                    end
                end
                set(z_max_edit(curr_gui), 'string', sprintf('%4.0f', elev_max(curr_gui)))
                update_z_range
            else
                if (elev_max(curr_gui) > get(z_max_slide(curr_gui), 'max'))
                    set(z_max_slide(curr_gui), 'value', get(z_max_slide(curr_gui), 'max'))
                else
                    set(z_max_slide(curr_gui), 'value', elev_max(curr_gui))
                end
            end
        elseif ((depth_max_ref - (get(z_max_slide(curr_gui), 'value') - depth_min_ref)) < depth_max)
            if get(zfix_check(curr_gui), 'value')
                tmp1        = depth_max - depth_min;
            end
            depth_min = depth_max_ref - (get(z_max_slide(curr_gui), 'value') - depth_min_ref);
            if get(zfix_check(curr_gui), 'value')
                depth_max = depth_min + tmp1;
                if (depth_max > depth_max_ref)
                    depth_max = depth_max_ref;
                    depth_min = depth_max - tmp1;
                    if (depth_min < depth_min_ref)
                        depth_min = depth_min_ref;
                    end
                    if ((depth_max_ref - (depth_min - depth_min_ref)) < get(z_max_slide(curr_gui), 'min'))
                        set(z_max_slide(curr_gui), 'value', get(z_max_slide(curr_gui), 'min'))
                    elseif ((depth_max_ref - (depth_min - depth_min_ref)) > get(z_max_slide(curr_gui), 'max'))
                        set(z_max_slide(curr_gui), 'value', get(z_max_slide(curr_gui), 'max'))
                    else
                        set(z_max_slide(curr_gui), 'value', (depth_max_ref - (depth_min - depth_min_ref)))
                    end
                end
                set(z_min_edit(curr_gui), 'string', sprintf('%4.0f', depth_max))
                if ((depth_max_ref - (depth_max - depth_min_ref)) < get(z_min_slide, 'min'))
                    set(z_min_slide(curr_gui), 'value', get(z_min_slide(curr_gui), 'min'))
                elseif ((depth_max_ref - (depth_max - depth_min_ref)) > get(z_min_slide, 'max'))
                    set(z_min_slide(curr_gui), 'value', get(z_min_slide(curr_gui), 'max'))
                else
                    set(z_min_slide(curr_gui), 'value', (depth_max_ref - (depth_max - depth_min_ref)))
                end
            end
            set(z_max_edit(curr_gui), 'string', sprintf('%4.0f', depth_min))
            update_z_range
        else
            if ((depth_max_ref - (depth_min - depth_min_ref)) < get(z_max_slide(curr_gui), 'min'))
                set(z_max_slide(curr_gui), 'value', get(z_max_slide(curr_gui), 'min'))
            elseif ((depth_max_ref - (depth_min - depth_min_ref)) > get(z_max_slide(curr_gui), 'max'))
                set(z_max_slide(curr_gui), 'value', get(z_max_slide(curr_gui), 'max'))
            else
                set(z_max_slide(curr_gui), 'value', (depth_max_ref - (depth_min - depth_min_ref)))
            end
        end
        set(z_max_slide(curr_gui), 'enable', 'off')
        drawnow
        set(z_max_slide(curr_gui), 'enable', 'on')
    end

%% Reset minimum dB/x/y/z/dist

    function reset_db_min1(source, eventdata)
        [curr_gui, curr_ax] = deal(1, 1, 1, 2);
        reset_db_min
    end

    function reset_db_min2(source, eventdata)
        [curr_gui, curr_ax, curr_rad, curr_rad_alt] ...
                            = deal(2, 2, 1, 2);
        set(rad_group, 'selectedobject', rad_check(curr_rad))
        reset_db_min
    end

    function reset_db_min3(source, eventdata)
        [curr_gui, curr_ax, curr_rad, curr_rad_alt] ...
                            = deal(2, 3, 2, 1);
        set(rad_group, 'selectedobject', rad_check(curr_rad))
        reset_db_min
    end

    function reset_db_min(source, eventdata)
        if (db_min_ref(curr_ax) < get(cb_min_slide(curr_ax), 'min'))
            set(cb_min_slide(curr_ax), 'value', get(cb_min_slide(curr_ax), 'min'))
        else
            set(cb_min_slide(curr_ax), 'value', db_min_ref(curr_ax))
        end
        set(cb_min_edit(curr_ax), 'string', num2str(db_min_ref(curr_ax)))
        db_min(curr_ax)     = db_min_ref(curr_ax);
        update_db_range
    end

    function reset_dist_min1(source, eventdata)
        [curr_gui, curr_ax, curr_rad, curr_rad_alt] ...
                            = deal(2, 2, 1, 2);
        reset_dist_min
    end

    function reset_dist_min2(source, eventdata)
        [curr_gui, curr_ax, curr_rad, curr_rad_alt] ...
                            = deal(2, 3, 2, 1);
        reset_dist_min
    end

    function reset_dist_min(source, eventdata)
        if (dist_min_ref(curr_rad) < get(dist_min_slide(curr_rad), 'min'))
            set(dist_min_slide(curr_rad), 'value', get(dist_min_slide(curr_rad), 'min'))
        else
            set(dist_min_slide(curr_rad), 'value', dist_min_ref(curr_rad))
        end
        set(dist_min_edit(curr_rad), 'string', sprintf('%3.1f', dist_min_ref(curr_rad)))
        dist_min(curr_rad)  = dist_min_ref(curr_rad);
        update_dist_range
    end

    function reset_x_min(source, eventdata)
        [curr_gui, curr_ax] = deal(1);
        if (x_min_ref < get(x_min_slide, 'min'))
            set(x_min_slide, 'value', get(x_min_slide, 'min'))
        else
            set(x_min_slide, 'value', x_min_ref)
        end
        set(x_min_edit, 'string', sprintf('%4.1f', x_min_ref))
        x_min              = x_min_ref;
        update_x_range
    end

    function reset_y_min(source, eventdata)
        [curr_gui, curr_ax] = deal(1);
        if (y_min_ref < get(y_min_slide, 'min'))
            set(y_min_slide, 'value', get(y_min_slide, 'min'))
        else
            set(y_min_slide, 'value', y_min_ref)
        end
        set(y_min_edit, 'string', sprintf('%4.1f', y_min_ref))
        y_min              = y_min_ref;
        update_y_range
    end

    function reset_z_min1(source, eventdata)
        [curr_gui, curr_ax] = deal(1);
        reset_z_min
    end

    function reset_z_min2(source, eventdata)
        [curr_gui, curr_ax, curr_rad, curr_rad_alt] ...
                            = deal(2, 2, 1, 2);
        reset_z_min
    end

    function reset_z_min(source, eventdata)
        elev_min(curr_gui)   = elev_min_ref;
        switch curr_gui
            case 1
                if (elev_min_ref < get(z_min_slide(curr_gui), 'min'))
                    set(z_min_slide(curr_gui), 'value', get(z_min_slide(curr_gui), 'min'))
                else
                    set(z_min_slide(curr_gui), 'value', elev_min_ref)
                end
                set(z_min_edit(curr_gui), 'string', sprintf('%4.0f', elev_min_ref))
            case 2
                depth_max   = depth_max_ref;
                switch disp_type
                    case 'elev.'
                        elev_min(curr_gui) ...
                            = elev_min_ref;
                        if (elev_min_ref < get(z_min_slide(curr_gui), 'min'))
                            set(z_min_slide(curr_gui), 'value', get(z_min_slide(curr_gui), 'min'))
                        else
                            set(z_min_slide(curr_gui), 'value', elev_min_ref)
                        end
                        set(z_min_edit(curr_gui), 'string', sprintf('%4.0f', elev_min_ref))
                    case 'depth'
                        if (depth_min_ref < get(z_min_slide(curr_gui), 'min'))
                            set(z_min_slide(curr_gui), 'value', get(z_min_slide(curr_gui), 'min'))
                        elseif (depth_min_ref > get(z_min_slide(curr_gui), 'max'))
                            set(z_min_slide(curr_gui), 'value', get(z_min_slide(curr_gui), 'max'))
                        else
                            set(z_min_slide(curr_gui), 'value', depth_min_ref)
                        end
                        set(z_min_edit(curr_gui), 'string', sprintf('%4.0f', depth_max_ref))
                end
        end
        update_z_range
    end

%% Reset maximum dB/x/y/z

    function reset_db_max1(source, eventdata)
        [curr_gui, curr_ax, curr_rad, curr_rad_alt] ...
                            = deal(1, 1, 1, 2);
        reset_db_max
    end

    function reset_db_max2(source, eventdata)
        [curr_gui, curr_ax, curr_rad, curr_rad_alt] ...
                            = deal(2, 2, 1, 2);
        reset_db_max
    end

    function reset_db_max3(source, eventdata)
        [curr_gui, curr_ax, curr_rad, curr_rad_alt] ...
                            = deal(2, 3, 2, 1);
        reset_db_max
    end

    function reset_db_max(source, eventdata)
        if (db_max_ref(curr_ax) > get(cb_max_slide(curr_ax), 'max'))
            set(cb_max_slide(curr_ax), 'value', get(cb_max_slide(curr_ax), 'max'))
        else
            set(cb_max_slide(curr_ax), 'value', db_max_ref(curr_ax))
        end
        set(cb_max_edit(curr_ax), 'string', num2str(db_max_ref(curr_ax)))
        db_max(curr_ax)     = db_max_ref(curr_ax);
        update_db_range
    end

    function reset_dist_max1(source, eventdata)
        [curr_gui, curr_ax, curr_rad, curr_rad_alt] ...
                            = deal(2, 2, 1, 2);
        reset_dist_max
    end

    function reset_dist_max2(source, eventdata)
        [curr_gui, curr_ax, curr_rad, curr_rad_alt] ...
                            = deal(2, 3, 2, 1);
        reset_dist_max
    end

    function reset_dist_max(source, eventdata)
        if (dist_max_ref(curr_rad) > get(dist_max_slide(curr_rad), 'max'))
            set(dist_max_slide(curr_rad), 'value', get(dist_max_slide(curr_rad), 'max'))
        else
            set(dist_max_slide(curr_rad), 'value', dist_max_ref(curr_rad))
        end
        set(dist_max_edit(curr_rad), 'string', sprintf('%3.1f', dist_max_ref(curr_rad)))
        dist_max(curr_rad)  = dist_max_ref(curr_rad);
        update_dist_range
    end

    function reset_x_max(source, eventdata)
        [curr_gui, curr_ax] = deal(1);
        if (x_max_ref > get(x_max_slide, 'max'))
            set(x_max_slide, 'value', get(x_max_slide, 'max'))
        else
            set(x_max_slide, 'value', x_max_ref)
        end
        set(x_max_edit, 'string', sprintf('%4.1f', x_max_ref))
        x_max              = x_max_ref;
        update_x_range
    end

    function reset_y_max(source, eventdata)
        [curr_gui, curr_ax] = deal(1);
        if (y_max_ref > get(y_max_slide, 'max'))
            set(y_max_slide, 'value', get(y_max_slide, 'max'))
        else
            set(y_max_slide, 'value', y_max_ref)
        end
        set(y_max_edit, 'string', sprintf('%4.1f', y_max_ref))
        y_max              = y_max_ref;
        update_y_range
    end

    function reset_z_max1(source, eventdata)
        [curr_gui, curr_ax] = deal(1);
        reset_z_max
    end

    function reset_z_max2(source, eventdata)
        [curr_gui, curr_ax, curr_rad, curr_rad_alt] ...
                            = deal(2, 2, 1, 2);
        reset_z_max
    end

    function reset_z_max(source, eventdata)
        elev_max(curr_gui)   = elev_max_ref;
        switch curr_gui
            case 1                
                if (elev_max_ref > get(z_max_slide(curr_gui), 'max'))
                    set(z_max_slide(curr_gui), 'value', get(z_max_slide(curr_gui), 'max'))
                else
                    set(z_max_slide(curr_gui), 'value', elev_max_ref)
                end
                set(z_max_edit(curr_gui), 'string', sprintf('%4.0f', elev_max_ref))
            case 2
                depth_min   = depth_min_ref;
                switch disp_type
                    case 'elev.'
                        if (elev_max_ref > get(z_max_slide(curr_gui), 'max'))
                            set(z_max_slide(curr_gui), 'value', get(z_max_slide(curr_gui), 'max'))
                        else
                            set(z_max_slide(curr_gui), 'value', elev_max_ref)
                        end
                        set(z_max_edit(curr_gui), 'string', sprintf('%4.0f', elev_max_ref))
                    case 'depth'
                        if (depth_min_ref < get(z_min_slide(curr_gui), 'min'))
                            set(z_min_slide, 'value', get(z_min_slide(curr_gui), 'min'))
                        elseif (depth_min_ref > get(z_min_slide(curr_gui), 'max'))
                            set(z_min_slide(curr_gui), 'value', get(z_min_slide(curr_gui), 'max'))
                        else
                            set(z_min_slide(curr_gui), 'value', depth_min_ref)
                        end
                        set(z_min_edit(curr_gui), 'string', sprintf('%4.0f', depth_max_ref))
                end
        end
        update_z_range
    end

%% Reset all x/y/z

    function reset_xyz(source, eventdata)
        [curr_gui, curr_ax] = deal(1);
        reset_x_min
        reset_x_max
        reset_y_min
        reset_y_max
        reset_z_min
        reset_z_max
    end

    function reset_xz1(source, eventdata)
        [curr_gui, curr_ax, curr_rad, curr_rad_alt] ...
                            = deal(2, 2, 1, 2);
        reset_xz
    end

    function reset_xz2(source, eventdata)
        [curr_gui, curr_ax, curr_rad, curr_rad_alt] ...
                            = deal(2, 3, 2, 1);
        reset_xz
    end

    function reset_xz(source, eventdata)
        reset_dist_min
        reset_dist_max
        reset_z_min
        reset_z_max
    end

%% Update dB/x/y/z/elevation/depth range

    function update_db_range(source, eventdata)
        set(rad_group, 'selectedobject', rad_check(curr_rad))        
        axes(ax(curr_ax))
        caxis([db_min(curr_ax) db_max(curr_ax)])
    end

    function update_dist_range(source, eventdata)
        set(rad_group, 'selectedobject', rad_check(curr_rad))        
        axes(ax(curr_ax))
        xlim([dist_min(curr_rad) dist_max(curr_rad)])
        narrow_cb
    end

    function update_x_range(source, eventdata)
        axes(ax(curr_ax))
        xlim([x_min x_max])
        narrow_cb
    end

    function update_y_range(source, eventdata)
        axes(ax(curr_ax))
        ylim([y_min y_max])
        narrow_cb
    end

    function update_z_range(source, eventdata)
        set(rad_group, 'selectedobject', rad_check(curr_rad))
        axes(ax(curr_ax))
        if (curr_gui == 1)
            zlim([elev_min(curr_gui) elev_max(curr_gui)])
        else
            switch disp_type
                case 'elev.'
                    ylim([elev_min(curr_gui) elev_max(curr_gui)])
                case 'depth'
                    ylim([depth_min depth_max])
            end
        end
        narrow_cb
        switch curr_ax
            case 2
                [curr_ax, curr_rad] ...
                           = deal(3, 2);
                narrow_cb
                [curr_ax, curr_rad] ...
                           = deal(2, 1);
            case 3
                [curr_ax, curr_rad] ...
                           = deal(2, 1);
                narrow_cb
                [curr_ax, curr_rad] ...
                           = deal(3, 2);
        end
    end

%% Adjust slider limits after panning or zooming

    function panzoom1
        [curr_gui, curr_ax, curr_rad, curr_rad_alt] ...
                            = deal(2, 2, 1, 2);
        panzoom
    end

    function panzoom2
        [curr_gui, curr_ax, curr_rad, curr_rad_alt] ...
                            = deal(2, 3, 2, 1);
        panzoom
    end

    function panzoom(source, eventdata)
        set(rad_group, 'selectedobject', rad_check(curr_rad))
        tmp1                = get(ax(curr_ax), 'xlim');
        if (tmp1(1) < dist_min_ref(curr_rad))
            reset_dist_min
        else
            if (tmp1(1) < get(dist_min_slide(curr_rad), 'min'))
                set(dist_min_slide(curr_rad), 'value', get(dist_min_slide(curr_rad), 'min'))
            else
                set(dist_min_slide(curr_rad), 'value', tmp1(1))
            end
            set(dist_min_edit(curr_rad), 'string', sprintf('%3.1f', tmp1(1)))
            dist_min(curr_rad) ...
                            = tmp1(1);
        end
        if (tmp1(2) > dist_max_ref(curr_rad))
            reset_dist_max
        else
            if (tmp1(2) > get(dist_max_slide(curr_rad), 'max'))
                set(dist_max_slide(curr_rad), 'value', get(dist_max_slide(curr_rad), 'max'))
            else
                set(dist_max_slide(curr_rad), 'value', tmp1(2))
            end
            set(dist_max_edit(curr_rad), 'string', sprintf('%3.1f', tmp1(2)))
            dist_max(curr_rad) ...
                            = tmp1(2);
        end
        tmp1                = get(ax(curr_ax), 'ylim');
        switch disp_type
            case 'elev.'
                if (tmp1(1) < elev_min_ref)
                    reset_y_min
                else
                    if (tmp1(1) < get(z_min_slide(curr_gui), 'min'))
                        set(z_min_slide(curr_gui), 'value', get(z_min_slide(curr_gui), 'min'))
                    else
                        set(z_min_slide(curr_gui), 'value', tmp1(1))
                    end
                    set(z_min_edit(curr_gui), 'string', sprintf('%4.0f', tmp1(1)))
                    elev_min(curr_gui) ...
                            = tmp1(1);
                end
                if (tmp1(2) > elev_max_ref)
                    reset_y_max
                else
                    if (tmp1(2) > get(z_max_slide(curr_gui), 'max'))
                        set(z_max_slide(curr_gui), 'value', get(z_max_slide(curr_gui), 'max'))
                    else
                        set(z_max_slide(curr_gui), 'value', tmp1(2))
                    end
                    set(z_max_edit(curr_gui), 'string', sprintf('%4.0f', tmp1(2)))
                    elev_max(curr_gui) = tmp1(2);
                end
            case 'depth'
                tmp2        = [depth_min depth_max];
                if (tmp1(1) < depth_min_ref)
                    reset_z_min
                else
                    if (tmp1(1) < get(z_min_slide(curr_gui), 'min'))
                        set(z_min_slide(curr_gui), 'value', get(z_min_slide(curr_gui), 'min'))
                    elseif (tmp1(1) > get(z_min_slide(curr_gui), 'max'))
                        set(z_min_slide(curr_gui), 'value', get(z_min_slide(curr_gui), 'max'))
                    else
                        set(z_min_slide(curr_gui), 'value', tmp1(1))
                    end
                    set(z_min_edit(curr_gui), 'string', sprintf('%4.0f', tmp1(1)))
                    depth_min ...
                            = tmp1(1);
                end
                if (tmp1(2) > depth_max_ref)
                    reset_z_max
                else
                    if (tmp1(2) < get(z_max_slide(curr_gui), 'min'))
                        set(z_max_slide(curr_gui), 'value', get(z_max_slide(curr_gui), 'min'))
                    elseif (tmp1(2) > get(z_max_slide(curr_gui), 'max'))
                        set(z_max_slide(curr_gui), 'value', get(z_max_slide(curr_gui), 'max'))
                    else
                        set(z_max_slide(curr_gui), 'value', tmp1(2))
                    end
                    set(z_max_edit(curr_gui), 'string', sprintf('%4.0f', tmp1(2)))
                    depth_max ...
                            = tmp1(2);
                end
        end
        narrow_cb
        switch curr_ax
            case 2
                [curr_ax, curr_rad] ...
                           = deal(3, 2);
                narrow_cb
                [curr_ax, curr_rad] ...
                           = deal(2, 1);
            case 3
                [curr_ax, curr_rad] ...
                           = deal(2, 1);
                narrow_cb
                [curr_ax, curr_rad] ...
                           = deal(3, 2);
        end        
    end

%% Plot data in terms of elevation

    function plot_elev(source, eventdata)
        curr_gui            = 2;
        if ~data_done(curr_rad)
            set(status_box(curr_gui), 'string', 'Data not loaded yet.')
            return
        end
        set(status_box(curr_gui), 'string', 'Plotting data in terms of elevation...')
        if ishandle(p_data(curr_gui, curr_rad))
            delete(p_data(curr_gui, curr_rad))
        end
        axes(ax(curr_ax))
        set(z_min_slide(curr_gui), 'min', elev_min_ref, 'max', elev_max_ref, 'value', elev_max(curr_gui))
        set(z_max_slide(curr_gui), 'min', elev_min_ref, 'max', elev_max_ref, 'value', elev_min(curr_gui))
        set(z_min_edit(curr_gui), 'string', sprintf('%4.0f', elev_max(curr_gui)))
        set(z_max_edit(curr_gui), 'string', sprintf('%4.0f', elev_min(curr_gui)))
        if (data_done(curr_rad) && get(data_check(curr_gui, curr_rad), 'value'))
            switch curr_gui
                case 1
                    set(status_box(1), 'string', 'Displaying radargram in 3D GUI...')
                    zlim([elev_min(curr_gui) elev_max(curr_gui)])
                    p_data(curr_gui, curr_rad) ...
                            = surf(repmat(x{curr_rad}(ind_decim{curr_rad}), num_sample(curr_rad), 1), repmat(y{curr_rad}(ind_decim{curr_rad}), num_sample(curr_rad), 1), repmat(elev{curr_rad}, 1, num_decim(curr_rad)), double(amp_elev{curr_rad}), ...
                                   'facecolor', 'flat', 'edgecolor', 'none', 'facelighting', 'none');
                    set(status_box(1), 'string', 'Displayed. Changing view will be slower.')
                    reset_xyz
                    narrow_cb
                    show_data
                    show_core
                    show_pk
                    show_int
                case 2
                    for ii = 2:3
                        [curr_ax, curr_rad] ...
                            = deal(ii, (ii - 1));
                        set(data_check(curr_gui, curr_rad), 'value', 1)
                        axes(ax(curr_ax))
                        set(z_min_slide(curr_gui), 'min', elev_min_ref, 'max', elev_max_ref, 'value', elev_max(curr_gui))
                        set(z_max_slide(curr_gui), 'min', elev_min_ref, 'max', elev_max_ref, 'value', elev_min(curr_gui))
                        set(z_min_edit(curr_gui), 'string', sprintf('%4.0f', elev_max(curr_gui)))
                        set(z_max_edit(curr_gui), 'string', sprintf('%4.0f', elev_min(curr_gui)))
                        axis xy
                        ylim([elev_min(curr_gui) elev_max(curr_gui)])
                        p_data(curr_gui, curr_rad) ...
                            = imagesc(dist_lin{curr_rad}(ind_decim{curr_rad}), elev{curr_rad}, amp_elev{curr_rad}, [db_min(curr_ax) db_max(curr_ax)]);
                        reset_xz
                        narrow_cb
                        show_data
                        show_core
                        show_pk
                        show_int
                    end
            end
        end
    end

%% Plot data in terms of depth

    function plot_depth(source, eventdata)
        curr_gui            = 2;
        if ~all(data_done)
            set(status_box(curr_gui), 'string', 'Data not loaded yet.')
            return
        end
        set(status_box(curr_gui), 'string', 'Plotting data in terms of depth...')
        delete(p_data(curr_gui, ishandle(p_data(curr_gui, :))))
        for ii = 2:3
            [curr_ax, curr_rad] ...
                            = deal(ii, (ii - 1));
            set(data_check(curr_gui, curr_rad), 'value', 1)
            axes(ax(curr_ax)) %#ok<*LAXES>
            set(z_min_slide(curr_gui), 'min', depth_min_ref, 'max', depth_max_ref, 'value', (depth_max_ref - (depth_max - depth_min_ref)))
            set(z_max_slide(curr_gui), 'min', depth_min_ref, 'max', depth_max_ref, 'value', (depth_max_ref - (depth_min - depth_min_ref)))
            set(z_min_edit(curr_gui), 'string', sprintf('%4.0f', depth_max))
            set(z_max_edit(curr_gui), 'string', sprintf('%4.0f', depth_min))
            axis ij
            ylim([depth_min depth_max])
            p_data(curr_gui, curr_rad) ...
                            = imagesc(dist_lin{curr_rad}(ind_decim{curr_rad}), depth{curr_rad}, amp_depth{curr_rad}, [db_min(curr_ax) db_max(curr_ax)]);
            reset_xz
            narrow_cb
            show_data
            show_core
            show_pk
            show_int
        end
    end

%% Show radar data

    function show_data1(source, eventdata)
        [curr_gui, curr_ax, curr_rad, curr_rad_alt] ...
                            = deal(1, 1, 1, 2);
        plot_elev
        show_data
    end

    function show_data2(source, eventdata)
        [curr_gui, curr_ax, curr_rad, curr_rad_alt] ...
                            = deal(1, 1, 2, 1);
        plot_elev
        show_data
    end

    function show_data3(source, eventdata)
        [curr_gui, curr_ax, curr_rad, curr_rad_alt] ...
                            = deal(2, 2, 1, 2);
        show_data
    end

    function show_data4(source, eventdata)
        [curr_gui, curr_ax, curr_rad, curr_rad_alt] ...
                            = deal(2, 3, 2, 1);
        show_data
    end

    function show_data(source, eventdata)
        set(rad_group, 'selectedobject', rad_check(curr_rad))
        if data_done(curr_rad)
            if (get(data_check(curr_gui, curr_rad), 'value') && ishandle(p_data(curr_gui, curr_rad)))
                set(p_data(curr_gui, curr_rad), 'visible', 'on')
            elseif ishandle(p_data(curr_gui, curr_rad))
                set(p_data(curr_gui, curr_rad), 'visible', 'off')
            end
        elseif get(data_check(curr_gui, curr_rad), 'value')
            set(data_check(curr_gui, curr_rad), 'value', 0)
        end
    end

%% Show picked layers

    function show_pk1(source, eventdata)
        [curr_gui, curr_ax, curr_rad, curr_rad_alt] ...
                            = deal(1, 1, 1, 2);
        show_pk
    end

    function show_pk2(source, eventdata)
        [curr_gui, curr_ax, curr_rad, curr_rad_alt] ...
                            = deal(1, 1, 2, 1);
        show_pk
    end

    function show_pk3(source, eventdata)
        [curr_gui, curr_ax, curr_rad, curr_rad_alt] ...
                            = deal(2, 2, 1, 2);
        show_pk
    end

    function show_pk4(source, eventdata)
        [curr_gui, curr_ax, curr_rad, curr_rad_alt] ...
                            = deal(2, 3, 2, 1);
        show_pk
    end

    function show_pk(source, eventdata)
        set(rad_group, 'selectedobject', rad_check(curr_rad))
        if pk_done(curr_rad)
            if get(pk_check(curr_gui, curr_rad), 'value')
                if ((curr_gui == 1) || strcmp(disp_type, 'elev.'))
                    set(p_pk{curr_gui, curr_rad}(ishandle(p_pk{curr_gui, curr_rad})), 'visible', 'on')
                    uistack(p_pk{curr_gui, curr_rad}(ishandle(p_pk{curr_gui, curr_rad})), 'top')
                    if ishandle(p_surf(curr_gui, curr_rad))
                        set(p_surf(curr_gui, curr_rad), 'visible', 'on')
                        uistack(p_surf(curr_gui, curr_rad), 'top')
                    end
                    if ishandle(p_bed(curr_gui, curr_rad))
                        set(p_bed(curr_gui, curr_rad), 'visible', 'on')
                        uistack(p_bed(curr_gui, curr_rad), 'top')
                    end
                    set(p_pkdepth{curr_rad}(ishandle(p_pkdepth{curr_rad})), 'visible', 'off')
                    if ishandle(p_beddepth(curr_rad))
                        set(p_beddepth(curr_rad), 'visible', 'off')
                    end
                else
                    set(p_pkdepth{curr_rad}(ishandle(p_pkdepth{curr_rad})), 'visible', 'on')
                    uistack(p_pkdepth{curr_rad}(ishandle(p_pkdepth{curr_rad})), 'top')
                    if ishandle(p_beddepth(curr_rad))
                        set(p_beddepth(curr_rad), 'visible', 'on')
                    end
                    set(p_pk{curr_gui, curr_rad}(ishandle(p_pk{curr_gui, curr_rad})), 'visible', 'off')
                    if ishandle(p_surf(curr_gui, curr_rad))
                        set(p_surf(curr_gui, curr_rad), 'visible', 'off')
                    end
                    if ishandle(p_bed(curr_gui, curr_rad))
                        set(p_bed(curr_gui, curr_rad), 'visible', 'off')
                    end
                end
                show_int
            else
                set([p_pk{curr_gui, curr_rad}(ishandle(p_pk{curr_gui, curr_rad})) p_pkdepth{curr_rad}(ishandle(p_pkdepth{curr_rad}))], 'visible', 'off')
                if ishandle(p_surf(curr_gui, curr_rad))
                    set(p_surf(curr_gui, curr_rad), 'visible', 'off')
                end
                if ishandle(p_bed(curr_gui, curr_rad))
                    set(p_bed(curr_gui, curr_rad), 'visible', 'off')
                end
                if ishandle(p_beddepth(curr_rad))
                    set(p_beddepth(curr_rad), 'visible', 'off')
                end
            end
        elseif get(pk_check(curr_gui, curr_rad), 'value')
            set(pk_check(curr_gui, curr_rad), 'value', 0)
        end
    end

%% Show intersections

    function show_int1(source, eventdata)
       [curr_gui, curr_ax, curr_rad, curr_rad_alt] ...
                            = deal(1, 1, 1, 2);
       show_int
    end

    function show_int2(source, eventdata)
        [curr_gui, curr_ax, curr_rad, curr_rad_alt] ...
                            = deal(2, 2, 1, 2);
        show_int
    end

    function show_int3(source, eventdata)
        [curr_gui, curr_ax, curr_rad, curr_rad_alt] ...
                            = deal(2, 3, 2, 1);
        show_int
    end

    function show_int(source, eventdata)
        set(rad_group, 'selectedobject', rad_check(curr_rad))
        if all(pk_done)
            if get(int_check(curr_ax), 'value')
                if ((curr_gui == 1) || strcmp(disp_type, 'elev.'))
                    set(p_int1{1, curr_ax}(ishandle(p_int1{1, curr_ax})), 'visible', 'on')
                    uistack(p_int1{1, curr_ax}(ishandle(p_int1{1, curr_ax})), 'top')
                    if (curr_gui == 2)
                        set(p_int2{1, curr_rad}(ishandle(p_int2{1, curr_rad})), 'visible', 'on')
                        uistack(p_int2{1, curr_rad}(ishandle(p_int2{1, curr_rad})), 'top')
                        set([p_int1{2, curr_ax}(ishandle(p_int1{2, curr_ax})) p_int2{2, curr_rad}(ishandle(p_int2{2, curr_rad}))], 'visible', 'off')
                    end
                else
                    set([p_int1{2, curr_ax}(ishandle(p_int1{2, curr_ax})) p_int2{2, curr_rad}(ishandle(p_int2{2, curr_rad}))], 'visible', 'on')
                    uistack(p_int1{2, curr_ax}(ishandle(p_int1{2, curr_ax})), 'top')
                    uistack(p_int2{2, curr_rad}(ishandle(p_int2{2, curr_rad})), 'top')
                    set([p_int1{1, curr_ax}(ishandle(p_int1{1, curr_ax})) p_int2{1, curr_rad}(ishandle(p_int2{1, curr_rad}))], 'visible', 'off')
                end
            else
                for ii = 1:2
                    set([p_int1{ii, curr_ax}(ishandle(p_int1{ii, curr_ax})) p_int2{ii, curr_rad}(ishandle(p_int2{ii, curr_rad}))], 'visible', 'off')
                end
            end
        elseif get(int_check(curr_ax), 'value')
            set(int_check(curr_ax), 'value', 0)
        end
    end

%% Show core intersections

    function show_core1(source, eventdata)
       [curr_gui, curr_ax, curr_rad, curr_rad_alt] ...
                            = deal(1, 1, 1, 2);
       show_core
    end

    function show_core2(source, eventdata)
        [curr_gui, curr_ax, curr_rad, curr_rad_alt] ...
                            = deal(2, 2, 1, 2);
        show_core
    end

    function show_core3(source, eventdata)
        [curr_gui, curr_ax, curr_rad, curr_rad_alt] ...
                            = deal(2, 3, 2, 1);
        show_core
    end

    function show_core(source, eventdata)
        set(rad_group, 'selectedobject', rad_check(curr_rad))
        if (core_done && ~isempty(ind_int_core{curr_rad}))
            if get(core_check(curr_ax), 'value')
                switch curr_gui
                    case 1
                        set([p_core{curr_gui, curr_rad}(ishandle(p_core{curr_gui, curr_rad})) p_corename{curr_gui, curr_rad}(ishandle(p_corename{curr_gui, curr_rad}))], 'visible', 'on')
                        uistack(p_core{curr_gui, curr_rad}(ishandle(p_core{curr_gui, curr_rad})), 'top')
                        uistack(p_corename{curr_gui, curr_rad}(ishandle(p_corename{curr_gui, curr_rad})), 'top')
                    case 2
                        switch disp_type
                            case 'elev.'
                                set([p_core{curr_gui, curr_rad}(ishandle(p_core{curr_gui, curr_rad})) p_corename{curr_gui, curr_rad}(ishandle(p_corename{curr_gui, curr_rad}))], 'visible', 'on')
                                uistack(p_core{curr_gui, curr_rad}(ishandle(p_core{curr_gui, curr_rad})), 'top')
                                uistack(p_corename{curr_gui, curr_rad}(ishandle(p_corename{curr_gui, curr_rad})), 'top')
                                set([p_coredepth{curr_rad}(ishandle(p_coredepth{curr_rad})) p_corenamedepth{curr_rad}(ishandle(p_corenamedepth{curr_rad}))], 'visible', 'off')
                            case 'depth'
                                set([p_coredepth{curr_rad}(ishandle(p_coredepth{curr_rad})) p_corenamedepth{curr_rad}(ishandle(p_corenamedepth{curr_rad}))], 'visible', 'off')
                                uistack(p_coredepth{curr_rad}(ishandle(p_coredepth{curr_rad})), 'top')
                                uistack(p_corenamedepth{curr_rad}(ishandle(p_corenamedepth{curr_rad})), 'top')
                                set([p_core{curr_gui, curr_rad}(ishandle(p_core{curr_gui, curr_rad})) p_corename{curr_gui, curr_rad}(ishandle(p_corename{curr_gui, curr_rad}))], 'visible', 'off')
                        end
                end
            else
                set([p_core{curr_gui, curr_rad}(ishandle(p_core{curr_gui, curr_rad})) p_corename{curr_gui, curr_rad}(ishandle(p_corename{curr_gui, curr_rad}))], 'visible', 'off')
                if (curr_gui == 2)
                    set([p_coredepth{curr_rad}(ishandle(p_coredepth{curr_rad})) p_corenamedepth{curr_rad}(ishandle(p_corenamedepth{curr_rad}))], 'visible', 'off')
                end
            end
        elseif get(core_check(curr_ax), 'value')
            set(core_check(curr_ax), 'value', 0)
        end
    end

%% Adjust number of indices to display

    function adj_decim1(source, eventdata)
        [curr_gui, curr_ax, curr_rad, curr_rad_alt] ...
                            = deal(1, 1, 1, 2);
        adj_decim
    end

    function adj_decim2(source, eventdata)
        [curr_gui, curr_ax, curr_rad, curr_rad_alt] ...
                            = deal(1, 1, 2, 1);
        adj_decim
    end

    function adj_decim3(source, eventdata)
        [curr_gui, curr_ax, curr_rad, curr_rad_alt] ...
                            = deal(2, 2, 1, 2);
        adj_decim
    end

    function adj_decim4(source, eventdata)
        [curr_gui, curr_ax, curr_rad, curr_rad_alt] ...
                            = deal(2, 3, 2, 1);
        adj_decim
    end

    function adj_decim(source, eventdata)
        set(rad_group, 'selectedobject', rad_check(curr_rad))
        decim(curr_rad)     = abs(round(str2double(get(decim_edit(curr_gui, curr_rad), 'string'))));
        if pk_done(curr_rad)
            set(status_box, 'string', 'Updating picks to new decimation...')
            pause(0.1)
            if (decim(curr_rad) > 1)
                ind_decim{curr_rad} ...
                            = (1 + ceil(decim(curr_rad) / 2)):decim(curr_rad):(pk{curr_rad}.num_trace_tot - ceil(decim(curr_rad) / 2));
            else
                ind_decim{curr_rad} ...
                            = 1:pk{curr_rad}.num_trace_tot;
            end
                num_decim(curr_rad) ...
                            = length(ind_decim{curr_rad});
            delete([p_bed(ishandle(p_bed(:, curr_rad)), curr_rad); p_beddepth(ishandle(p_beddepth))'; p_surf(ishandle(p_surf(:, curr_rad)), curr_rad)])
            for ii = 1:2
                delete([p_pk{ii, curr_rad}(ishandle(p_pk{ii, curr_rad})) p_pkdepth{curr_rad}(ishandle(p_pkdepth{curr_rad}))])
            end
            layer_str{curr_rad} ...
                            = num2cell(1:pk{curr_rad}.num_layer);
            axes(ax(1))
            for ii = 1:pk{curr_rad}.num_layer
                if ~any(~isnan(elev_smooth{curr_rad}(ii, ind_decim{curr_rad})))
                    p_pk{1, curr_rad}(ii) = plot3(0, 0, 0, 'w.', 'markersize', 1);
                    layer_str{curr_rad}{ii} = [num2str(ii) ' H'];
                else
                    p_pk{1, curr_rad}(ii) = plot3(x{curr_rad}(ind_decim{curr_rad}(~isnan(elev_smooth{curr_rad}(ii, ind_decim{curr_rad})))), y{curr_rad}(ind_decim{curr_rad}(~isnan(elev_smooth{curr_rad}(ii, ind_decim{curr_rad})))), ...
                                                  elev_smooth{curr_rad}(ii, ind_decim{curr_rad}(~isnan(elev_smooth{curr_rad}(ii, ind_decim{curr_rad})))), '.', 'color', colors{curr_rad}(ii, :), 'markersize', 12, 'visible', 'off');
                end
            end
            switch curr_rad
                case 1
                    axes(ax(2))
                case 2
                    axes(ax(3))
            end
            for ii = 1:pk{curr_rad}.num_layer
                if all(isnan(elev_smooth{curr_rad}(ii, ind_decim{curr_rad})))
                    p_pk{2, curr_rad}(ii) = plot(0, 0, 'w.', 'markersize', 1);
                else
                    p_pk{2, curr_rad}(ii) = plot(dist_lin{curr_rad}(ind_decim{curr_rad}(~isnan(elev_smooth{curr_rad}(ii, ind_decim{curr_rad})))), elev_smooth{curr_rad}(ii, ind_decim{curr_rad}(~isnan(elev_smooth{curr_rad}(ii, ind_decim{curr_rad})))), ...
                                                 '.', 'color', colors{curr_rad}(ii, :), 'markersize', 12, 'visible', 'off');
                end
            end
            % check to see if surface and bed picks are available
            if isfield(pk{curr_rad}, 'elev_surf')
                if any(~isnan(elev_surf{curr_rad}(ind_decim{curr_rad})))
                    surf_avail(curr_rad) ...
                            = true;
                    axes(ax(1))
                    p_surf(1, curr_rad) ...
                            = plot3(x{curr_rad}(ind_decim{curr_rad}(~isnan(elev_surf{curr_rad}(ind_decim{curr_rad})))), y{curr_rad}(ind_decim{curr_rad}(~isnan(elev_surf{curr_rad}(ind_decim{curr_rad})))), ...
                                    elev_surf{curr_rad}(ind_decim{curr_rad}(~isnan(elev_surf{curr_rad}(ind_decim{curr_rad})))), 'g.', 'markersize', 12, 'visible', 'off');
                    axes(ax(1 + curr_rad))
                    p_surf(2, curr_rad) ...
                            = plot(dist_lin{curr_rad}(ind_decim{curr_rad}(~isnan(elev_surf{curr_rad}(ind_decim{curr_rad})))), elev_surf{curr_rad}(ind_decim{curr_rad}(~isnan(elev_surf{curr_rad}(ind_decim{curr_rad})))), 'g--', 'linewidth', 2, 'visible', 'off');
                    if any(isnan(elev_surf{curr_rad}(ind_decim{curr_rad}(~isnan(elev_surf{curr_rad}(ind_decim{curr_rad}))))))
                        set(p_surf(2, curr_rad), 'marker', '.', 'linestyle', 'none', 'markersize', 12)
                    end
                else
                    surf_avail(curr_rad) ...
                            = false;
                end
            end
            if isfield(pk{curr_rad}, 'elev_bed')
                if any(~isnan(elev_bed{curr_rad}(ind_decim{curr_rad})))
                    bed_avail(curr_rad) ...
                            = true;
                    axes(ax(1))
                    p_bed(1, curr_rad) ...
                        = plot3(x{curr_rad}(ind_decim{curr_rad}(~isnan(elev_bed{curr_rad}(ind_decim{curr_rad})))), y{curr_rad}(ind_decim{curr_rad}(~isnan(elev_bed{curr_rad}(ind_decim{curr_rad})))), ...
                                elev_bed{curr_rad}(ind_decim{curr_rad}(~isnan(elev_bed{curr_rad}(ind_decim{curr_rad})))), 'g.', 'markersize', 12, 'visible', 'off');
                    axes(ax(1 + curr_rad))
                    p_bed(2, curr_rad) ...
                        = plot(dist_lin{curr_rad}(ind_decim{curr_rad}(~isnan(elev_bed{curr_rad}(ind_decim{curr_rad})))), elev_bed{curr_rad}(ind_decim{curr_rad}(~isnan(elev_bed{curr_rad}(ind_decim{curr_rad})))), 'g--', 'linewidth', 2, 'visible', 'off');
                    if any(isnan(elev_bed{curr_rad}(ind_decim{curr_rad}(~isnan(elev_bed{curr_rad}(ind_decim{curr_rad}))))))
                        set(p_bed(2, curr_rad), 'marker', '.', 'linestyle', 'none', 'markersize', 12)
                    end
                else
                    bed_avail(curr_rad) ...
                            = false;
                end
            end
            axes(ax(curr_rad + 1))
            for ii = 1:pk{curr_rad}.num_layer
                if all(isnan(pk{curr_rad}.depth_smooth(ii, ind_decim{curr_rad})))
                    p_pkdepth{curr_rad}(ii) = plot(0, 0, 'w.', 'markersize', 1);
                else
                    p_pkdepth{curr_rad}(ii) = plot(dist_lin{curr_rad}(ind_decim{curr_rad}(~isnan(pk{curr_rad}.depth_smooth(ii, ind_decim{curr_rad})))), pk{curr_rad}.depth_smooth(ii, ind_decim{curr_rad}(~isnan(pk{curr_rad}.depth_smooth(ii, ind_decim{curr_rad})))), ...
                                                   '.', 'color', colors{curr_rad}(ii, :), 'markersize', 12, 'visible', 'off');
                end
            end
            if curr_layer(curr_rad)
                set(layer_list(:, curr_rad), 'string', layer_str{curr_rad}, 'value', curr_layer(curr_rad))
            else
                set(layer_list(:, curr_rad), 'string', layer_str{curr_rad}, 'value', 1)
            end
            switch curr_rad
                case 1
                    show_pk1
                    show_pk3
                case 2
                    show_pk2
                    show_pk4
            end
        end
        if data_done(curr_rad)
            set(status_box, 'string', 'Updating data to new decimation...')
            pause(0.1)
            set(fgui, 'keypressfcn', '', 'windowbuttondownfcn', '')
            load_data_breakout
            set(fgui(1), 'keypressfcn', @keypress1)
            set(fgui(2), 'keypressfcn', @keypress2, 'windowbuttondownfcn', @mouse_click)
        end
        set(decim_edit(:, curr_rad), 'string', num2str(decim(curr_rad)))
        set(status_box, 'string', ['Decimation number set to 1/' num2str(decim(curr_rad)) ' indice(s).'])
        axes(ax(curr_ax))
    end

%% Adjust 3D display aspect ratio

    function adj_aspect(source, eventdata)
        aspect_ratio        = abs(round(str2double(get(aspect_edit, 'string'))));
        set(ax(1), 'dataaspectratio', [1 1 aspect_ratio])
        set(aspect_edit, 'string', num2str(aspect_ratio))
        set(status_box(1), 'string', ['X/Y/Z axis aspect ratio set to 1:1:' num2str(aspect_ratio) '.'])
    end

%% Change colormap

    function change_cmap1(source, eventdata)
        [curr_gui, curr_ax] = deal(1);
        change_cmap
    end

    function change_cmap2(source, eventdata)
        [curr_gui, curr_ax] = deal(2);
        change_cmap
    end

    function change_cmap(source, eventdata)
        axes(ax(curr_ax))
        colormap(cmaps{get(cmap_list(curr_gui), 'value')})
    end

%% Change intersection

    function change_int(source, eventdata)
        curr_gui            = 2;
        if ~(num_int && (curr_ind_int(1) ~= 0))
            return
        end
        curr_int            = get(intnum_list, 'value');
        tmp3                = [curr_ax curr_rad curr_rad_alt];
        for ii = 1:2
            for jj = 1:3
                set(p_int1{ii, jj}(ishandle(p_int1{ii, jj})), 'linewidth', 2)
                if any(ishandle(p_int1{ii, jj}(curr_int)))
                    set(p_int1{ii, jj}(curr_int), 'linewidth', 4)
                end
            end
        end
        [dist_min(1), dist_max(1), dist_min(2), dist_max(2)] ...
                            = deal((dist_lin{1}(curr_ind_int(curr_int, 1)) - 10), (dist_lin{1}(curr_ind_int(curr_int, 1)) + 10), (dist_lin{2}(curr_ind_int(curr_int, 2)) - 10), (dist_lin{2}(curr_ind_int(curr_int, 2)) + 10));
        if (dist_min(1) < dist_min_ref(1))
            dist_min(1) = dist_min_ref(1);
        end
        if (dist_min(2) < dist_min_ref(2))
            dist_min(2) = dist_min_ref(2);
        end
        if (dist_max(1) > dist_max_ref(1))
            dist_max(1) = dist_max_ref(1);
        end
        if (dist_max(2) > dist_max_ref(2))
            dist_max(2) = dist_max_ref(2);
        end
        axes(ax(2))
        xlim([dist_min(1) dist_max(1)])
        axes(ax(3))
        xlim([dist_min(2) dist_max(2)])
        set(dist_min_slide(1), 'value', dist_min(1))
        set(dist_min_slide(2), 'value', dist_min(2))
        set(dist_max_slide(1), 'value', dist_max(1))
        set(dist_max_slide(2), 'value', dist_max(2))
        set(dist_min_edit(1), 'string', sprintf('%3.0f', dist_min(1)))
        set(dist_min_edit(2), 'string', sprintf('%3.0f', dist_min(2)))
        set(dist_max_edit(1), 'string', sprintf('%3.0f', dist_max(1)))
        set(dist_max_edit(2), 'string', sprintf('%3.0f', dist_max(2)))
        [curr_ax, curr_rad, curr_rad_alt] ...
                            = deal(tmp3(1), tmp3(2), tmp3(3));
        switch disp_type
            case 'elev.'
                if any(~isnan([elev_surf{1}(curr_ind_int(curr_int, 1)) elev_surf{2}(curr_ind_int(curr_int, 2))]))
                    elev_max(2) ...
                            = mean([elev_surf{1}(curr_ind_int(curr_int, 1)) elev_surf{2}(curr_ind_int(curr_int, 2))], 'omitnan');
                    set(z_max_slide(2), 'value', elev_max(2))
                    set(z_max_edit(2), 'string', sprintf('%4.0f', elev_max(2)))
                end
                if any(~isnan([elev_bed{1}(curr_ind_int(curr_int, 1)) elev_bed{2}(curr_ind_int(curr_int, 2))]))
                    elev_min(2) ...
                            = mean([elev_bed{1}(curr_ind_int(curr_int, 1)) elev_bed{2}(curr_ind_int(curr_int, 2))], 'omitnan');
                    set(z_min_slide(2), 'value', elev_min(2))
                    set(z_min_edit(2), 'string', sprintf('%4.0f', elev_min(2)))
                end
            case 'depth'
                if any(~isnan([elev_surf{1}(curr_ind_int(curr_int, 1)) elev_surf{2}(curr_ind_int(curr_int, 2))]))
                    depth_min ...
                            = 0;
                    set(z_max_slide(2), 'value', (depth_max_ref - (depth_min - depth_min_ref)))
                    set(z_max_edit(2), 'string', sprintf('%4.0f', depth_min))
                end
                if any(~isnan([elev_bed{1}(curr_ind_int(curr_int, 1)) elev_bed{2}(curr_ind_int(curr_int, 2))]))
                    depth_max ...
                            = mean(([elev_bed{1}(curr_ind_int(curr_int, 1)) elev_bed{2}(curr_ind_int(curr_int, 2))] - [elev_surf{1}(curr_ind_int(curr_int, 1)) elev_surf{2}(curr_ind_int(curr_int, 2))]), 'omitnan');
                    set(z_min_slide(2), 'value', (depth_max_ref - (depth_max - depth_min_ref)))
                    set(z_min_edit(2), 'string', sprintf('%4.0f', depth_max))
                end
        end
        update_z_range
    end

%% Toggle gridlines

    function toggle_grid1(source, eventdata)
        [curr_gui, curr_ax] = deal(1);
        toggle_grid
    end

    function toggle_grid2(source, eventdata)
        [curr_gui, curr_ax, curr_rad, curr_rad_alt] ...
                            = deal(2, 2, 1, 2);
        toggle_grid
    end

    function toggle_grid3(source, eventdata)
        [curr_gui, curr_ax, curr_rad, curr_rad_alt] ...
                            = deal(2, 3, 2, 1);
        toggle_grid
    end

    function toggle_grid
        set(rad_group, 'selectedobject', rad_check(curr_rad))
        if get(grid_check(curr_ax), 'value')
            axes(ax(curr_ax))
            grid on
        else
            grid off
        end
    end

%% Narrow color axis to +/- 2 standard deviations of current mean value

    function narrow_cb1(~, eventdata)
        [curr_gui, curr_ax] = deal(1);
        narrow_cb
    end

    function narrow_cb2(~, eventdata)
        [curr_gui, curr_ax, curr_rad, curr_rad_alt] ...
                            = deal(2, 2, 1, 2);
        narrow_cb
    end

    function narrow_cb3(~, eventdata)
        [curr_gui, curr_ax, curr_rad, curr_rad_alt] ...
                            = deal(2, 3, 2, 1);
        narrow_cb
    end

    function narrow_cb(source, eventdata)
        set(rad_group, 'selectedobject', rad_check(curr_rad))
        if ~(get(cbfix_check2(curr_ax), 'value') && data_done(curr_rad))
            return
        end
        axes(ax(curr_ax))
        tmp1                = zeros(2);
        tmp1(1, :)          = interp1(dist_lin{curr_rad}(ind_decim{curr_rad}), 1:num_decim(curr_rad), [dist_min(curr_rad) dist_max(curr_rad)], 'nearest', 'extrap');
        switch disp_type
            case 'elev.'
                tmp1(2, :)  = interp1(elev{curr_rad}, 1:num_sample(curr_rad), [elev_min(curr_gui) elev_max(curr_gui)], 'nearest', 'extrap');
                tmp1(2, :)  = flipud(tmp1(2, :));
                tmp1        = amp_elev{curr_rad}(tmp1(2, 1):10:tmp1(2, 2), tmp1(1, 1):10:tmp1(1, 2));
            case 'depth'
                tmp1(2, :)  = interp1(depth{curr_rad}, 1:num_sample(curr_rad), [depth_min depth_max], 'nearest', 'extrap');
                tmp1        = amp_depth{curr_rad}(tmp1(2, 1):10:tmp1(2, 2), tmp1(1, 1):10:tmp1(1, 2));
        end
        tmp2                = NaN(1, 2);
        [tmp2(1), tmp2(2)]  = deal(mean(tmp1(~isinf(tmp1)), 'omitnan'), std(tmp1(~isinf(tmp1)), 'omitnan'));
        if any(isnan(tmp2))
            return
        end
        tmp1                = zeros(1, 2);
        tmp4                = 2 * tmp2(2);
        if ((tmp2(1) - tmp4) < db_min_ref(curr_ax))
            tmp1(1)         = db_min_ref(curr_ax);
        else
            tmp1(1)         = tmp2(1) - tmp4;
        end
        if ((tmp2(1) + tmp4) > db_max_ref(curr_ax))
            tmp1(2)         = db_max_ref(curr_ax);
        else
            tmp1(2)         = tmp2(1) + tmp4;
        end
        [db_min(curr_ax), db_max(curr_ax)] ...
                            = deal(tmp1(1), tmp1(2));
        if (db_min(curr_ax) < get(cb_min_slide(curr_ax), 'min'))
            set(cb_min_slide(curr_ax), 'value', get(cb_min_slide(curr_ax), 'min'))
        else
            set(cb_min_slide(curr_ax), 'value', db_min(curr_ax))
        end
        if (db_max(curr_ax) > get(cb_max_slide(curr_ax), 'max'))
            set(cb_max_slide(curr_ax), 'value', get(cb_max_slide(curr_ax), 'max'))
        else
            set(cb_max_slide(curr_ax), 'value', db_max(curr_ax))
        end
        set(cb_min_edit(curr_ax), 'string', sprintf('%3.0f', db_min(curr_ax)))
        set(cb_max_edit(curr_ax), 'string', sprintf('%3.0f', db_max(curr_ax)))
        caxis([db_min(curr_ax) db_max(curr_ax)])
    end

%% Switch display type

    function disp_radio(~, eventdata)
        disp_type           = get(eventdata.NewValue, 'string');
        switch disp_type
            case 'elev.'
                plot_elev
            case 'depth'
                plot_depth
        end
        change_int
    end

%% Switch active transect

    function rad_radio(~, eventdata)
        switch get(eventdata.NewValue, 'string')
            case 'M'
                [curr_gui, curr_ax, curr_rad, curr_rad_alt] ...
                            = deal(2, 2, 1, 2);
                set(status_box(curr_gui), 'string', 'Master transect now selected/active.')
            case 'I'
                [curr_gui, curr_ax, curr_rad, curr_rad_alt] ...
                            = deal(2, 3, 2, 1);
                set(status_box(curr_gui), 'string', 'Intersecting transect now selected/active.')
        end
        axes(ax(curr_ax))
    end

%% Switch viewing dimension

    function choose_dim(~, eventdata)
        [curr_gui, curr_ax] = deal(1);
        curr_dim            = get(eventdata.NewValue, 'string');
        axes(ax(1))
        switch curr_dim
            case '2D'
                [curr_az3, curr_el3] ...
                            = view;
                if any([curr_az2 curr_el2])
                    view(curr_az2, curr_el2)
                else
                    view(2)
                end
            case '3D'
                [curr_az2, curr_el2] ...
                            = view;
                view(curr_az3, curr_el3)
        end
    end

%% Keyboard shortcuts for various functions

    function keypress1(~, eventdata)
        [curr_gui, curr_ax] = deal(1);
        switch eventdata.Key
            case '1'
                [curr_rad, curr_rad_alt] ...
                            = deal(1, 2);
                if get(pk_check(1, 1), 'value')
                    set(pk_check(1, 1), 'value', 0)
                else
                    set(pk_check(1, 1), 'value', 1)
                end
                show_pk
            case '2'
                [curr_rad, curr_rad_alt] ...
                            = deal(2, 1);
                if get(pk_check(1, 2), 'value')
                    set(pk_check(1, 2), 'value', 0)
                else
                    set(pk_check(1, 2), 'value', 1)
                end
                show_pk
            case '3'
                if get(int_check(1), 'value')
                    set(int_check(1), 'value', 0)
                else
                    set(int_check(1), 'value', 1)
                end
                show_int1
            case '4'
                if get(core_check(1), 'value')
                    set(core_check(1), 'value', 0)
                else
                    set(core_check(1), 'value', 1)
                end
                show_core1
            case '5'
                [curr_rad, curr_rad_alt] ...
                            = deal(1, 2);
                if get(data_check(curr_gui, curr_rad), 'value')
                    set(data_check(curr_gui, curr_rad), 'value', 0)
                else
                    set(data_check(curr_gui, curr_rad), 'value', 1)
                end
                show_data
            case '6'
                [curr_rad, curr_rad_alt] ...
                            = deal(2, 1);
                if get(data_check(curr_gui, curr_rad), 'value')
                    set(data_check(curr_gui, curr_rad), 'value', 0)
                else
                    set(data_check(curr_gui, curr_rad), 'value', 1)
                end
                show_data
            case 'a'
                pk_last
            case 'c'
                load_core
            case 'e'
                reset_xyz
            case 'g'
                if get(grid_check(1), 'value')
                    set(grid_check(1), 'value', 0)
                else
                    set(grid_check(1), 'value', 1)
                end
                toggle_grid
            case 'i'
                load_int
            case 'm'
                load_match
            case 'n'
                pk_next
            case 'p'
                load_pk1
            case 't'
                misctest
            case 'v'
                pk_save
            case 'w'
                if (get(cmap_list(curr_gui), 'value') == 1)
                    set(cmap_list(curr_gui), 'value', 2)
                else
                    set(cmap_list(curr_gui), 'value', 1)
                end
                change_cmap
            case 'x'
                if get(xfix_check, 'value')
                    set(xfix_check, 'value', 0)
                else
                    set(xfix_check, 'value', 1)
                end
            case 'y'
                if get(yfix_check, 'value')
                    set(yfix_check, 'value', 0)
                else
                    set(yfix_check, 'value', 1)
                end
            case 'z'
                if get(zfix_check(1), 'value')
                    set(zfix_check(1), 'value', 0)
                else
                    set(zfix_check(1), 'value', 1)
                end
            case 'spacebar'
                axes(ax(1))
                switch curr_dim
                    case '2D'
                        set(dim_group, 'selectedobject', dim_check(2))
                        curr_dim ...
                            = '3D';
                        [curr_az2, curr_el2] ...
                            = view;
                        view(curr_az3, curr_el3)
                    case '3D'
                        set(dim_group, 'selectedobject', dim_check(1))
                        curr_dim ...
                            = '2D';
                        [curr_az3, curr_el3] ...
                            = view;
                        if any([curr_az2 curr_el2])
                            view(curr_az2, curr_el2)
                        else
                            view(2)
                        end
                end
        end
    end

    function keypress2(~, eventdata)
        curr_gui            = 2;
        switch eventdata.Key
            case '1'
                set(rad_group, 'selectedobject', rad_check(1))
                [curr_gui, curr_ax, curr_rad, curr_rad_alt] ...
                            = deal(2, 2, 1, 2);
                axes(ax(curr_ax))
                set(status_box(curr_gui), 'string', 'Master transect now selected/active.')
            case '2'
                set(rad_group, 'selectedobject', rad_check(2))
                [curr_gui, curr_ax, curr_rad, curr_rad_alt] ...
                            = deal(2, 3, 2, 1);
                axes(ax(curr_ax))
                set(status_box(curr_gui), 'string', 'Intersecting transect now selected/active.')
            case '3'
                [curr_ax, curr_rad, curr_rad_alt] ...
                            = deal(2, 1, 2);
                if get(pk_check(curr_gui, curr_rad), 'value')
                    set(pk_check(curr_gui, curr_rad), 'value', 0)
                else
                    set(pk_check(curr_gui, curr_rad), 'value', 1)
                end
                show_pk
            case '4'
                [curr_ax, curr_rad, curr_rad_alt] ...
                            = deal(3, 2, 1);
                if get(pk_check(curr_gui, curr_rad), 'value')
                    set(pk_check(curr_gui, curr_rad), 'value', 0)
                else
                    set(pk_check(curr_gui, curr_rad), 'value', 1)
                end
                show_pk
            case '5'
                [curr_ax, curr_rad, curr_rad_alt] ...
                            = deal(2, 1, 2);
                if get(data_check(curr_gui, curr_rad), 'value')
                    set(data_check(curr_gui, curr_rad), 'value', 0)
                else
                    set(data_check(curr_gui, curr_rad), 'value', 1)
                end
                show_data
            case '6'
                [curr_ax, curr_rad, curr_rad_alt] ...
                            = deal(3, 2, 1);
                if get(data_check(curr_gui, curr_rad), 'value')
                    set(data_check(curr_gui, curr_rad), 'value', 0)
                else
                    set(data_check(curr_gui, curr_rad), 'value', 1)
                end
                show_data
            case '7'
                [curr_ax, curr_rad, curr_rad_alt] ...
                            = deal(2, 1, 2);
                if get(int_check(curr_ax), 'value')
                    set(int_check(curr_ax), 'value', 0)
                else
                    set(int_check(curr_ax), 'value', 1)
                end
                show_int
            case '8'
                [curr_ax, curr_rad, curr_rad_alt] ...
                            = deal(3, 2, 1);
                if get(int_check(curr_ax), 'value')
                    set(int_check(curr_ax), 'value', 0)
                else
                    set(int_check(curr_ax), 'value', 1)
                end
                show_int
            case '9'
                if get(core_check(curr_ax), 'value')
                    set(core_check(curr_ax), 'value', 0)
                else
                    set(core_check(curr_ax), 'value', 1)
                end
                show_core
            case '0'
                [curr_ax, curr_rad, curr_rad_alt] ...
                            = deal(2, 1, 2);
                if get(pk_check(curr_gui, curr_rad), 'value')
                    set(pk_check(curr_gui, :), 'value', 0)
                else
                    set(pk_check(curr_gui, :), 'value', 1)
                end
                show_pk
                [curr_ax, curr_rad, curr_rad_alt] ...
                            = deal(3, 2, 1);
                show_pk
            case 'a'
                pk_last
            case 'b'
                if get(cbfix_check2(curr_ax), 'value')
                    set(cbfix_check2(curr_ax), 'value', 0)
                else
                    set(cbfix_check2(curr_ax), 'value', 1)
                end
                narrow_cb
            case 'd'
                if get(distfix_check(curr_rad), 'value')
                    set(distfix_check(curr_rad), 'value', 0)
                else
                    set(distfix_check(curr_rad), 'value', 1)
                end
            case 'e'
                reset_xz
            case 'g'
                if get(grid_check(curr_ax), 'value')
                    set(grid_check(curr_ax), 'value', 0)
                else
                    set(grid_check(curr_ax), 'value', 1)
                end
                toggle_grid
            case 'h'
                if get(match_check, 'value')
                    set(match_check, 'value', 0)
                else
                    set(match_check, 'value', 1)
                end
            case 'l'
                set(fgui, 'keypressfcn', '', 'windowbuttondownfcn', '')
                load_data
                set(fgui(1), 'keypressfcn', @keypress1)
                set(fgui(2), 'keypressfcn', @keypress2, 'windowbuttondownfcn', @mouse_click)
            case 'm'
                pk_match
            case 'n'
                pk_next
            case 'o'
                pk_focus
            case 't'
                if (curr_int > 1)
                    set(intnum_list, 'value', (curr_int - 1))
                    change_int
                end
            case 'u'
                pk_unmatch
            case 'v'
                if get(nearest_check, 'value')
                    set(nearest_check, 'value', 0)
                else
                    set(nearest_check, 'value', 1)
                end
            case 'w'
                if (get(cmap_list(curr_gui), 'value') == 1)
                    set(cmap_list(curr_gui), 'value', 2)
                else
                    set(cmap_list(curr_gui), 'value', 1)
                end
                change_cmap
            case 'x'
                pk_select_gui2
            case 'y'
                if (curr_int < num_int)
                    set(intnum_list, 'value', (curr_int + 1))
                    change_int
                end
            case 'z'
                pk_select_gui1
            case 'downarrow'
                if strcmp(disp_type, 'elev.')
                    tmp1 = elev_max(curr_gui) - elev_min(curr_gui);
                    tmp2 = elev_min(curr_gui) - (0.25 * tmp1);
                    if (tmp2 < elev_min_ref)
                        elev_min(curr_gui) = elev_min_ref;
                    else
                        elev_min(curr_gui) = tmp2;
                    end
                    elev_max(curr_gui)    = elev_min(curr_gui) + tmp1;
                    if (elev_max(curr_gui) > elev_max_ref)
                        elev_max(curr_gui) = elev_max_ref;
                    end
                    set(z_min_edit(curr_gui), 'string', sprintf('%4.0f', elev_min(curr_gui)))
                    set(z_max_edit(curr_gui), 'string', sprintf('%4.0f', elev_max(curr_gui)))
                    if (elev_min(curr_gui) < get(z_min_slide(curr_gui), 'min'))
                        set(z_min_slide(curr_gui), 'value', get(z_min_slide(curr_gui), 'min'))
                    else
                        set(z_min_slide(curr_gui), 'value', elev_min(curr_gui))
                    end
                    if (elev_max(curr_gui) > get(z_max_slide(curr_gui), 'max'))
                        set(z_max_slide(curr_gui), 'value', get(z_max_slide(curr_gui), 'max'))
                    else
                        set(z_max_slide(curr_gui), 'value', elev_max(curr_gui))
                    end
                else
                    tmp1 = depth_max - depth_min;
                    tmp2 = depth_max + (0.25 * tmp1);
                    if (tmp2 > depth_max_ref)
                        depth_max = depth_max_ref;
                    else
                        depth_max = tmp2;
                    end
                    depth_min = depth_max - tmp1;
                    if (depth_min < depth_min_ref)
                        depth_min = depth_min_ref;
                    end
                    set(z_min_edit(curr_gui), 'string', sprintf('%4.0f', depth_max))
                    set(z_max_edit(curr_gui), 'string', sprintf('%4.0f', depth_min))
                    if ((depth_max_ref - (depth_max - depth_min_ref)) < get(z_min_slide(curr_gui), 'min'))
                        set(z_min_slide(curr_gui), 'value', get(z_min_slide(curr_gui), 'min'))
                    elseif ((depth_max_ref - (depth_max - depth_min_ref)) > get(z_min_slide(curr_gui), 'max'))
                        set(z_min_slide(curr_gui), 'value', get(z_min_slide(curr_gui), 'max'))
                    else
                        set(z_min_slide(curr_gui), 'value', (depth_max_ref - (depth_max - depth_min_ref)))
                    end
                    if ((depth_max_ref - (depth_min - depth_min_ref)) < get(z_max_slide(curr_gui), 'min'))
                        set(z_max_slide(curr_gui), 'value', get(z_max_slide(curr_gui), 'min'))
                    elseif ((depth_max_ref - (depth_min - depth_min_ref)) > get(z_max_slide(curr_gui), 'max'))
                        set(z_max_slide(curr_gui), 'value', get(z_max_slide(curr_gui), 'max'))
                    else
                        set(z_max_slide(curr_gui), 'value', (depth_max_ref - (depth_min - depth_min_ref)))
                    end
                end
                switch curr_ax
                    case 2
                        [curr_ax, curr_rad] = deal(3, 2);
                        switch disp_type
                            case 'elev.'
                                tmp1 = elev_max(curr_gui) - elev_min(curr_gui);
                                tmp2 = elev_min(curr_gui) - (0.25 * tmp1);
                                if (tmp2 < elev_min_ref)
                                    elev_min(curr_gui) = elev_min_ref;
                                else
                                    elev_min(curr_gui) = tmp2;
                                end
                                elev_max(curr_gui)    = elev_min(curr_gui) + tmp1;
                                if (elev_max(curr_gui) > elev_max_ref)
                                    elev_max(curr_gui) = elev_max_ref;
                                end
                                set(z_min_edit(curr_gui), 'string', sprintf('%4.0f', elev_min(curr_gui)))
                                set(z_max_edit(curr_gui), 'string', sprintf('%4.0f', elev_max(curr_gui)))
                                if (elev_min(curr_gui) < get(z_min_slide(curr_gui), 'min'))
                                    set(z_min_slide(curr_gui), 'value', get(z_min_slide(curr_gui), 'min'))
                                else
                                    set(z_min_slide(curr_gui), 'value', elev_min(curr_gui))
                                end
                                if (elev_max(curr_gui) > get(z_max_slide(curr_gui), 'max'))
                                    set(z_max_slide(curr_gui), 'value', get(z_max_slide(curr_gui), 'max'))
                                else
                                    set(z_max_slide(curr_gui), 'value', elev_max(curr_gui))
                                end
                            case 'depth'
                                tmp1 = depth_max - depth_min;
                                tmp2 = depth_max + (0.25 * tmp1);
                                if (tmp2 > depth_max_ref)
                                    depth_max = depth_max_ref;
                                else
                                    depth_max = tmp2;
                                end
                                depth_min = depth_max - tmp1;
                                if (depth_min < depth_min_ref)
                                    depth_min = depth_min_ref;
                                end
                                set(z_min_edit(curr_gui), 'string', sprintf('%4.0f', depth_max))
                                set(z_max_edit(curr_gui), 'string', sprintf('%4.0f', depth_min))
                                if ((depth_max_ref - (depth_max - depth_min_ref)) < get(z_min_slide(curr_gui), 'min'))
                                    set(z_min_slide(curr_gui), 'value', get(z_min_slide(curr_gui), 'min'))
                                elseif ((depth_max_ref - (depth_max - depth_min_ref)) > get(z_min_slide(curr_gui), 'max'))
                                    set(z_min_slide(curr_gui), 'value', get(z_min_slide(curr_gui), 'max'))
                                else
                                    set(z_min_slide(curr_gui), 'value', (depth_max_ref - (depth_max - depth_min_ref)))
                                end
                                if ((depth_max_ref - (depth_min - depth_min_ref)) < get(z_max_slide(curr_gui), 'min'))
                                    set(z_max_slide(curr_gui), 'value', get(z_max_slide(curr_gui), 'min'))
                                elseif ((depth_max_ref - (depth_min - depth_min_ref)) > get(z_max_slide(curr_gui), 'max'))
                                    set(z_max_slide(curr_gui), 'value', get(z_max_slide(curr_gui), 'max'))
                                else
                                    set(z_max_slide(curr_gui), 'value', (depth_max_ref - (depth_min - depth_min_ref)))
                                end
                        end
                        [curr_ax, curr_rad] = deal(2, 1);
                    case 3
                        [curr_ax, curr_rad] = deal(2, 1);
                        switch disp_type
                            case 'elev.'
                                tmp1 = elev_max(curr_gui) - elev_min(curr_gui);
                                tmp2 = elev_min(curr_gui) - (0.25 * tmp1);
                                if (tmp2 < elev_min_ref)
                                    elev_min(curr_gui) = elev_min_ref;
                                else
                                    elev_min(curr_gui) = tmp2;
                                end
                                elev_max(curr_gui)    = elev_min(curr_gui) + tmp1;
                                if (elev_max(curr_gui) > elev_max_ref)
                                    elev_max(curr_gui) = elev_max_ref;
                                end
                                set(z_min_edit(curr_gui), 'string', sprintf('%4.0f', elev_min(curr_gui)))
                                set(z_max_edit(curr_gui), 'string', sprintf('%4.0f', elev_max(curr_gui)))
                                if (elev_min(curr_gui) < get(z_min_slide(curr_gui), 'min'))
                                    set(z_min_slide(curr_gui), 'value', get(z_min_slide(curr_gui), 'min'))
                                else
                                    set(z_min_slide(curr_gui), 'value', elev_min(curr_gui))
                                end
                                if (elev_max(curr_gui) > get(z_max_slide(curr_gui), 'max'))
                                    set(z_max_slide(curr_gui), 'value', get(z_max_slide(curr_gui), 'max'))
                                else
                                    set(z_max_slide(curr_gui), 'value', elev_max(curr_gui))
                                end
                            case 'depth'
                                tmp1 = depth_max - depth_min;
                                tmp2 = depth_max + (0.25 * tmp1);
                                if (tmp2 > depth_max_ref)
                                    depth_max = depth_max_ref;
                                else
                                    depth_max = tmp2;
                                end
                                depth_min = depth_max - tmp1;
                                if (depth_min < depth_min_ref)
                                    depth_min = depth_min_ref;
                                end
                                set(z_min_edit(curr_gui), 'string', sprintf('%4.0f', depth_max))
                                set(z_max_edit(curr_gui), 'string', sprintf('%4.0f', depth_min))
                                if ((depth_max_ref - (depth_max - depth_min_ref)) < get(z_min_slide(curr_gui), 'min'))
                                    set(z_min_slide(curr_gui), 'value', get(z_min_slide(curr_gui), 'min'))
                                elseif ((depth_max_ref - (depth_max - depth_min_ref)) > get(z_min_slide(curr_gui), 'max'))
                                    set(z_min_slide(curr_gui), 'value', get(z_min_slide(curr_gui), 'max'))
                                else
                                    set(z_min_slide(curr_gui), 'value', (depth_max_ref - (depth_max - depth_min_ref)))
                                end
                                if ((depth_max_ref - (depth_min - depth_min_ref)) < get(z_max_slide(curr_gui), 'min'))
                                    set(z_max_slide(curr_gui), 'value', get(z_max_slide(curr_gui), 'min'))
                                elseif ((depth_max_ref - (depth_min - depth_min_ref)) > get(z_max_slide(curr_gui), 'max'))
                                    set(z_max_slide(curr_gui), 'value', get(z_max_slide(curr_gui), 'max'))
                                else
                                    set(z_max_slide(curr_gui), 'value', (depth_max_ref - (depth_min - depth_min_ref)))
                                end
                        end
                        [curr_ax, curr_rad] = deal(3, 2);
                end
                update_z_range
            case 'leftarrow'
                tmp1        = dist_max(curr_rad) - dist_min(curr_rad);
                tmp2        = dist_min(curr_rad) - (0.25 * tmp1);
                if (tmp2 < dist_min_ref(curr_rad))
                    dist_min(curr_rad) = dist_min_ref(curr_rad);
                else
                    dist_min(curr_rad) = tmp2;
                end
                dist_max(curr_rad) = dist_min(curr_rad) + tmp1;
                if (dist_max(curr_rad) > dist_max_ref(curr_rad))
                    dist_max(curr_rad) = dist_max_ref(curr_rad);
                end
                set(dist_min_edit(curr_rad), 'string', sprintf('%3.1f', dist_min(curr_rad)))
                set(dist_max_edit(curr_rad), 'string', sprintf('%3.1f', dist_max(curr_rad)))
                if (dist_min(curr_rad) < get(dist_min_slide(curr_rad), 'min'))
                    set(dist_min_slide(curr_rad), 'value', get(dist_min_slide(curr_rad), 'min'))
                else
                    set(dist_min_slide(curr_rad), 'value', dist_min(curr_rad))
                end
                if (dist_max(curr_rad) > get(dist_max_slide(curr_rad), 'max'))
                    set(dist_max_slide(curr_rad), 'value', get(dist_max_slide(curr_rad), 'max'))
                else
                    set(dist_max_slide(curr_rad), 'value', dist_max(curr_rad))
                end
                update_dist_range
            case 'rightarrow'
                tmp1        = dist_max(curr_rad) - dist_min(curr_rad);
                tmp2        = dist_max(curr_rad) + (0.25 * tmp1);
                if (tmp2 > dist_max_ref(curr_rad));
                    dist_max(curr_rad) ...
                            = dist_max_ref(curr_rad);
                else
                    dist_max(curr_rad) ...
                            = tmp2;
                end
                dist_min(curr_rad) ...
                            = dist_max(curr_rad) - tmp1;
                if (dist_min(curr_rad) < dist_min_ref(curr_rad))
                    dist_min(curr_rad) ...
                            = dist_min_ref(curr_rad);
                end
                set(dist_min_edit(curr_rad), 'string', sprintf('%3.1f', dist_min(curr_rad)))
                set(dist_max_edit(curr_rad), 'string', sprintf('%3.1f', dist_max(curr_rad)))
                if (dist_min(curr_rad) < get(dist_min_slide(curr_rad), 'min'))
                    set(dist_min_slide(curr_rad), 'value', get(dist_min_slide(curr_rad), 'min'))
                else
                    set(dist_min_slide(curr_rad), 'value', dist_min(curr_rad))
                end
                if (dist_max(curr_rad) > get(dist_max_slide(curr_rad), 'max'))
                    set(dist_max_slide(curr_rad), 'value', get(dist_max_slide(curr_rad), 'max'))
                else
                    set(dist_max_slide(curr_rad), 'value', dist_max(curr_rad))
                end
                update_dist_range
            case 'uparrow'
                if strcmp(disp_type, 'elev.')
                    tmp1 = elev_max(curr_gui) - elev_min(curr_gui);
                    tmp2 = elev_max(curr_gui) + (0.25 * tmp1);
                    if (tmp2 > elev_max_ref)
                        elev_max(curr_gui) = elev_max_ref;
                    else
                        elev_max(curr_gui) = tmp2;
                    end
                    elev_min(curr_gui) = elev_max(curr_gui) - tmp1;
                    if (elev_min(curr_gui) < elev_min_ref)
                        elev_min(curr_gui) = elev_min_ref;
                    end
                    set(z_min_edit(curr_gui), 'string', sprintf('%4.0f', elev_min(curr_gui)))
                    set(z_max_edit(curr_gui), 'string', sprintf('%4.0f', elev_max(curr_gui)))
                    if (elev_min(curr_gui) < get(z_min_slide(curr_gui), 'min'))
                        set(z_min_slide(curr_gui), 'value', get(z_min_slide(curr_gui), 'min'))
                    else
                        set(z_min_slide(curr_gui), 'value', elev_min(curr_gui))
                    end
                    if (elev_max(curr_gui) > get(z_max_slide(curr_gui), 'max'))
                        set(z_max_slide(curr_gui), 'value', get(z_max_slide(curr_gui), 'max'))
                    else
                        set(z_max_slide(curr_gui), 'value', elev_max(curr_gui))
                    end
                else
                    tmp1 = depth_max - depth_min;
                    tmp2 = depth_min - (0.25 * tmp1);
                    if (tmp2 < depth_min_ref)
                        depth_min = depth_min_ref;
                    else
                        depth_min = tmp2;
                    end
                    depth_max = depth_min + tmp1;
                    depth_min = depth_max - tmp1;
                    set(z_min_edit(curr_gui), 'string', sprintf('%4.0f', depth_max))
                    set(z_max_edit(curr_gui), 'string', sprintf('%4.0f', depth_min))
                    if ((depth_max_ref - (depth_max - depth_min_ref)) < get(z_min_slide(curr_gui), 'min'))
                        set(z_min_slide(curr_gui), 'value', get(z_min_slide(curr_gui), 'min'))
                    elseif ((depth_max_ref - (depth_max - depth_min_ref)) > get(z_min_slide(curr_gui), 'max'))
                        set(z_min_slide(curr_gui), 'value', get(z_min_slide(curr_gui), 'max'))
                    else
                        set(z_min_slide(curr_gui), 'value', (depth_max_ref - (depth_max - depth_min_ref)))
                    end
                    if ((depth_max_ref - (depth_min - depth_min_ref)) < get(z_max_slide(curr_gui), 'min'))
                        set(z_max_slide(curr_gui), 'value', get(z_max_slide(curr_gui), 'min'))
                    elseif ((depth_max_ref - (depth_min - depth_min_ref)) > get(z_max_slide(curr_gui), 'max'))
                        set(z_max_slide(curr_gui), 'value', get(z_max_slide(curr_gui), 'max'))
                    else
                        set(z_max_slide(curr_gui), 'value', (depth_max_ref - (depth_min - depth_min_ref)))
                    end
                end
                switch curr_ax
                    case 2
                        [curr_ax, curr_rad] = deal(3, 2);
                        switch disp_type
                            case 'elev.'
                                tmp1 = elev_max(curr_gui) - elev_min(curr_gui);
                                tmp2 = elev_max(curr_gui) + (0.25 * tmp1);
                                if (tmp2 > elev_max_ref)
                                    elev_max(curr_gui) = elev_max_ref;
                                else
                                    elev_max(curr_gui) = tmp2;
                                end
                                elev_min(curr_gui) = elev_max(curr_gui) - tmp1;
                                if (elev_min(curr_gui) < elev_min_ref)
                                    elev_min(curr_gui) = elev_min_ref;
                                end
                                set(z_min_edit(curr_gui), 'string', sprintf('%4.0f', elev_min(curr_gui)))
                                set(z_max_edit(curr_gui), 'string', sprintf('%4.0f', elev_max(curr_gui)))
                                if (elev_min(curr_gui) < get(z_min_slide(curr_gui), 'min'))
                                    set(z_min_slide(curr_gui), 'value', get(z_min_slide(curr_gui), 'min'))
                                else
                                    set(z_min_slide(curr_gui), 'value', elev_min(curr_gui))
                                end
                                if (elev_max(curr_gui) > get(z_max_slide(curr_gui), 'max'))
                                    set(z_max_slide(curr_gui), 'value', get(z_max_slide(curr_gui), 'max'))
                                else
                                    set(z_max_slide(curr_gui), 'value', elev_max(curr_gui))
                                end
                            case 'depth'
                                tmp1 = depth_max - depth_min;
                                tmp2 = depth_min - (0.25 * tmp1);
                                if (tmp2 < depth_min_ref)
                                    depth_min = depth_min_ref;
                                else
                                    depth_min = tmp2;
                                end
                                depth_max = depth_min + tmp1;
                                depth_min = depth_max - tmp1;
                                set(z_min_edit(curr_gui), 'string', sprintf('%4.0f', depth_max))
                                set(z_max_edit(curr_gui), 'string', sprintf('%4.0f', depth_min))
                                if ((depth_max_ref - (depth_max - depth_min_ref)) < get(z_min_slide(curr_gui), 'min'))
                                    set(z_min_slide(curr_gui), 'value', get(z_min_slide(curr_gui), 'min'))
                                elseif ((depth_max_ref - (depth_max - depth_min_ref)) > get(z_min_slide(curr_gui), 'max'))
                                    set(z_min_slide(curr_gui), 'value', get(z_min_slide(curr_gui), 'max'))
                                else
                                    set(z_min_slide(curr_gui), 'value', (depth_max_ref - (depth_max - depth_min_ref)))
                                end
                                if ((depth_max_ref - (depth_min - depth_min_ref)) < get(z_max_slide(curr_gui), 'min'))
                                    set(z_max_slide(curr_gui), 'value', get(z_max_slide(curr_gui), 'min'))
                                elseif ((depth_max_ref - (depth_min - depth_min_ref)) > get(z_max_slide(curr_gui), 'max'))
                                    set(z_max_slide(curr_gui), 'value', get(z_max_slide(curr_gui), 'max'))
                                else
                                    set(z_max_slide(curr_gui), 'value', (depth_max_ref - (depth_min - depth_min_ref)))
                                end
                        end
                        [curr_ax, curr_rad] = deal(2, 1);
                    case 3
                        [curr_ax, curr_rad] = deal(2, 1);
                        switch disp_type
                            case 'elev.'
                                tmp1 = elev_max(curr_gui) - elev_min(curr_gui);
                                tmp2 = elev_max(curr_gui) + (0.25 * tmp1);
                                if (tmp2 > elev_max_ref)
                                    elev_max(curr_gui) = elev_max_ref;
                                else
                                    elev_max(curr_gui) = tmp2;
                                end
                                elev_min(curr_gui) = elev_max(curr_gui) - tmp1;
                                if (elev_min(curr_gui) < elev_min_ref)
                                    elev_min(curr_gui) = elev_min_ref;
                                end
                                set(z_min_edit(curr_gui), 'string', sprintf('%4.0f', elev_min(curr_gui)))
                                set(z_max_edit(curr_gui), 'string', sprintf('%4.0f', elev_max(curr_gui)))
                                if (elev_min(curr_gui) < get(z_min_slide(curr_gui), 'min'))
                                    set(z_min_slide(curr_gui), 'value', get(z_min_slide(curr_gui), 'min'))
                                else
                                    set(z_min_slide(curr_gui), 'value', elev_min(curr_gui))
                                end
                                if (elev_max(curr_gui) > get(z_max_slide(curr_gui), 'max'))
                                    set(z_max_slide(curr_gui), 'value', get(z_max_slide(curr_gui), 'max'))
                                else
                                    set(z_max_slide(curr_gui), 'value', elev_max(curr_gui))
                                end
                            case 'depth'
                                tmp1 = depth_max - depth_min;
                                tmp2 = depth_min - (0.25 * tmp1);
                                if (tmp2 < depth_min_ref)
                                    depth_min = depth_min_ref;
                                else
                                    depth_min = tmp2;
                                end
                                depth_max = depth_min + tmp1;
                                depth_min = depth_max - tmp1;
                                set(z_min_edit(curr_gui), 'string', sprintf('%4.0f', depth_max))
                                set(z_max_edit(curr_gui), 'string', sprintf('%4.0f', depth_min))
                                if ((depth_max_ref - (depth_max - depth_min_ref)) < get(z_min_slide(curr_gui), 'min'))
                                    set(z_min_slide(curr_gui), 'value', get(z_min_slide(curr_gui), 'min'))
                                elseif ((depth_max_ref - (depth_max - depth_min_ref)) > get(z_min_slide(curr_gui), 'max'))
                                    set(z_min_slide(curr_gui), 'value', get(z_min_slide(curr_gui), 'max'))
                                else
                                    set(z_min_slide(curr_gui), 'value', (depth_max_ref - (depth_max - depth_min_ref)))
                                end
                                if ((depth_max_ref - (depth_min - depth_min_ref)) < get(z_max_slide(curr_gui), 'min'))
                                    set(z_max_slide(curr_gui), 'value', get(z_max_slide(curr_gui), 'min'))
                                elseif ((depth_max_ref - (depth_min - depth_min_ref)) > get(z_max_slide(curr_gui), 'max'))
                                    set(z_max_slide(curr_gui), 'value', get(z_max_slide(curr_gui), 'max'))
                                else
                                    set(z_max_slide(curr_gui), 'value', (depth_max_ref - (depth_min - depth_min_ref)))
                                end
                        end
                        [curr_ax, curr_rad] = deal(3, 2);
                end
                update_z_range
        end
    end

%% Mouse click

    function mouse_click(source, eventdata)
        tmp1                = get(source, 'currentpoint'); % picked x/y pixels
        tmp2                = get(fgui(2), 'position'); % figure x0/y0/w/h normalized
        tmp3                = [get(ax(2), 'position'); get(ax(3), 'position')]; % axis 1 x0/y0/w/h; 2 x0/y0/w/h normalized
        tmp4                = [(tmp2(1) + (tmp2(3) * tmp3(1, 1))) (tmp2(1) + (tmp2(3) * (tmp3(1, 1) + tmp3(1, 3)))); (tmp2(2) + (tmp2(4) * tmp3(1, 2))) (tmp2(2) + (tmp2(4) * (tmp3(1, 2) + tmp3(1, 4))))]; % 1 x0/y1;y0/y1 pixels
        tmp5                = [(tmp2(1) + (tmp2(3) * tmp3(2, 1))) (tmp2(1) + (tmp2(3) * (tmp3(2, 1) + tmp3(2, 3)))); (tmp2(2) + (tmp2(4) * tmp3(2, 2))) (tmp2(2) + (tmp2(4) * (tmp3(2, 2) + tmp3(2, 4))))]; % 2 x0/y1;y0/y1 pixels
        if ((tmp1(1) > (tmp4(1, 1))) && (tmp1(1) < (tmp4(1, 2))) && (tmp1(2) > (tmp4(2, 1))) && (tmp1(2) < (tmp4(2, 2))))
            [curr_gui, curr_ax, curr_rad, curr_rad_alt] ...
                            = deal(2, 2, 1, 2);
            switch disp_type
                case 'elev.'
                    tmp1    = [((tmp1(1) - tmp4(1, 1)) / diff(tmp4(1, :))) ((tmp1(2) - tmp4(2, 1)) / diff(tmp4(2, :)))];
                case 'depth'
                    tmp1    = [((tmp1(1) - tmp4(1, 1)) / diff(tmp4(1, :))) ((tmp4(2, 2) - tmp1(2)) / diff(tmp4(2, :)))];
            end
            tmp2            = [get(ax(curr_ax), 'xlim'); get(ax(curr_ax), 'ylim')];
            [ind_x_pk, ind_y_pk] ...
                            = deal(((tmp1(1) * diff(tmp2(1, :))) + tmp2(1, 1)), ((tmp1(2) * diff(tmp2(2, :))) + tmp2(2, 1)));
            pk_select_gui_breakout
        elseif ((tmp1(1) > (tmp5(1, 1))) && (tmp1(1) < (tmp5(1, 2))) && (tmp1(2) > (tmp5(2, 1))) && (tmp1(2) < (tmp5(2, 2))))
            [curr_gui, curr_ax, curr_rad, curr_rad_alt] ...
                            = deal(2, 3, 2, 1);
            switch disp_type
                case 'elev.'
                    tmp1    = [((tmp1(1) - tmp5(1, 1)) / diff(tmp5(1, :))) ((tmp1(2) - tmp5(2, 1)) / diff(tmp5(2, :)))];
                case 'depth'
                    tmp1    = [((tmp1(1) - tmp5(1, 1)) / diff(tmp5(1, :))) ((tmp5(2, 2) - tmp1(2)) / diff(tmp5(2, :)))];
            end
            tmp2            = [get(ax(curr_ax), 'xlim'); get(ax(curr_ax), 'ylim')];
            [ind_x_pk, ind_y_pk] ...
                            = deal(((tmp1(1) * diff(tmp2(1, :))) + tmp2(1, 1)), ((tmp1(2) * diff(tmp2(2, :))) + tmp2(2, 1)));
            pk_select_gui_breakout
        end
    end

%% Test something

    function misctest(source, eventdata)
        
        set(status_box, 'string', 'Test done.')
    end
%%
end