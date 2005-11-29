function handles = CalculateStatistics(handles)

% Help for the Calculate Statistics module:
% Category: Other
%
% SHORT DESCRIPTION:
% Calculates the V and Z' factors for measurements made from images.
% *************************************************************************
%
% The V and Z' factors are statistical measures of assay quality and are
% calculated for each measurement that you have made in the pipeline. This
% allows you to choose which measures are most powerful for distinguishing
% positive and negative control samples. You must tell the module which
% samples are positive and negative controls, or the concentrations of
% drugs, in a simple text file with one entry per cycle, loaded using
% the Load Text module.
%
% The reference for Z' factor is: JH Zhang, TD Chung, et al. (1999) "A
% simple statistical parameter for use in evaluation and validation of high
% throughput screening assays." J Biomolecular Screening 4(2): 67-73.
%
% The reference for V factor is: I Ravkin (2004): Poster #P12024 - Quality
% Measures for Imaging-based Cellular Assays. Society for Biomolecular
% Screening Annual Meeting Abstracts.
%
% See also <nothing relevant>.

% CellProfiler is distributed under the GNU General Public License.
% See the accompanying file LICENSE for details.
%
% Developed by the Whitehead Institute for Biomedical Research.
% Copyright 2003,2004,2005.
%
% Authors:
%   Anne Carpenter
%   Thouis Jones
%   In Han Kang
%   Ola Friman
%   Steve Lowe
%   Joo Han Chang
%   Colin Clarke
%   Mike Lamprecht
%   Susan Ma
%   Wyman Li
%
% Website: http://www.cellprofiler.org
%
% $Revision: 1725 $

%%%%%%%%%%%%%%%%%
%%% VARIABLES %%%
%%%%%%%%%%%%%%%%%
drawnow

[CurrentModule, CurrentModuleNum, ModuleName] = CPwhichmodule(handles);

%textVAR01 = What did you call the grouping values?
%infotypeVAR01 = datagroup
%inputtypeVAR01 = popupmenu
DataName = char(handles.Settings.VariableValues{CurrentModuleNum,1});

%textVAR02 = In order to run this module, you must use the Load Text module to load a grouping value for each cycle. This is either a marking of whether each cycle is a positive or negative control (for Z factor) or it is concentrations (doses) for each curve (required for meaningful V factors). Both Z and V factors will be calculated for all measured values (Intensity, AreaShape, Texture, etc.). These measurements can be exported as the "Experiment" set of data.

%%%VariableRevisionNumber = 2

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% PRELIMINARY CALCULATIONS %%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
drawnow

if handles.Current.SetBeingAnalyzed == handles.Current.NumberOfImageSets

    %%% Get all fieldnames in Measurements
    ObjectFields = fieldnames(handles.Measurements);

    GroupingStrings = handles.Measurements.Image.(DataName);
    %%% Need column vector
    GroupingValues = str2num(char(GroupingStrings'));

    for i = 1:length(ObjectFields)

        ObjectName = char(ObjectFields(i));

        if strcmp(ObjectName,'Results')
            test=eps;
        end
        %%% Filter out Experiment and Image fields
        if ~strcmp(ObjectName,'Experiment') && ~strcmp(ObjectName,'Image')

            try
                %%% Get all fieldnames in Measurements.(ObjectName)
                MeasureFields = fieldnames(handles.Measurements.(ObjectName));
            catch %%% Must have been text field and ObjectName is class 'cell'
                continue
            end

            for j = 1:length(MeasureFields)

                MeasureFeatureName = char(MeasureFields(j));

                if length(MeasureFeatureName) > 7
                    if strcmp(MeasureFeatureName(end-7:end),'Features')

                        %%% Not placed with above if statement since
                        %%% MeasureFeatureName may not be 8 characters long
                        if ~strcmp(MeasureFeatureName(1:8),'Location')

                            %%% Get Features
                            MeasureFeatures = handles.Measurements.(ObjectName).(MeasureFeatureName);

                            %%% Get Measure name
                            MeasureName = MeasureFeatureName(1:end-8);
                            %%% Check for measurements
                            if ~isfield(handles.Measurements.(ObjectName),MeasureName)
                                error(['Image processing was canceled in the ', ModuleName, ' module because it could not find the measurements you specified.']);
                            end

                            Ymatrix = zeros(length(handles.Current.NumberOfImageSets),length(MeasureFeatures));
                            for k = 1:handles.Current.NumberOfImageSets
                                for l = 1:length(MeasureFeatures)
                                        Ymatrix(k,l) = mean(handles.Measurements.(ObjectName).(MeasureName){k}(:,l));
                                end
                            end

                            [v, z] = VZfactors(GroupingValues,Ymatrix);

                            measurefield = [ObjectName,'Statistics'];
                            featuresfield = [ObjectName,'StatisticsFeatures'];
                            if isfield(handles.Measurements,'Experiment')
                                if isfield(handles.Measurements.Experiment,measurefield)
                                    OldEnd = length(handles.Measurements.Experiment.(featuresfield));
                                    for a = 1:length(z)
                                        handles.Measurements.Experiment.(measurefield){1}(1,OldEnd+a) = z(a);
                                        handles.Measurements.Experiment.(measurefield){1}(1,OldEnd+length(z)+a) = v(a);
                                        handles.Measurements.Experiment.(featuresfield){OldEnd+a} = ['Zfactor_',MeasureFeatures{a}];
                                        handles.Measurements.Experiment.(featuresfield){OldEnd+length(z)+a} = ['Vfactor_',MeasureFeatures{a}];
                                    end
                                else
                                    for a = 1:length(z)
                                        handles.Measurements.Experiment.(measurefield){1}(1,a) = z(a);
                                        handles.Measurements.Experiment.(measurefield){1}(1,length(z)+a) = v(a);
                                        handles.Measurements.Experiment.(featuresfield){a} = ['Zfactor_',MeasureFeatures{a}];
                                        handles.Measurements.Experiment.(featuresfield){length(z)+a} = ['Vfactor_',MeasureFeatures{a}];
                                    end
                                end
                            else
                                for a = 1:length(z)
                                    handles.Measurements.Experiment.(measurefield){1}(1,a) = z(a);
                                    handles.Measurements.Experiment.(measurefield){1}(1,length(z)+a) = v(a);
                                    handles.Measurements.Experiment.(featuresfield){a} = ['Zfactor_',MeasureFeatures{a}];
                                    handles.Measurements.Experiment.(featuresfield){length(z)+a} = ['Vfactor_',MeasureFeatures{a}];
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end

%%%%%%%%%%%%%%%%%%%%%%%
%%% DISPLAY RESULTS %%%
%%%%%%%%%%%%%%%%%%%%%%%
drawnow

ThisModuleFigureNumber = handles.Current.(['FigureNumberForModule',CurrentModule]);
%%% Closes the window if it is open.
if any(findobj == ThisModuleFigureNumber) == 1;
    close(ThisModuleFigureNumber)
end

%%%%%%%%%%%%%%%%%%%%
%%% SUBFUNCTIONS %%%
%%%%%%%%%%%%%%%%%%%%
drawnow

function [v, z] = VZfactors(xcol, ymatr)
% xcol is (Nobservations,1) column vector of grouping values
% (in terms of dose curve it may be Dose).
% ymatr is (Nobservations, Nmeasures) matrix, where rows correspond to observations
% and columns corresponds to different measures.
% v, z are (1, Nmeasures) row vectors containing V- and Z-factors
% for the corresponding measures.
[xs, avers, stds] = LocShrinkMeanStd(xcol, ymatr);
range = max(avers) - min(avers);
cnstns = find(range == 0);
if (length(cnstns) > 0)
    range(cnstns) = 0.000001;
end
vstd = mean(stds);
v = 1 - 6 .* (vstd ./ range);
zstd = stds(1, :) + stds(length(xs), :);
z = 1 - 3 .* (zstd ./ range);
return

function [xs, avers, stds] = LocShrinkMeanStd(xcol, ymatr)

ncols = size(ymatr,2);
[labels, labnum, xs] = LocVectorLabels(xcol);
avers = zeros(labnum, ncols);
stds = avers;
for ilab = 1 : labnum
    labinds = find(labels == ilab);
    labmatr = ymatr(labinds,:);
    avers(ilab, :) = mean(labmatr);
    stds(ilab, :) = std(labmatr, 1);
end

function [labels, labnum, uniqsortvals] = LocVectorLabels(x)
%
n = length(x);
labels = zeros(1, n);
[srt, inds] = sort(x);
prev = srt(1) - 1; % absent value
labnum = 0;
uniqsortvals = labels;
for i = 1 : n
    nextval = srt(i);
    if (nextval ~= prev) % 1-st time for sure
        prev = srt(i);
        labnum = labnum + 1;
        uniqsortvals(labnum) = nextval;
    end
    labels(inds(i)) = labnum;
end
uniqsortvals = uniqsortvals(1 : labnum);