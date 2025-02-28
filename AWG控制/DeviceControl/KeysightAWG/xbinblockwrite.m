function xbinblockwrite(f, data, format, cmd)
% set debugScpi=1 in MATLAB workspace to log SCPI commands
if (evalin('base', 'exist(''debugScpi'', ''var'')'))
    fprintf('cmd = %s %s, %d elements\n', cmd, format, length(data));
end
binblockwrite(f, data, format, cmd);
fprintf(f, '');
end