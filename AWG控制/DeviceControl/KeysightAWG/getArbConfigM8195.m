function arbConfig = getArbConfigM8195(chConfig)
% create on 09/07/2018
% for 

arbConfig.model = 'M8195A_2ch';

% reset
arbConfig.do_rst = 0;

% for iqopen
arbConfig.connectionType = 'tcpip';
arbConfig.ip_address = '192.168.0.168';
arbConfig.port = 5025;

% for channel setting
arbConfig.amplitude = chConfig.amplitude;
arbConfig.offset = chConfig.offset;
arbConfig.skew = chConfig.skew;

% for segment 8195_2ch
arbConfig.fixedSampleRate = 0;
arbConfig.defaultSampleRate = 32e9;s
arbConfig.maximumSampleRate = 32.5e9;
arbConfig.minimumSampleRate = 27e9;
arbConfig.minimumSegmentSize = 5*128;
arbConfig.maximumSegmentSize = 8*1024*1024*1024;
% due to a sequencer bug, use double the specified granularity
% Once that bug is fixed, we can go back to 128
arbConfig.segmentGranularity = 256;
arbConfig.maxSegmentNumber = 512*1024;
arbConfig.numChannels = 2;

arbConfig.DACRange = 1;
arbConfig.interleaving = 0;
arbConfig.gainCorrection = 0;