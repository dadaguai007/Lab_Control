function data = data_preprocess(data,arbConfig)
normalize = 1;
%% Convert data into column vector
if (isvector(data) && size(data,2) > 1)
    data = data.';
end
%% Check if the data length satisfies the segment requirement
len = length(data);
if (mod(len, arbConfig.segmentGranularity) ~= 0)
    errordlg(['Segment size is ' num2str(len) ', must be a multiple of ' num2str(arbConfig.segmentGranularity)], 'Error');
    return;
elseif (len < arbConfig.minimumSegmentSize && len ~= 0)
    errordlg(['Segment size is ' num2str(len) ', must be >= ' num2str(arbConfig.minimumSegmentSize)], 'Error');
    return;
elseif (len > arbConfig.maximumSegmentSize)
    errordlg(['Segment size is ' num2str(len) ', must be <= ' num2str(arbConfig.maximumSegmentSize)], 'Error');
    return;
end
%% normalize if required
if (normalize && ~isempty(data))
    scale = max(max(abs(real(data(:,1)))), max(abs(imag(data(:,1)))));
    if (scale > 1)
        if (normalize)
            data(:,1) = data(:,1) / scale;
        else
            errordlg('Data must be in the range -1...+1', 'Error');
        end
    end
end

%% Set the DACRange if required
if (isfield(arbConfig, 'DACRange') && arbConfig.DACRange ~= 1)
    data = data .* arbConfig.DACRange;
end
    
%% apply I/Q gainCorrection if necessary
if (isfield(arbConfig, 'gainCorrection') && arbConfig.gainCorrection ~= 0)
    data = complex(real(data) * 10^(arbConfig.gainCorrection/20), imag(data));
    scale = max(max(real(data)), max(imag(data)));
    if (scale > 1)
        data = data ./ scale;
    end
end