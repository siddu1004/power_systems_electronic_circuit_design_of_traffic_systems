%% validate_SITRA_Project_Structure.m
% Checks project structure and common self-referential signalModel errors.
clc;

thisFile = mfilename('fullpath');
matlabFolder = fileparts(thisFile);
projectRoot = fileparts(matlabFolder);

required = { ...
    'createNetwork.m', ...
    'part8_mpc_controller.m', ...
    'mpcSignalModel.m', ...
    'run_SITRA_Master_Simulation.m'};

fprintf('\n============================================================\n');
fprintf('SITRA PROJECT STRUCTURE VALIDATION\n');
fprintf('============================================================\n');

allOK = true;
for k = 1:numel(required)
    ok = exist(fullfile(matlabFolder,required{k}),'file') == 2;
    fprintf('%-40s %s\n',required{k},passfail(ok));
    allOK = allOK && ok;
end

signalFile = fullfile(matlabFolder,'signalModel.m');
if exist(signalFile,'file') == 2
    txt = fileread(signalFile);
    % Ignore the function declaration itself and search for additional calls.
    declaration = regexp(txt,'function\s+[^\n]*signalModel\s*\([^\n]*\)','once','match');
    body = strrep(txt,declaration,'');
    recursiveCall = ~isempty(regexp(body,'\bsignalModel\s*\(','once'));
    signalOK = ~recursiveCall;
    fprintf('%-40s %s\n','signalModel self-recursion check',passfail(signalOK));
    allOK = allOK && signalOK;
else
    fprintf('%-40s %s\n','signalModel self-recursion check','NOT FOUND');
end

fprintf('------------------------------------------------------------\n');
fprintf('PROJECT STRUCTURE STATUS = %s\n',passfail(allOK));
fprintf('============================================================\n');

function txt = passfail(tf)
if tf, txt = 'PASS'; else, txt = 'FAIL'; end
end
