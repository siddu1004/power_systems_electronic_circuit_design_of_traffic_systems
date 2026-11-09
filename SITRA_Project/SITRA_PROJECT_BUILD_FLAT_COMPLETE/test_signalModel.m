%% PART 4A — SIGNAL MODEL UNIT TEST

clear;
clc;

% Create network
net = createNetwork();

% Signal parameters
params = struct('green',18,'yellow',3);

fprintf('\n');
fprintf('=====================================\n');
fprintf('SIGNAL MODEL UNIT TEST\n');
fprintf('=====================================\n\n');

% Test times
testTimes = [0 5 17 18 20 21 38 39 41 42 59 60 62 63 65];

for i = 1:numel(testTimes)

    t = testTimes(i);

    active = signalModel(t,net,params);

    fprintf('t = %3d s  ->  active = %d\n', ...
        t, active);

end

fprintf('\n');
fprintf('Expected timing:\n');

fprintf('B1 green :  0 - 17 s\n');
fprintf('Yellow   : 18 - 20 s\n');

fprintf('B2 green : 21 - 38 s\n');
fprintf('Yellow   : 39 - 41 s\n');

fprintf('B3 green : 42 - 59 s\n');
fprintf('Yellow   : 60 - 62 s\n');

fprintf('B1 repeats at 63 s\n');

fprintf('\n');
fprintf('=====================================\n');
fprintf('UNIT TEST COMPLETE\n');
fprintf('=====================================\n');