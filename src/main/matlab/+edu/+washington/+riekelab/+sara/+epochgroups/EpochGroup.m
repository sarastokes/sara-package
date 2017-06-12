classdef (Abstract) EpochGroup < symphonyui.core.persistent.descriptions.EpochGroupDescription

methods
  function obj = EpochGroup()
    import symphonyui.core.*;

    obj.addProperty('externalSolutionAdditions', {},...
      'Type', PropertyType('cellstr', 'row', {'14 mM D-glucose', 'APB (10 uM)', 'APB (7.5uM)', 'LY 341359 (10uM)', 'gabazine (25uM)', 'TPMPA (50uM)'}));
    obj.addProperty('pipetteSolution', 'Ames',...
      'Type', PropertyType('char', 'row', {'Ames', 'CMS', 'K-Asp', 'neurobiotin', '1% biocytin', 'lucifer yellow', 'Alexa-488'}));
    obj.addProperty('seriesResistanceCompensation', int32(0),...
      'Type', PropertyType('int32', 'scalar', [0 100]));
  end
end
end
