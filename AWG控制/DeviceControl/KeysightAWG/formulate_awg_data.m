function [fseq,nZeros] = formulate_awg_data(seq,br,fs)
minimumSegmentSize = 5*128;
segmentGranularity = 256;

if isrow(seq)
    seq = seq.';
end
if br ~= fs 
    % resampling is required
    fseq = resample(seq,fs,br,100);
end
N = length(fseq);
if N < minimumSegmentSize*segmentGranularity
    error('Output sequency is too short to load to AWG!');
end
len = segmentGranularity.*ceil(N/segmentGranularity);
if len > N
    % adding zeros in the end is required
    nZeros = len - N;
    fseq(end+1:end+nZeros) = 0;
    fprintf('%d zeros are inserted into the end of the sequence.\n',nZeros)
else
    nZeros = 0;
end
% normalization
 scale = max(max(abs(real(seq))), max(abs(imag(seq))));
 fseq = fseq ./ scale;