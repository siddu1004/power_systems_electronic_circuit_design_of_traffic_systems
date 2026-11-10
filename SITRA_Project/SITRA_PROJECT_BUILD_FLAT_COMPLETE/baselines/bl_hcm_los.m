function los = bl_hcm_los(d)
%BL_HCM_LOS  HCM level of service for a signalised intersection.
%   d = average control delay [s/veh].
%   A <= 10 < B <= 20 < C <= 35 < D <= 55 < E <= 80 < F
%   (HCM also assigns F whenever v/c > 1; T4 is oversaturated by design.)
if d <= 10,      los = 'A';
elseif d <= 20,  los = 'B';
elseif d <= 35,  los = 'C';
elseif d <= 55,  los = 'D';
elseif d <= 80,  los = 'E';
else,            los = 'F';
end
end
