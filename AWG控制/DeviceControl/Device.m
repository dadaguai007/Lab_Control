classdef Device < handle
    % 2017-07-06: add delete methods
    % 2021-12-28: add TCP/IP and USB support
    properties
        DeviceName = 'General Device';
        ConnectionType = 'GPIB'; % GPIB(default) | TCPIP | USB
        VISA_Vendor = 'Agilent';
        DevObj=[];
        % for GPIB connection
        GPIB_Addr; % DO NOT USE ADDRESS 21!!! IT IS RESERVED BY KEYSIGHT
        GPIBControllerAddr = 0;
        % for TCP/IP connection
        IPaddr = ''; % example: '192.168.0.123'
        % for USB connection
        USBaddr = ''; % example: '0x2A8D::0x1002::MY58290609'
    end
    
    properties
        Status;
    end
    
    methods
        function DevObj = Init(obj)
            if ~isunix
                obj.VISA_Vendor = 'agilent';
            end
            % Create GPIB object via NI Visa Driver
            switch lower(obj.ConnectionType)
                case 'gpib'
                    RsrcName = sprintf('GPIB%d::%d::0::INSTR',obj.GPIBControllerAddr,obj.GPIB_Addr);
                case 'tcpip'
                    RsrcName = sprintf('TCPIP0::%s::inst0::INSTR',obj.IPaddr);
                case 'usb'
                    RsrcName = sprintf('USB0::%s::0::INSTR',obj.USBaddr);
            end
            % TODO
            DevObj = instrfind('Type', 'visa-gpib', 'RsrcName', RsrcName, 'Tag', '');
            if isempty(DevObj)
                DevObj = visa(obj.VISA_Vendor, RsrcName);
            else
                fclose(DevObj);
                DevObj = DevObj(1);
            end
            obj.DevObj = DevObj;
        end
        
        function passflag = SelfTest(obj,flagPrint)
            % extCode: 0->normal;1->error
            if nargin<2
                flagPrint = 1;
            end
            gp = obj.Init();
            fopen(gp);
            message = query(gp,'*idn?');
            if ~isempty(message)
                passflag = true;
                if flagPrint
                    fprintf('Device Self Test Passed!\nDevice Info: %s\n',message);
                end
            else
                passflag = false;
            end
            fclose(gp);
        end
        
        function value = Read(obj,cmd)
            g = obj.Init();
            fopen(g);
            fprintf(g,cmd);
            txt = fscanf(g,'%s');
            if isstruct(txt)
                value = txt{1};
            else
                value = txt;
            end
            fclose(g);
        end
        
        function value = ReadFloat(obj,cmd)
            txt = obj.Read(cmd);
            value = str2double(txt);
        end
        
        function Set(obj,cmd)
            g = obj.Init();
            fopen(g);
            fprintf(g,cmd);
            fclose(g);
        end
        
        function retVal = xfprintf(obj,g,cmd,flagIgnoreErr)
            retVal = 0;
            fprintf(g,cmd);
            query(g,'*opc?');
            result = query(g,':syst:err?');
            if (isempty(result))
                fclose(g);
                errordlg({'The Device did not respond a :SYST:ERRor query.' ...
                    'Please check that the firmware is running and responding to commands.'}, 'Error');
                retVal = -1;
                return
            end
            if (~exist('flagIgnoreErr', 'var') || flagIgnoreErr == 0)
                while (~strncmp(result, '0,""',4))
                    errordlg({'Device returns an error on command:' 'Error Message:' result});
                    result = query(g, ':syst:err?');
                    retVal = -1;
                end
            end
            return;
        end
        
        function errors = ReadErrorQueue(obj)
            errors = {};
            
            stb = str2num(obj.Read('*STB?'));
            errQueue = bitand(stb,4) > 0;
            
            if errQueue == true
                while 1
                    response = obj.Read('SYST:ERR?');
                    k = strfind(lower(response), '"no error"');
                    if ~isempty (k) %#ok<STREMP>
                        break
                    end
                    errors{end+1} = response; %#ok<AGROW>
                end
            end
        end
        
        function ErrorChecking(obj)
            % This method calls the ReadErrorQueue() and if any error is detected, it generates MException()
            %
            % See also READERRORQUEUE
            errors = obj.ReadErrorQueue();
            if ~isempty (errors)
                sizes = size(errors);
                errorsCount = sizes(2);
                allErrors = strjoin(errors, 'newline');
                if errorsCount == 1
                    message = 'Instrument reports one error in the error queue';
                else
                    message = sprintf('Instrument reports %d errors in the error queue', errorsCount);
                end
                throw(MException('Device:ErrorChecking', '%s:%s%s', message, 'newline', allErrors));
            end
        end
        
        function delete(obj)
            if ~isempty(obj.DevObj) % add this line to avoid the warning from an empty DevObj
                if isvalid(obj.DevObj)
                    fclose(obj.DevObj);
                    delete(obj.DevObj);
                end
            end
        end
    end
end