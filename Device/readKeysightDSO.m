function [y,info] = readKeysightDSO(chIDs)
%%%% change log %%%%
% 2022.03.18 solved the signed/unsigned problem
% 2022.03.19 replace fread with binblockread

% ########## for Agilent DSO ##################
%% open by using TCP/IP
IPaddr = '172.16.104.26';

g = instrfind('Type', 'visa-tcpip', 'RemoteHost', IPaddr);
if isempty(g)
    g = visa('Agilent',['TCPIP0::' IPaddr '::inst0::INSTR']);
else
    fclose(g);
    g = g(1);
end

%%
set(g, 'Timeout', 5);
set(g, 'InputBufferSize', 2e7);    %when ASCii type
%
fopen(g);
% data acqusition
% setting
fprintf(g,':STOP');
fprintf(g, ':ACQ:INT OFF'); % interpolation off
fprintf(g,'ACQ:MODE RTIME');  %real time mode
fprintf(g,':ACQ:AVER OFF'); % average mode off
fprintf(g,':WAVeform:POINts MAX');
fprintf(g,':WAVeform:UNSigned ON'); % make sure the data is in unsigned mode

% collect information
nPoints = str2double(query(g, ':WAVeform:POINts?')); % change the record length record length
SampRate = str2double(query(g, ':ACQ:SRATE?')); % recover the sampling rate

% enable the status resister
fprintf(g, '*CLS');% Clear event que
fprintf(g, '*ESE 1');
fprintf(g, '*SRE 0');

for iCh = 1:length(chIDs)
    chID = chIDs(iCh);
    % set the waveform capture
    fprintf(g, ':waveform:source channel%d', chID);  % choose channel
    fprintf(g, ':waveform:format word'); % binary transfer mode.
    fprintf(g, ':waveform:BYTeorder LSBFirst'); % byte order LSB

    % read waveform
    fprintf(g, ':waveform:DATA?'); %
    % waiting_in_sec(0.1);
    pause(0.1);
    % use binblockread to read the waveform data
    Aall = binblockread(g,'int16'); % int16 for DSO-X 93204A; uint16 for 6004A 

    % Get the preamble block  split the preambleBlock into individual pieces of info
    preambleBlock = query(g,':WAVEFORM:PREAMBLE?');
    preambleBlock = regexp(preambleBlock,',','split');

    % store all this information into a waveform structure for later use
    info.Format = str2double(preambleBlock{1});     % This should be 1, since we're specifying INT16 output
    info.Type = str2double(preambleBlock{2});
    info.Points = str2double(preambleBlock{3});
    info.Count = str2double(preambleBlock{4});      % This is always 1
    info.XIncrement = str2double(preambleBlock{5}); % in seconds
    info.XOrigin = str2double(preambleBlock{6});    % in seconds
    info.XReference = str2double(preambleBlock{7});
    info.YIncrement = str2double(preambleBlock{8}); % V
    info.YOrigin = str2double(preambleBlock{9});
    info.YReference = str2double(preambleBlock{10});
    info.RawData = Aall;

    y(:,iCh) = (Aall - info.YReference) * info.YIncrement + info.YOrigin;
end

% Run again
fprintf(g,':RUN');

fprintf(g, '*CLS');
fclose(g);

