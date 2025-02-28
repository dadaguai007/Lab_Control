        function setCenterDisplay(obj,chID)
            if nargin < 2
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
                cmd = sprintf(':CHANnel%d:OFFSet %f V',chID,-Vavg);
                fprintf(g,cmd);

            end
            fclose(g);
        end


%Auto（先auto功能），再打开带宽限制，设置时间间隔，重新设置纵向间隔
      function AutoCenterDisplay(obj,chID,time,newVertiScale)
            if nargin < 3
                flagAutoSetVerticalScale = 0;
      
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
                cmd = sprintf(':AUToscale:CHANnel %d',chID);
                fprintf(g,cmd);
                cmd = sprintf(':Timebase:SCALe %f s',time);
                %             cmd = sprintf(':Timebase:SCALe %f CHANnel%d',time,chID);
                fprintf(g,cmd);
                cmd = sprintf(':CHANnel%d:BWLimit %d',chID,ON);
                fprintf(g,cmd);
                cmd = sprintf(':CHANnel%d:SCALe %f V',chID,newVertiScale);
                fprintf(g,cmd);
            else
                cmd = sprintf(':AUToscale:CHANnel %d',chID);
                fprintf(g,cmd);
                cmd = sprintf(':Timebase:SCALe %f s',time);
                %             cmd = sprintf(':Timebase:SCALe %f CHANnel%d',time,chID);
                fprintf(g,cmd);
            end
            fclose(g);

        end

