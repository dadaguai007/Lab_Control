classdef KEYSIGHT6004A < Device

    properties

    end

    methods
        function obj = KEYSIGHT6004A(IPaddr)
            if nargin < 1
                obj.Addr = '172.16.104.8';
            else
                obj.Addr = IPaddr;
            end
            obj.DeviceName = 'KEYSIGHT MSOX6004A oscilloscope';
            obj.VISA_Vendor = 'agilent';
            obj.ConnectionType = 'tcpip';
        end
        % obj也算是一个参数
        function y = readwaveform(obj,chIDs)
            if nargin < 2
                chIDs = 1;
            end
            g = obj.Init();
            %%
            set(g, 'Timeout', 5);
            set(g, 'InputBufferSize', 1e7);    %when ASCii type
            %
            fopen(g);
            % data acqusition
            % setting
            fprintf(g,':STOP');
            fprintf(g, ':ACQ:INT OFF'); % interpolation off
            fprintf(g,':ACQ:MODE RTIME');  %real time mode
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
                Aall = binblockread(g,'uint16');

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
            pause(0.2)
            fprintf(g, '*CLS');
            fclose(g);
        end

        function [y,info] = setScopeVerticalScale(obj,chID, vertiScale)
            if nargin < 3
                flagAutoSetVerticalScale = 1;
            else
                flagAutoSetVerticalScale = 0;
            end
            g = obj.Init();
            set(g, 'Timeout', 5);
            set(g, 'InputBufferSize', 1e7);    %when ASCii type
            %
            fopen(g);
            % enable the status resister
            fprintf(g, '*CLS');% Clear event que
            fprintf(g, '*ESE 1');
            fprintf(g, '*SRE 0');
            if flagAutoSetVerticalScale
                % remove the offset
                cmd = sprintf(':MEASure:VAVerage? CHANnel%d',chID);
                Vavg = str2double(query(g,cmd));
                cmd = sprintf(':CHANnel%d:OFFSet %f V',chID,-Vavg);
                fprintf(g,cmd);
                % read the peak point of the current waveform
                cmd = sprintf(':MEASure:VMAX? CHANnel%d',chID);
                VMax = str2double(query(g,cmd));
                cmd = sprintf(':MEASure:VMIN? CHANnel%d',chID);
                VMin = str2double(query(g,cmd));
                % set new vertical scale
                margin = 0.2;
                newVertiScale = (VMax-VMin)*(1+margin)/8;
                newVertiScale = max(newVertiScale,0.001); % minimum scale is 1mV
                cmd = sprintf(':CHANnel%d:SCALe %f V',chID,newVertiScale);
                fprintf(g,cmd);
            else
                vertiScale = max(vertiScale,0.001); % minimum scale is 1mV
                cmd = sprintf(':CHANnel%d:SCALe %f V',chID,vertiScale);
                fprintf(g,cmd);
            end
            fclose(g);
        end


        %固定纵向比例下的波形居中
        function sweepsetCenterDisplay(obj,chID)
            if nargin < 3
                flagAutoSetVerticalScale = 1;
            end

            g = obj.Init();
            set(g, 'Timeout', 5);
            set(g, 'InputBufferSize', 1e7);    %when ASCii type
            %
            fopen(g);
            % enable the status resister
            fprintf(g, '*CLS');% Clear event que
            fprintf(g, '*ESE 1');
            fprintf(g, '*SRE 0');
% 判断是否会超阈值
            cmd = sprintf(':CHANnel%d:SCALe?',chID);
            newVertiScale = str2double(query(g,cmd));
            pause(1.5);
            cmd = sprintf(':MEASure:VMIN? CHANnel%d',chID);
            VMin = str2double(query(g,cmd));
            cmd = sprintf(':MEASure:VMax? CHANnel%d',chID);
            VMax = str2double(query(g,cmd));
            
            while (VMax>1000) || (VMin>1000)
                newVertiScale = newVertiScale+0.001;
                cmd = sprintf(':CHANnel%d:SCALe %f V',chID,newVertiScale);
                fprintf(g,cmd);
                pause(0.1);

                if VMax> VMin
                    %假设Vmax超出量程，Vmax还是大于Vmin
                    %以Vmin为最小值进行平移呗
                    cmd = sprintf(':MEASure:VMIN? CHANnel%d',chID);
                    VMin = str2double(query(g,cmd));
                    cmd = sprintf(':CHANnel%d:OFFSet %f V',chID,VMin);
                    fprintf(g,cmd);

                    cmd = sprintf(':MEASure:VAVerage? CHANnel%d',chID);
                    Vavg = str2double(query(g,cmd));
                    offset = VMin;
                    while Vavg>1000
                        offset = offset + newVertiScale;
                        cmd = sprintf(':CHANnel%d:OFFSet %f V',chID,offset);
                        fprintf(g,cmd);
                        cmd = sprintf(':MEASure:VAVerage? CHANnel%d',chID);
                        Vavg = str2double(query(g,cmd));
                    end

                elseif VMax < VMin
                    %假设Vmin超出量程，Vmin是大于Vmax
                    cmd = sprintf(':MEASure:VMax? CHANnel%d',chID);
                    VMax = str2double(query(g,cmd));
                    cmd = sprintf(':CHANnel%d:OFFSet %f V',chID,VMax);
                    fprintf(g,cmd);
                    cmd = sprintf(':MEASure:VAVerage? CHANnel%d',chID);
                    Vavg = str2double(query(g,cmd));
                    offset = VMax;
                    while Vavg>1000
                        offset = offset - newVertiScale;
                        cmd = sprintf(':CHANnel%d:OFFSet %f V',chID,offset);
                        fprintf(g,cmd);
                        cmd = sprintf(':MEASure:VAVerage? CHANnel%d',chID);
                        Vavg = str2double(query(g,cmd));
                    end
                end
                cmd = sprintf(':MEASure:VMIN? CHANnel%d',chID);
                VMin = str2double(query(g,cmd));
                cmd = sprintf(':MEASure:VMax? CHANnel%d',chID);
                VMax = str2double(query(g,cmd));

            end

            if flagAutoSetVerticalScale
                % remove the offset
                cmd = sprintf(':MEASure:VAVerage? CHANnel%d',chID);
                Vavg = str2double(query(g,cmd));
                cmd = sprintf(':CHANnel%d:OFFSet %f V',chID,Vavg);
                fprintf(g,cmd);
            end
            fclose(g);
        end



        function AutoCenterDisplay(obj,chID,time,~)
            if nargin < 4
                flagAutoSetVerticalScale = 0;
                % switch lower（）
                %             case 'on'
                %                  f=1 ;
                %             case 'off'
                %                  f =  0 ;
                %             end
            else
                flagAutoSetVerticalScale = 1;
            end
            g = obj.Init();
            set(g, 'Timeout', 5);
            set(g, 'InputBufferSize', 1e7);    %when ASCii type
            %
            fopen(g);
            % enable the status resister
            fprintf(g, '*CLS');% Clear event que
            fprintf(g, '*ESE 1');
            fprintf(g, '*SRE 0');
            if flagAutoSetVerticalScale
                fprintf(g,':AUToscale');
                pause(3);
                cmd = sprintf(':Timebase:SCALe %f s',time);
                %             cmd = sprintf(':Timebase:SCALe %f CHANnel%d',time,chID);
                fprintf(g,cmd);
                cmd = sprintf(':CHANnel%d:BWLimit %d',chID,1);   % 打开带宽限制
                fprintf(g,cmd);
                % adjust best
                cmd = sprintf(':CHANnel%d:SCALe?',chID);
                nowVertiScale = str2double(query(g,cmd));
                newVertiScale = nowVertiScale/2;
                cmd = sprintf(':CHANnel%d:SCALe %f V',chID,newVertiScale);
                fprintf(g,cmd);
                cmd = sprintf(':MEASure:VMIN? CHANnel%d',chID);
                VMin = str2double(query(g,cmd));
                VMin = VMin+VMin/2;
                cmd = sprintf(':CHANnel%d:OFFSet %f V',chID,VMin);
                fprintf(g,cmd);
                %
                while 1

                    newVertiScale = newVertiScale-0.001;
                    cmd = sprintf(':CHANnel%d:SCALe %f V',chID,newVertiScale);
                    fprintf(g,cmd);
                    cmd = sprintf(':MEASure:VMIN? CHANnel%d',chID);
                    VMin = str2double(query(g,cmd));
                    cmd = sprintf(':MEASure:VMax? CHANnel%d',chID);
                    VMax = str2double(query(g,cmd));
                    if VMax> VMin
                        %假设Vmax超出量程，Vmax还是大于Vmin
                        %以Vmin为最小值进行平移呗
                        cmd = sprintf(':MEASure:VMIN? CHANnel%d',chID);
                        VMin = str2double(query(g,cmd));
                        cmd = sprintf(':CHANnel%d:OFFSet %f V',chID,VMin);
                        fprintf(g,cmd);

                        cmd = sprintf(':MEASure:VAVerage? CHANnel%d',chID);
                        Vavg = str2double(query(g,cmd));
                        offset = VMin;
                        while Vavg>1000
                            offset = offset + newVertiScale;
                            cmd = sprintf(':CHANnel%d:OFFSet %f V',chID,offset);
                            fprintf(g,cmd);
                            cmd = sprintf(':MEASure:VAVerage? CHANnel%d',chID);
                            Vavg = str2double(query(g,cmd));
                        end

                    elseif VMax < VMin
                        %假设Vmin超出量程，Vmin是大于Vmax
                        cmd = sprintf(':MEASure:VMax? CHANnel%d',chID);
                        VMax = str2double(query(g,cmd));
                        cmd = sprintf(':CHANnel%d:OFFSet %f V',chID,VMax);
                        fprintf(g,cmd);
                        cmd = sprintf(':MEASure:VAVerage? CHANnel%d',chID);
                        Vavg = str2double(query(g,cmd));
                        offset = VMax;
                        while Vavg>1000
                            offset = offset - newVertiScale;
                            cmd = sprintf(':CHANnel%d:OFFSet %f V',chID,offset);
                            fprintf(g,cmd);
                            cmd = sprintf(':MEASure:VAVerage? CHANnel%d',chID);
                            Vavg = str2double(query(g,cmd));
                        end
                    end
                    %应该是判断均值，如果均值能读取，就进行均值的offset
                    % 均值无法读取，继续进行方格的移取，方格的数据值是已知，直到均值能够读取

                    cmd = sprintf(':CHANnel%d:OFFSet %f V',chID,Vavg);
                    fprintf(g,cmd);
                    %读到Vavg时，MAX值也是能读取的
                    cmd = sprintf(':MEASure:VMax? CHANnel%d',chID);
                    VMax = str2double(query(g,cmd));
                    if VMax < (Vavg + 3*newVertiScale)
                        disp('此时不是最佳的量化区间');
                    else
                        disp('此时是最佳的量化区间');
                        break;
                    end

                end

            else
                fprintf(g,':AUToscale');
                cmd = sprintf(':Timebase:SCALe %f s',time);
                %             cmd = sprintf(':Timebase:SCALe %f CHANnel%d',time,chID);
                fprintf(g,cmd);
            end
            fclose(g);

        end

        function setCenterDisplay(obj,chID)
            if nargin < 3
                flagAutoSetVerticalScale = 1;
            end

            g = obj.Init();
            set(g, 'Timeout', 5);
            set(g, 'InputBufferSize', 1e7);    %when ASCii type
            %
            fopen(g);
            % enable the status resister
            fprintf(g, '*CLS');% Clear event que
            fprintf(g, '*ESE 1');
            fprintf(g, '*SRE 0');
            if flagAutoSetVerticalScale
                % remove the offset
                cmd = sprintf(':MEASure:VAVerage? CHANnel%d',chID);
                Vavg = str2double(query(g,cmd));
                cmd = sprintf(':CHANnel%d:OFFSet %f V',chID,Vavg);
                fprintf(g,cmd);

            end
            fclose(g);
        end

    end
end
