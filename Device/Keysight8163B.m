

classdef Keysight8163B < Device
    % copyright Tianwai@PSRL,KAIST
    % 2018/09/05: add TCPIP support, add dual channel support
    % 2019/01/24: add GPIB support for the auto calibration
    
    properties
        IPaddr = '192.168.0.20';
        thisConnectMethod = 'TCPIP'; %GPIB | TCPIP
        SlotInfo;
    end
    methods
        function obj = Keysight8163B(GPIB_Addr)
            if nargin <1
                obj.Addr = 20;
            else
                obj.GPIB_Addr = GPIB_Addr;
            end
            obj.DeviceName = 'Keysight 8163B Lightwave Multimeter';
            obj.VISA_Vendor = 'agilent';
            
        end
        
        function Pow = Read_Power(obj,slot,channel)
            % channel is the id of channel in the module with two monitoring
            % channels such as 81635A
            if nargin<3
                channel = 1;
            end
            obj.DevObj = obj.Init();
            fopen(obj.DevObj);
            if channel==1
                Pow = str2double(query(obj.DevObj,...
                    sprintf('read%d:chan%d:pow?',slot,channel)));
            elseif channel==2
                % see "slave channel" in the manual
                Pow = str2double(query(obj.DevObj,...
                    sprintf('fetc%d:chan%d:pow?',slot,channel)));
            end
        end
        
        function AutoCalibration(obj,CaliChNo,RefChNo)
            % 20190124 add support for old 8163B mainframe
            fprintf('The channel to be calibrated is %d\n',CaliChNo);
            fprintf('The channel used as a reference is %d\n',RefChNo);
            fprintf('If no problem, press any key to continue...\n');
            pause();
            % read the current calibration values
            dev = obj.Init();
            fopen(dev);
            switch obj.thisConnectMethod
                case 'TCPIP'
                    cmd = sprintf(':sens1:chan%d:corr?',RefChNo);
                    thisRefChCaliVal = str2double(query(dev,cmd));
                    cmd = sprintf(':sens1:chan%d:corr?',CaliChNo);
                    thisCaliChCaliVal = str2double(query(dev,cmd));
                    % read the current power of each channel
                    thisRefOptPow = obj.Read_Power(1,RefChNo)+thisRefChCaliVal;
                    thisCaliOptPow = obj.Read_Power(1,CaliChNo)+thisCaliChCaliVal;
                    % set the calibration value of the calibrated channel
                    newCaliVal = thisCaliOptPow - thisRefOptPow;
                    cmd = sprintf(':sens1:chan%d:corr %1.6f',CaliChNo,newCaliVal);
                case 'GPIB'
                    cmd = sprintf(':sens%d:corr?',RefChNo);
                    thisRefChCaliVal = str2double(query(dev,cmd));
                    cmd = sprintf(':sens%d:corr?',CaliChNo);
                    thisCaliChCaliVal = str2double(query(dev,cmd));
                    % output the current calibration value
                    fprintf('Current calibration value: Ch%d(Ref): %1.4fdB; Ch%d(Target): %1.4fdB\n',...
                        RefChNo,thisRefChCaliVal,CaliChNo,thisCaliChCaliVal);
                    % read the current power of each channel
                    thisRefOptPow = obj.Read_Power(RefChNo,1)+thisRefChCaliVal;
                    thisCaliOptPow = obj.Read_Power(CaliChNo,1)+thisCaliChCaliVal;
                    % set the calibration value of the calibrated channel
                    newCaliVal = thisCaliOptPow - thisRefOptPow;
                    cmd = sprintf(':sens%d:corr %1.6f',CaliChNo,newCaliVal);
                    % output the updated calibration value
                    fprintf('Updated calibration value: Ch%d(Ref): %1.4fdB; Ch%d(Target): %1.4fdB\n',...
                        RefChNo,thisRefChCaliVal,CaliChNo,newCaliVal);
            end
            
            fprintf(dev,cmd);
            fclose(dev);
        end
        
        function ClearCalibrate(obj,chNo)
            dev = obj.Init();
            fopen(dev);
            cmd = sprintf(':sens1:chan%d:corr 0',chNo);
            fprintf(dev,cmd);
            % read back
            cmd = sprintf(':sens1:chan%d:corr?',chNo);
            caliVal = str2double(query(dev,cmd));
            fprintf('Channel %d current calibration value is %1.6f\n',chNo,caliVal);
            fclose(dev);
        end
        
        function Set_WL(obj,ChNo,wave)
            % wave: wavelength, unit: nm
            switch(obj.thisConnectMethod)
                case 'GPIB'
                    cmd = sprintf(':sens%d:pow:wav %1.1fnm',ChNo,wave);
                case 'TCPIP'
                    cmd = sprintf(':sens1:chan%d:pow:wave %1.1fnm',ChNo,wave);
            end
            obj.Set(cmd);
            fprintf('The wavelength of Channel %d has been set to be %1.1f nm.\n',...
                ChNo,wave);
        end
        
        % set the slot information
        function obj = GetSlotInfo(obj)
            dev = obj.Init();
            fopen(dev);
            for idx = 1:2
                txt = query(dev,sprintf(':slot%d:idn?',idx));
                tmp = regexp(txt,'\w*HP\w*','match');
                obj.SlotInfo{idx} = tmp{:};
            end
            fclose(dev);
        end
        
        function SetAverageTime(obj,ChNo,time)
            % time unit: second
            switch(obj.thisConnectMethod)
                case 'GPIB'
                    cmd = sprintf(':outp%d:atim %1.1f',ChNo,time);
                case 'TCPIP'
                    cmd = sprintf(':outp1:chan%d:atim %1.1f',ChNo,time);
            end
            obj.Set(cmd);
            fprintf('The averaging time of Channel %d has been set to be %d ms.\n',...
                ChNo,time*1e3);
        end
        
%         function DevObj = Init(obj)
%             if ~isunix
%                 obj.VISA_Vendor = 'agilent';
%             end
%             switch obj.thisConnectMethod
%                 case 'GPIB'
%                     % Create GPIB object via NI Visa Driver
%                     RsrcName = sprintf('GPIB%d::%d::0::INSTR',obj.GPIBControllerAddr,obj.GPIB_Addr);
%                     DevObj = instrfind('Type', 'visa-gpib', 'RsrcName', RsrcName, 'Tag', '');
%                 case 'TCPIP'
%                     % Create TCPIP object via Visa Driver
%                     RsrcName = sprintf('TCPIP0::%s::5025::SOCKET',obj.IPaddr);
%                     DevObj = instrfind('Type', 'visa-generic', 'RsrcName', RsrcName, 'Tag', '');
%                 otherwise
%                     error('thisConnectMethod should be set!')
%             end
%             if isempty(DevObj)
%                 DevObj = visa(obj.VISA_Vendor, RsrcName);
%             else
%                 fclose(DevObj);
%                 DevObj = DevObj(1);
%             end
%             % set the obj.DevObj for the general use
%             obj.DevObj = DevObj;
%         end
    end
end