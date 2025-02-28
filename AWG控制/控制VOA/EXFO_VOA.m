classdef EXFO_VOA < Device
    % copyright Tianwai@PSRL,KAIST
    % 2019.01.24 add Set_WL
    
    properties (Dependent = true)
        Current_ATT;
        Current_Wavelength;
    end
    
    properties
        ModelNo; % resolution when setting att value
    end
    
    methods
        function obj = EXFO_VOA(GPIB_Addr)
            if nargin <1
                obj.Addr = 15;
            else
                obj.GPIB_Addr = GPIB_Addr;
            end
            obj.DeviceName = 'EXPO FVA-3150 VOA';
            obj.VISA_Vendor = 'agilent';
            obj.DevObj = obj.Init();
            fprintf('Current wavelength is %4.1f nm.\n',obj.Current_Wavelength);
            % get the model number
            txt = obj.Read('*IDN?');
            tmp = regexp(txt,'FVA-\w*','match');
            obj.ModelNo = tmp{1};
        end
        
        function Set_Att(obj,att)
            obj.DevObj = obj.Init();
            step = 0.2;
            fopen(obj.DevObj);
            current_att = -str2double(query(obj.DevObj,'ATT?'));
            diff = att - current_att;
            while(abs(diff) > step)
                fprintf(obj.DevObj,sprintf('ATT -%2.3f DB',current_att+...
                    sign(diff)*step));
                current_att = -str2double(query(obj.DevObj,'ATT?'));
                diff = att - current_att;
                pause(0.1);
            end
            % it is safe to set the att to the desired value
            fprintf(obj.DevObj,sprintf('ATT -%2.3f DB',att));
            fclose(obj.DevObj);
        end
        
        function Set_Att_Directly(obj,att)
            % the att should be larger than the minimum value
            min_value = 1.115;
            if att-min_value <= eps
                fprintf('Warnning! The set attenuation value is smaller than the physical limit!\n');
                fprintf('The att. in the device is larger than you set.\n');
            end
            % make sure the diff is no smaller than 0.002 dB
            current_att = obj.Read_Current_ATT();
            if abs(-current_att-att)-0.0019 < eps
                fprintf('Warnning! The diff. with the current att. must be at least 0.002 dB for the new attenuation!\n');
                fprintf('The att. in the device maintains unchanged.\n');
                return;
            end
            obj.DevObj = obj.Init();
            fopen(obj.DevObj);
            switch obj.ModelNo
                case 'FVA-3100'
                    obj.xfprintf(obj.DevObj,sprintf('ATT -%2.2f DB',att));
                case 'FVA-3150'
                    obj.xfprintf(obj.DevObj,sprintf('ATT -%2.3f DB',att));
            end
            fclose(obj.DevObj);
        end
        
        function Current_ATT = get_Current_ATT(obj)
            obj.DevObj = obj.Init();
            fopen(obj.DevObj);
            txt = query(obj.DevObj,'ATT?');
            Current_ATT = str2double(txt);
            fclose(obj.DevObj);
        end
        
        function Current_Wavelength = get.Current_Wavelength(obj)
            txt = obj.Read('WVL?');
            Current_Wavelength = str2double(txt);
        end
        
        function Current_ATT = Read_Current_ATT(obj)
            obj.DevObj = obj.Init();
            fopen(obj.DevObj);
            txt = query(obj.DevObj,'ATT?');
            %             query(obj.DevObj,'*opc?');
            Current_ATT = str2double(txt);
            fclose(obj.DevObj);
        end
        
        function Set_WL(obj,wav)
            curr_wav = obj.Current_Wavelength;
            if abs(curr_wav - wav) > 0.1
                cmd = sprintf('WVL %4.1f',wav);
                obj.Set(cmd);
                fprintf('Current wavelength is updated to %4.1f nm.\n',wav);
            end
        end
        
%         function DevObj = Init(obj)
%             if ~isunix
%                 obj.VISA_Vendor = 'agilent';
%             end
%             % Create GPIB object via NI Visa Driver
%             RsrcName = sprintf('GPIB%d::%d::0::INSTR',obj.GPIBControllerAddr,obj.GPIB_Addr);
%             DevObj = instrfind('Type', 'visa-gpib', 'RsrcName', RsrcName, 'Tag', '');
%             if isempty(DevObj)
%                 DevObj = visa(obj.VISA_Vendor, RsrcName);
%             else
%                 fclose(DevObj);
%                 DevObj = DevObj(1);
%             end
%             obj.DevObj = DevObj;
%         end
        
    end
    
end