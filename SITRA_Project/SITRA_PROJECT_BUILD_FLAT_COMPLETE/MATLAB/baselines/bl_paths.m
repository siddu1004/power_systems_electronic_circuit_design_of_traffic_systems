function [root, outDir] = bl_paths()
%BL_PATHS  Put the frozen SITRA functions on the path and pick the output folder.
%
%   Expected layout (after setup_SITRA_folders):
%       <root>/MATLAB/createNetwork.m, mpcSignalModel.m, part8_...m
%       <root>/MATLAB/baselines/bl_*.m        <- these files
%       <root>/Results/baselines/             <- outputs
%   A flat layout (frozen files in the parent of baselines/) also works.

here = fileparts(mfilename('fullpath'));
code = fileparts(here);              % folder holding createNetwork.m
addpath(here);
addpath(code);
[~, codeName] = fileparts(code);
if strcmpi(codeName, 'MATLAB')
    root = fileparts(code);
else
    root = code;
end
outDir = fullfile(root, 'Results', 'baselines');
if ~exist(outDir, 'dir')
    mkdir(outDir);
end
if exist('createNetwork','file') ~= 2 || exist('mpcSignalModel','file') ~= 2
    error(['bl_paths: createNetwork.m / mpcSignalModel.m not found. ' ...
           'Put the baselines folder inside the folder that holds them.']);
end
end
