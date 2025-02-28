function result = iqdownload(iqdata, fs, varargin)
% Download a vector of I/Q samples to the configured AWG
% - iqdata - contains a row-vector of complex I/Q samples
%            additional columns may contain marker info
% - fs - sampling rate in Hz
% optional arguments are specified as attribute/value pairs:
% - 'segmentNumber' - specify the segment number to use (default = 1)
% - 'normalize' - auto-scale the data to max. DAC range (default = 1)
% - 'downloadToChannel - string that describes to which AWG channel
%              the data is downloaded. (deprecated, please use
%              'channelMapping' instead)
% - 'channelMapping' - new format for AWG channel mapping:
%              vector with 2 columns and 1..n rows. Columns represent 
%              I and Q, rows represent AWG channels. Each element is either
%              1 or 0, indicating whether the signal is downloaded to
%              to the respective channel
% - 'sequence' - description of the sequence table 
% - 'marker' - vector of integers that must have the same length as iqdata
%              low order bits correspond to marker outputs
% - 'arbConfig' - struct as described in loadArbConfig (default: [])
% - 'keepOpen' - if set to 1, will keep the connection to the AWG open
%              after downloading the waveform
% - 'run' - determines if the AWG will be started immediately after
%              downloading the waveform/sequence. (default: 1)
%
% If arbConfig is not specified, the file "arbConfig.mat" is expected in
% the current directory.
%
% Thomas Dippon, Keysight Technologies 2011-2016
%
% Disclaimer of Warranties: THIS SOFTWARE HAS NOT COMPLETED KEYSIGHT'S FULL
% QUALITY ASSURANCE PROGRAM AND MAY HAVE ERRORS OR DEFECTS. KEYSIGHT MAKES 
% NO EXPRESS OR IMPLIED WARRANTY OF ANY KIND WITH RESPECT TO THE SOFTWARE,
% AND SPECIFICALLY DISCLAIMS THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
% FITNESS FOR A PARTICULAR PURPOSE.
% THIS SOFTWARE MAY ONLY BE USED IN CONJUNCTION WITH KEYSIGHT INSTRUMENTS. 

%% parse optional arguments
segmNum = 1;
result = [];
keepOpen = 0;
normalize = 1;
downloadToChannel = [];
channelMapping = [];
sequence = [];
arbConfig = [];
clear marker;
run = 1;
for i = 1:nargin-2
    if (ischar(varargin{i}))
        switch lower(varargin{i})
            case 'segmentnumber';  segmNum = varargin{i+1};
            case 'keepopen'; keepOpen = varargin{i+1};
            case 'normalize'; normalize = varargin{i+1};
            case 'downloadtochannel'; downloadToChannel = varargin(i+1);
            case 'channelmapping'; channelMapping = varargin{i+1};
            case 'marker'; marker = varargin{i+1};
            case 'sequence'; sequence = varargin{i+1};
            case 'arbconfig'; arbConfig = varargin{i+1};
            case 'run'; run = varargin{i+1};
        end
    end
end

if (ischar(channelMapping))
    error('unexpected format for parameter channelMapping: string');
end

% try to load the configuration from the file arbConfig.mat
% arbConfig = loadArbConfig(arbConfig); % changed by TW



%% extract markers - assume there are two markers per channel
    marker1 = [];
    marker2 = [];
    
%% establish a connection and download the data
    switch (arbConfig.model)
        case { 'M8195A_1ch' 'M8195A_2ch' 'M8195A_4ch' 'M8195A_2ch_256k' 'M8195A_4ch_256k' }
            result = iqdownload_M8195A(arbConfig, fs, data, marker1, marker2, segmNum, keepOpen, channelMapping, sequence, run);
        case { 'M8196A' }
            result = iqdownload_M8196A(arbConfig, fs, data, marker1, marker2, segmNum, keepOpen, channelMapping, sequence, run);
        otherwise
            error(['instrument model ' arbConfig.model ' is not supported']);
    end
end
