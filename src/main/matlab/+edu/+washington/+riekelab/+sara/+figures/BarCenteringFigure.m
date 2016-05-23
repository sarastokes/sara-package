classdef BarCenteringFigure < symphonyui.core.FigureHandler
  properties (SetAccess = private)
    device
    recordingType
    orientation
    position
  end

  properties (Access = private)
    axesHandle
    strf
  end

  methods
  function obj = SpatialNoiseFigure(device,varargin)
    ip = inputParser();
    ip.addParameter('groupBy', [], @(x)iscellstr(x));
    ip.addParameter('sweepColor', co(1,:), @(x)ischar(x) || isvector(x));
    ip.addParameter('storedSweepColor', 'r', @(x)ischar(x) || isvector(x));
    ip.addParameter('recordingType', [], @(x)ischar(x));
    ip.parse(varargin{:});

    obj.device = device;
    obj.recordingType = ip.Results.recordingType;
    obj.orientation = ip.Results.orientation;
    obj.position = ip.Results.position;

    obj.createUi();
  end

  function createUi(obj)
    import appbox.*;

    toolbar = findall(obj.figureHandle, 'Type','uitoolbar');

    obj.axesHandle = axes('Parent', obj.figureHandle,...
      'FontName', get(obj.figureHandle, 'DefaultUicontrolFontName'), 'FontSize', get(obj.figureHandle,'DefaultUicontrolFontSize'),...
      'XTickMode','auto');
    xlabel(obj.axesHandle,'sec');
    obj.sweeps = {};

    obj.setTitle([obj.device.name ' Mean Response']);
  end

  function setTitle(obj,t)
    set(obj.figureHandle,'Name',t);
    title(obj.axesHandle,t);
