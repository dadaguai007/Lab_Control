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