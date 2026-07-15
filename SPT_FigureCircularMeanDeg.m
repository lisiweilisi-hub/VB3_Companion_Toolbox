function mu = SPT_FigureCircularMeanDeg(thetaDeg)
% SPT_FigureCircularMeanDeg
% Circular mean in degrees for Figure Framework v2.
% MATLAB R2016b compatible.

thetaDeg = thetaDeg(:);
thetaDeg = thetaDeg(isfinite(thetaDeg));

if isempty(thetaDeg)
    mu = NaN;
    return;
end

thetaRad = thetaDeg * pi / 180;
z = mean(exp(1i * thetaRad));

if abs(z) < eps
    mu = NaN;
else
    mu = angle(z) * 180 / pi;
    if mu > 180
        mu = mu - 360;
    elseif mu <= -180
        mu = mu + 360;
    end
end

end