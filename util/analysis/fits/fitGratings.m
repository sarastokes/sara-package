function f = fitGratings(sf, F1)
    % sf = spatial frequencies
    % F1 = f1amplitude

	g2fun = @(v,x)(v(5)*abs(v(1)*pi*v(2)^2 * exp(-(pi*v(2)*x).^2) - v(3)*pi*v(4)^2*exp(-(pi*v(4)*x).^2)));
    gfun = @(v,x)((v(1)*exp(-(x*v(2)/2).^2) - v(3)*exp(-(x*v(4)/2).^2)));
	xaxis=-4:0.01:4;%10.^(-2:0.1:1);

    f.vars1 = lsqcurvefit(@DoG1D,[100 1 25 2 0], sf, F1);
    f.fit1 = DoG1D(f.vars1, sf); 
    f.gaussian1 = gfun(f.vars1, xaxis);

	f.vars2 = lsqcurvefit(g2fun, [2 0.45 400 0.02 10], sf, F1);
	f.fit2 = g2fun(f.vars2,sf);
	f.center = exp(-(xaxis*f.vars2(2)*pi*10).^2);
	f.center = f.vars2(1)*(f.center/sum(f.center));
	f.surround = exp(-(xaxis*f.vars2(4)*pi*10).^2);
	f.surround = f.vars2(3)*(f.surround/sum(f.surround));
	f.gaussian2 = f.center/max(f.center) - 0.5*f.surround/max(f.surround);
end