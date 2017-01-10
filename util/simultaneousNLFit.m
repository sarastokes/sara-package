dfunction y = simultaneousNLFit(params, xData)
    % xData is binned
    % 1 = mean
    % 2 = SD
    % 3 = spike rate (same for LMS)
    % 4 = scale factor for M
    % 5 = scale factor for S


y = [params(1)*normcdf(xData(1,:), params(2), params(3)), params(1)*normcdf(xData(2,:)*params(4), params(2), params(3)), params(1)*normcdf(xData(3,:)*params(5), params(2), params(3))];

