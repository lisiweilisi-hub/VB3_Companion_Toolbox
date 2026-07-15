function R = SPT_FigureCircularResultant(thetaDeg)
% SPT_FigureCircularResultant
% Circular resultant length in degrees for Figure Framework v2.
% MATLAB R2016b compatible.

thetaDeg = thetaDeg(:);
thetaDeg = thetaDeg(isfinite(thetaDeg));

if isempty(thetaDeg)
    R = NaN;
    return;
end

thetaRad = thetaDeg * pi / 180;
z = mean(exp(1i * thetaRad));
R = abs(z);

end