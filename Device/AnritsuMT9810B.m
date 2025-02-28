
classdef AnritsuMT9810B < Device
    
    properties
        
    end
    
    methods
        function obj = AnritsuMT9810B(GPIB_addr)
            if nargin <1
                obj.GPIB_Addr = 12;
            else
                obj.GPIB_Addr = GPIB_addr;
            end
            obj.DeviceName = 'Anritsu MT9810B Power Meter';
            obj.VISA_Vendor = 'agilent';
        end
        
        function Pow = Read_Power(obj,channel)
            a = 1;
            while a == 1
                if nargin<1
                    channel = 1;
                end
                obj.DevObj = obj.Init();
                fopen(obj.DevObj);
                %             if channel==1
                query(obj.DevObj,'*opc?');
                cmd=sprintf('FETCH%d:POWER?',channel);
                txt1=query(obj.DevObj,cmd);
                Pow1 = str2double(txt1(1:end-4));
                a=isnan(Pow1);
            end
            Pow=Pow1;

            fclose(obj.DevObj);
        end
        %
        function AutoCalibration(obj,CaliChNo,RefChNo)
            fprintf('The channel to be calibrated is %d\n',CaliChNo);
            fprintf('The channel used as a reference is %d\n',RefChNo);
            fprintf('If no problem, press any key to continue...\n');
            pause();
            %             read the current calibration values
            dev = obj.Init();
            fopen(dev);
            %             cmd=sprintf('SENS:CORR:ON 2');
            %             fprintf(dev,cmd);
            cmd = sprintf(':SENS%d:CORR?',RefChNo);
            oldRefChCaliVal = str2double(query(dev,cmd));
            cmd = sprintf(':sens%d:corr?',CaliChNo);
            oldCaliChCaliVal = str2double(query(dev,cmd));
            % output the current calibration value
            fprintf('Current calibration value: Ch%d(Ref): %1.4fdB; Ch%d(Target): %1.4fdB\n',...
                RefChNo,oldRefChCaliVal,CaliChNo,oldCaliChCaliVal);
            % read the current power of each channel
            %                     if CaliChNo.cali is on && RefChNo.cali is on
            realRefOptPow = obj.Read_Power(RefChNo)+oldRefChCaliVal;
            realCaliOptPow = obj.Read_Power(CaliChNo)+oldCaliChCaliVal;
            %                     else if CaliChNo.cali is on && RefChNo.cali is close
            %                             realRefOptPow = obj.Read_Power(RefChNo);
            %                             realCaliOptPow = obj.Read_Power(CaliChNo)+oldCaliChCaliVal;
            %                         else if CaliChNo.cali is close && RefChNo.cali is close
            %                                 realRefOptPow = obj.Read_Power(RefChNo);
            %                                 realCaliOptPow = obj.Read_Power(CaliChNo);
            %                             else
            %                                 realRefOptPow = obj.Read_Power(RefChNo)+oldRefChCaliVal;
            %                                 realCaliOptPow = obj.Read_Power(CaliChNo);
            %                             end
            %                         end
            %                     end
            % set the calibration value of the calibrated channel
            newCaliVal = realCaliOptPow - realRefOptPow;
            cmd = sprintf(':SENS%d:CORR %1.6f',CaliChNo,newCaliVal);
            % output the updated calibration value
            fprintf('Updated calibration value: Ch%d(Ref): %1.4fdB; Ch%d(Target): %1.4fdB\n',...
                RefChNo,oldRefChCaliVal,CaliChNo,newCaliVal);
            fclose(dev);
            fopen(dev);
            query(obj.DevObj,'*opc?');%我服了
            fprintf(dev,cmd);
            txt2 = query(dev,'SENS1:CORR?');
            disp(txt2);
            fclose(dev);
        end
        
        
        function ClearCalibrate(obj,chNo)
            dev = obj.Init();
            fopen(dev);
            cmd = sprintf(':sens%d:corr 0',chNo);
            fprintf(dev,cmd);
            % read back
            cmd = sprintf(':sens%d:corr?',chNo);
            caliVal = str2double(query(dev,cmd));
            fprintf('Channel %d current calibration value is %1.6f\n',chNo,caliVal);
            fclose(dev);
        end
        
        function SetAverageTime(obj,ChNo,time)
            dev = obj.Init();
            fopen(dev);
            cmd = sprintf(':sense%d:POWer:INTerval %1.1f',ChNo,time);
            fprintf(dev,cmd);
            fprintf('The averaging time of Channel %d has been set to be %d ms.\n',...
                ChNo,time*1e3);
            %             cmd=sprintf(':sense%d:POWer:INTerval?',ChNo);
            %             txt2 = query(dev,cmd);
            %             disp(txt2);
            fclose(dev);
        end
        
        function Set_WL(obj,ChNo,wavelength)
            % wave: wavelength, unit: nm
            dev = obj.Init();
            fopen(dev);
            cmd = sprintf(':sens%d:pow:wav %1.1fnm',ChNo,wavelength);
            fprintf(dev,cmd);
            fprintf('The wavelength of Channel %d has been set to be %1.1f nm.\n',...
                ChNo,wavelength);
            fclose(dev);
        end
        
    end
end