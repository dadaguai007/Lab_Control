function result = iqdownload_M8195A(arbConfig, fs, data, marker1, marker2, segmNum, keepOpen, channelMapping, sequence, run)
% Download a waveform to the M8195A
% It is NOT intended that this function be called directly, only via iqdownload
%
% T.Dippon, Keysight Technologies 2015
% changelogs by Tianwai
% 1. functions associated with sequence control is removed
% 2. only 2ch and 2ch_256k are kept


result = [];

% open the VISA connection
f = iqopen(arbConfig);
if (isempty(f))
    return;
end

result = f;

% stop waveform output
if (run >= 0)
    if (xfprintf(f, sprintf(':ABORt')) ~= 0)
        % if ABORT does not work, let's not try anything else...
        % we will probably get many other errors
        return;
    end
end

switch (arbConfig.model)
    case 'M8195A_2ch'
        % Note that _2ch refers to 16G option that uses external memory
        % After make clear it, TW change the setting back as the original version
        % To use internal memory, use _2ch_256k instead
        fsDivider = 2; % orignal value in iQtools
        % fsDivider = 1; % change by TW
        xfprintf(f, sprintf(':INST:DACM DUAL;:TRAC1:MMOD EXT;:TRAC4:MMOD EXT;:INST:MEM:EXT:RDIV DIV%d', fsDivider));
    case 'M8195A_2ch_256k'
        fsDivider = 1;
        xfprintf(f, sprintf(':INST:DACM DUAL;:TRAC1:MMOD INT;:TRAC4:MMOD INT;:INST:MEM:EXT:RDIV DIV%d', fsDivider));
    otherwise
        error(sprintf('unexpected arb model: %s', arbConfig.model));
end

% set frequency
if (fs ~= 0)
    xfprintf(f, sprintf(':FREQuency:RASTer %.15g;', fs * fsDivider));
end

% apply skew if necessary
if (isfield(arbConfig, 'skew') && arbConfig.skew ~= 0)
    data = iqdelay(data, fs, arbConfig.skew);
end

% direct mode waveform download
for ch = find(channelMapping(:,1))'
    gen_arb_M8195A(arbConfig, f, ch, real(data), marker1, segmNum, run, fs);
end
for ch = find(channelMapping(:,2))'
    gen_arb_M8195A(arbConfig, f, ch, imag(data), marker2, segmNum, run, fs);
end

if (run == 1 && sum(sum(channelMapping)) ~= 0)
    xfprintf(f, sprintf(':FUNCtion:MODE ARBitrary'));
    xfprintf(f, ':INIT:IMMediate');
end
en
if (~exist('keepOpen', 'var') || keepOpen == 0)
    fclose(f);
end
end


function gen_arb_M8195A(arbConfig, f, chan, data, marker, segm_num, run, fs)
% download an arbitrary waveform signal to a given channel and segment
if (isempty(chan) || ~chan)
    return;
end
segm_len = length(data);
if (segm_len > 0)
    % Try to delete the segment, but ignore errors if it does not exist
    % Another approach would be to first find out if it exists and only
    % then delete it, but that takes much longer
    if (run >= 0)
        xfprintf(f, sprintf(':TRACe%d:DELete %d', chan, segm_num), 1);
        xfprintf(f, sprintf(':TRACe%d:DEFine %d,%d', chan, segm_num, segm_len));
    end
    % scale to DAC values - data is assumed to be -1 ... +1
    dataSize = 'int8';
    data = int8(round(127 * data));
    
    % Download the arbitrary waveform.
    % Split large waveform segments in reasonable chunks
    use_binblockwrite = 1;
    offset = 0;
    while (offset < segm_len)
        if (use_binblockwrite)
            len = min(segm_len - offset, 512000);
            cmd = sprintf(':TRACe%d:DATA %d,%d,', chan, segm_num, offset);
            xbinblockwrite(f, data(1+offset:offset+len), dataSize, cmd);
        else
            len = min(segm_len - offset, 5120);
            cmd = sprintf(':TRACe%d:DATA %d,%d', chan, segm_num, offset);
            cmd = [cmd sprintf(',%d', data(1+offset:offset+len)) '\n'];
            xfprintf(f, cmd);
        end
        offset = offset + len;
    end
    xquery(f, '*opc?\n');
    if (run >= 0)
        xfprintf(f, sprintf(':TRACe%d:SELect %d', chan, segm_num));
    end
end
end


function xbinblockwrite(f, data, format, cmd)
% set debugScpi=1 in MATLAB workspace to log SCPI commands
if (evalin('base', 'exist(''debugScpi'', ''var'')'))
    fprintf('cmd = %s %s, %d elements\n', cmd, format, length(data));
end
binblockwrite(f, data, format, cmd);
fprintf(f, '');
end

function retVal = xquery(f, s)
% send a query to the instrument object f
retVal = query(f, s);
% set debugScpi=1 in MATLAB workspace to log SCPI commands
if (evalin('base', 'exist(''debugScpi'', ''var'')'))
    if (length(retVal) > 60)
        rstr = sprintf('%s... (total %d chars)', retVal(1:60), length(retVal));
    else
        rstr = retVal;
    end
    fprintf('qry = %s -> %s\n', s, strtrim(rstr));
end
end

function retVal = xfprintf(f, s, ignoreError)
% Send the string s to the instrument object f
% and check the error status
% if ignoreError is set, the result of :syst:err is ignored
% returns 0 for success, -1 for errors

retVal = 0;
% set debugScpi=1 in MATLAB workspace to log SCPI commands
if (evalin('base', 'exist(''debugScpi'', ''var'')'))
    fprintf('cmd = %s\n', s);
end
fprintf(f, s);
result = query(f, ':syst:err?');
if (isempty(result))
    fclose(f);
    errordlg({'The M8195A firmware did not respond to a :SYST:ERRor query.' ...
        'Please check that the firmware is running and responding to commands.'}, 'Error');
    retVal = -1;
    return;
end
if (~exist('ignoreError', 'var') || ignoreError == 0)
    while (~strncmp(result, '0,No error', 10) && ~strncmp(result, '0,"No error"', 12))
        errordlg({'M8195A firmware returns an error on command:' s 'Error Message:' result});
        result = query(f, ':syst:err?');
        retVal = -1;
    end
end
end
