% Determine whether two spherical points (unit radius) may be considered close
% or antipodal.
function [close, antipodal, p, q, anglePq_deg] = getAngleInfo(az1_deg, el1_deg, ...
    az2_deg, el2_deg, threshold_deg)

    % These logicals are mutually exclusive.
    close = false;
    antipodal = false;
    
    deg2rad = pi / 180.;
    rad2deg = 180. / pi;

    [pN, pE, pD] = sph2NED_deg(az1_deg, el1_deg, 1.);
    [qN, qE, qD] = sph2NED_deg(az2_deg, el2_deg, 1.);

    p = [pN, pE, pD];
    q = [qN, qE, qD];

    dotPq = dot(p, q);
    anglePq_deg = acos(dotPq) * rad2deg;

    if (anglePq_deg > (180.0 - threshold_deg))
        antipodal = true;
    elseif (anglePq_deg < threshold_deg)
        close = true;
    end

end % getAngleInfo