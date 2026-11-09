%% setup_SITRA_folders.m
% One-time fix: the flat zip -> the layout run_all_SITRA expects.
%   <root>/run_all_SITRA.m, build_SITRA_S*.m, test_SITRA_S*.m, setup_SITRA_folders.m
%   <root>/MATLAB/            all other .m files
%   <root>/Documentation/     README.md, BUILD_LOG.md, *.txt
% Run once from the folder that contains the .m files. Safe to re-run.
root = pwd;
keep = {'run_all_SITRA.m','setup_SITRA_folders.m'};
if ~exist('MATLAB','dir'), mkdir('MATLAB'); end
if ~exist('Documentation','dir'), mkdir('Documentation'); end

f = dir('*.m');
for k = 1:numel(f)
    n = f(k).name;
    isStage = startsWith(n,'build_SITRA_S') || startsWith(n,'test_SITRA_S');
    if any(strcmp(n,keep)) || isStage, continue; end
    movefile(n, fullfile('MATLAB',n));
    fprintf('  moved %-45s -> MATLAB/\n', n);
end
for ext = {'*.md','*.txt'}
    d = dir(ext{1});
    for k = 1:numel(d)
        movefile(d(k).name, fullfile('Documentation',d(k).name));
    end
end
fprintf('\nLayout ready in %s\nNext: run_all_SITRA\n', root);
