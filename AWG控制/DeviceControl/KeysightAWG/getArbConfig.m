function arbConfig = getArbConfig(ipaddr,port,model)
% this function is to emulate the "loadArbConfig" function provided in
% IQtools
% Created by Tianwai@PSRL,KAIST
% Created on Aug.13, 2019
% Rev 0.1

% For M8195A, M8195A_2ch_256k refers to use the internal memory, whereas
% 'M8195A_2ch' refers to use the external memory

if nargin < 1
    ipaddr = '192.168.0.168';
    port = 5025;
    model = 'M8195A_2ch_256k';
end
% if ~strcmp(model,'M8195A_2ch_256k') && ...
%         ~strcmp(model,'M8195A_2ch') && ...
%         ~strcmp(model,'M8196A') && ...
%         ~strcmp(model,'M8195A_1ch')
%     errordlg('Only support M8195A_1ch, M8195A_2ch_256k, M8195A_2ch or M8196A','Error');
% end

try
    x = evalin('base','arbConfig');
    if strcmp(x.model,model)
        fprintf('There is arbConfig in current environment. Nothing changed!\n');
        return;
    end
catch
    
end

arbConfig.model = model; % 'M8195A_2ch_256k', 'M8195A_2ch', 'M8196A'
% reset
arbConfig.do_rst = 0;
% for iqopen, using default
arbConfig.connectionType = 'tcpip';
arbConfig.ip_address = ipaddr;
arbConfig.port = port;
% for channel setting, using default
arbConfig.amplitude = [0.5,0,0,0.5];
arbConfig.offset = [0,0,0,0];
arbConfig.skew = 0;
% set segment information
% the following code comes from loadArbConfig.m
switch arbConfig.model
    case { 'M8195A_1ch' }
        arbConfig.fixedSampleRate = 0;
        arbConfig.defaultSampleRate = 64e9;
        arbConfig.maximumSampleRate = 65e9;
        arbConfig.minimumSampleRate = 54e9;
        arbConfig.minimumSegmentSize = 5*256;
        arbConfig.maximumSegmentSize = 16*1024*1024*1024;
        % due to a sequencer bug, use double the specified granularity
        % Once that bug is fixed, we can go back to 256
        arbConfig.segmentGranularity = 512;
        arbConfig.maxSegmentNumber = 512*1024;
        arbConfig.numChannels = 1;
    case { 'M8195A_2ch_256k'}
        arbConfig.fixedSampleRate = 0;
        arbConfig.defaultSampleRate = 64e9;
        arbConfig.maximumSampleRate = 65e9;
        arbConfig.minimumSampleRate = 54e9;
        arbConfig.minimumSegmentSize = 128;
        arbConfig.maximumSegmentSize = 256*1024;
        arbConfig.segmentGranularity = 128;
        arbConfig.maxSegmentNumber = 1;
        arbConfig.numChannels = 2;
    case { 'M8195A_Rev1'}
        arbConfig.fixedSampleRate = 0;
        arbConfig.defaultSampleRate = 64e9;
        arbConfig.maximumSampleRate = 65e9;
        arbConfig.minimumSampleRate = 54e9;
        arbConfig.minimumSegmentSize = 128;
        arbConfig.maximumSegmentSize = 256*1024;
        arbConfig.segmentGranularity = 128;
        arbConfig.maxSegmentNumber = 1;
        arbConfig.numChannels = 4;
    case { 'M8195A_2ch' }
        arbConfig.fixedSampleRate = 0;
        arbConfig.defaultSampleRate = 32e9;
        arbConfig.maximumSampleRate = 32.5e9;
        arbConfig.minimumSampleRate = 27e9;
        arbConfig.minimumSegmentSize = 5*128;
        arbConfig.maximumSegmentSize = 8*1024*1024*1024;
        % due to a sequencer bug, use double the specified granularity
        % Once that bug is fixed, we can go back to 128
        arbConfig.segmentGranularity = 256;
        arbConfig.maxSegmentNumber = 512*1024;
        arbConfig.numChannels = 2;
    case { 'M8196A' }
        arbConfig.fixedSampleRate = 0;
        arbConfig.defaultSampleRate = 92e9;
        arbConfig.maximumSampleRate = 93.4e9;
        arbConfig.minimumSampleRate = 82.24e9;
        arbConfig.minimumSegmentSize = 128;
        arbConfig.maximumSegmentSize = 512*1024;
        arbConfig.segmentGranularity = 128;
        arbConfig.maxSegmentNumber = 1;
        arbConfig.numChannels = 4;
    otherwise
        errordlg('Unknown instrument model', 'Error');
end