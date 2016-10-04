function printCellSummary(CELL)
%% not great but gets the job done

if ~strcmp(class(CELL), 'symphonyui.core.persistent.Source')
	error('Input must be a source for now');
end

fprintf('SOURCE = %s\n', CELL.label);
for eg = 1:length(CELL.getEpochGroups)
	eGroup = CELL.getEpochGroups{eg};
	fprintf('GROUP %u (%u blocks) - %s\n', eg, length(eGroup.getEpochBlocks), eGroup.label);
	for eb = 1:length(eGroup.getEpochBlocks)
		eBlock = eGroup.getEpochBlocks{eb};
		protocolId = strsplit(eBlock.protocolId,'.');
		protocolId = protocolId{end};

		if isKey(eBlock.protocolParameters, 'chromaticClass') == 1
			chromaticClass = eBlock.protocolParameters('chromaticClass');
		elseif isKey(eBlock.protocolParameters,'stimClass') == 1
			chromaticClass = upper(eBlock.protocolParameters('stimClass'));
		% elseif strcmp(protocolId, 'SingleSpot')
		% 	chromaticClass = '';
		else			
			chromaticClass = 'achromatic';
		end

		epoch = eBlock.getEpochs{1};
		if isKey(epoch.protocolParameters, 'objectiveMag')
			objMag = num2str(epoch.protocolParameters('objectiveMag'));
		else
			objMag = '?'; % forgot riekelab protocols don't have this
		end
		if isKey(epoch.protocolParameters, 'ndf')
			ndf = epoch.protocolParameters('ndf');
		else
			ndf = '?';
		end

		% init the output string
		str = sprintf(' -- BLOCK %u (%u epochs) - %s, %s, (%sx)', eb, length(eBlock.getEpochs), protocolId, chromaticClass, objMag);
		% add protocol specific properties
		if ndf ~= 2
			str = [str ', ' num2str(ndf) 'ndf'];
		end
		propStr = sortProtocolProperties();

		% print
		fprintf('%s, %s\n', str, propStr);
	end
end

% put somewhere else later
function propStr = sortProtocolProperties()
	switch protocolId
	case 'ChromaticSpot'
		% TODO: innerRadius/annulus
		radius = eBlock.protocolParameters('outerRadius');
		if radius >= 1000
			radius = 'FF';
		else
			radius = [num2str(radius) 'r'];
		end
		intensity = eBlock.protocolParameters('contrast');
		if intensity > 0
			intensity = num2str(intensity * 100);
		elseif intensity < 0
			intensity = sprintf('-%s', num2str(-100 * intensity));
		else
			intensity = 'Baseline';
		end
		propStr = sprintf(', %s%s, %s', intensity, '%', radius);

	case 'SingleSpot'
		radius = ceil(eBlock.protocolParameters('spotDiameter') / 2);
		if radius >= 1000
			radius = 'FF';
		else
			radius = [num2str(radius) 'r'];
		end
		intensity = eBlock.protocolParameters('spotIntensity');
		if intensity > 0
			intensity = num2str(intensity * 100);
		elseif intensity < 0
			intensity = sprintf('-%s', num2str(-100 * intensity));
		else
			intensity = 'Baseline';
		end
		propStr = sprintf(', %s%s, %s', intensity, '%', radius);

	case 'GaussianNoise'
		propStr = sprintf(', %.2fsd, %s', eBlock.protocolParameters('stdev'), eBlock.protocolParameters('stimulusClass'));

	case 'SpatialNoise'
		propStr = sprintf(', %s, %ustx', eBlock.protocolParameters('noiseClass'), eBlock.protocolParameters('stixelSize'));

	case 'ConeSweep'
		if eBlock.protocolParameters('radius') >= 1000
			radius = 'FF';
		else
			radius = [num2str(eBlock.protocolParameters('radius')) 'r'];
		end
		propStr = sprintf(', %s, %uhz, %s', eBlock.protocolParameters('temporalClass'), eBlock.protocolParameters('temporalFrequency'), radius);
		if strcmp('annulus', epoch.protocolParameters('stimulusClass'))
			propStr = ['annulus, ' propStr];
		end
		if eBlock.protocolParameters('equalQuantalCatch') == 1
			propStr = ['eQCatch, ' propStr];
		else
			intensity = 100 * eBlock.protocolParameters('contrast');
			propStr = [num2str(intensity) '%, ' propStr];
		end


	case 'TempChromaticGrating'
		propStr = sprintf(', %u, %s, %sdeg', (100*eBlock.protocolParameters('contrast')), eBlock.protocolParameters('temporalClass'), num2str(eBlock.protocolParameters('orientation')));

	case 'IsoSTC'
		propStr = sprintf(', %s', eBlock.protocolParameters('paradigmClass'));

	case 'BarCentering'
		propStr = sprintf(', %s, %s, %.2f mean', eBlock.protocolParameters('searchAxis'), eBlock.protocolParameters('temporalClass'), eBlock.protocolParameters('backgroundIntensity'));

	otherwise
		propStr = '';

	end % switch protocolId
end % sortProtocolProperties
end % printCellSummary