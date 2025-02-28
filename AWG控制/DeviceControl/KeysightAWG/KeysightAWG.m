classdef KeysightAWG < Device
    % Rev v0.2
    % Created by Tianwai@PSRL,KAIST
    % Package to control Keysight AWG
    properties
        channelMapping;
        arbConfig;
        AWGSamplingRate = 64e9;
        channelConfig;
        AWGmodel = 'M8195A_2ch_256k';
        UseMemory = 'Internal';
        
        ipaddr = '192.168.0.168';
        port = 5025;
        
        flagNotification = true;
        flagRunAfterLoad = true;
    end
    
    methods
        function obj = KeysightAWG(ipaddr,port,modMethod,model)
            if nargin <1
                % use default
                ipaddr = '192.168.0.168';
                port = 5025;
                modMethod = 'IQ';
                model = 'M8195A_2ch_256k';
            end
            
            % configure remote interface to the AWG
            obj.ipaddr = ipaddr;
            obj.port = port;
            obj.AWGmodel = 'M8195A_Rev1';
            obj.arbConfig = getArbConfig(ipaddr,port,model);
            % configure the channel mapping
            obj.channelMapping = [1 0;0 1;0 0;0 0]; % channel mapping: 1|2 : I|Q;
        end

        function g = Init(obj)
            %   g = iqopen(obj.arbConfig);
            RsrcName = sprintf('TCPIP0::%s::inst0::INSTR',obj.ipaddr);
            g = instrfind('Type', 'visa-tcpip', 'RsrcName', RsrcName, 'Tag', '');
            if isempty(g)
                g = visa(obj.VISA_Vendor, RsrcName);
            else
                fclose(g);
                g = g(1);
            end
            fclose(g);
        end
        
        function SendDataToAWG(obj,data,channel,amp,offset)
            run = 1;
            if nargin < 4
                flagSetChannel = 0;
            else
                flagSetChannel = 1;
                
            end
            % check the validity of the data and do some scalings
            data = data_preprocess(data,obj.arbConfig);
            
            % open the VISA connection
            f = obj.Init();
            fopen(f);
            
            % stop waveform output
            if (run >= 0)
                if (xfprintf(f, sprintf(':ABORt')) ~= 0)
                    % if ABORT does not work, let's not try anything else...
                    % we will probably get many other errors
                    return;
                end
            end
            
            % set using either internal memory (256k) or extended memory
            switch (obj.arbConfig.model)
                case 'M8195A_2ch'
                    fsDivider = 2; % orignal value in iQtools
                    xfprintf(f, sprintf(':INST:DACM DUAL;:TRAC1:MMOD EXT;:TRAC4:MMOD EXT;:INST:MEM:EXT:RDIV DIV%d', fsDivider));
                case 'M8195A_2ch_256k'
                    fsDivider = 1;
                    xfprintf(f, sprintf(':INST:DACM DUAL;:TRAC1:MMOD INT;:TRAC4:MMOD INT;:INST:MEM:EXT:RDIV DIV%d', fsDivider));
                case 'M8195A_Rev1'
                    fsDivider = 1;
                    xfprintf(f, sprintf([':INST:DACM FOUR' ...
                        ';:TRAC1:MMOD INT;:TRAC2:MMOD INT;:INST:MEM:EXT:RDIV DIV%d'], fsDivider));
                otherwise
                    error('unexpected arb model: %s', obj.arbConfig.model);
            end
            
            % set frequency
            fs = obj.AWGSamplingRate;
            if (fs ~= 0)
                xfprintf(f, sprintf(':FREQuency:RASTer %.15g;', fs * fsDivider));
            end
            
            % send the data to the target channel
            marker1 = [];
            segmNum = 1;
            for id = 1:length(channel)
                ch = channel(id);
                gen_arb_M8195A(obj.arbConfig, f, ch, real(data), marker1, segmNum, run, fs);
%                 % turn on Output
%                 xfprintf(f, sprintf(':OUTPut%d ON', ch));
                % set the amplitde and offset if required
                if flagSetChannel
                    % apply the channel setting (amplitude & offset)
                    xfprintf(f,sprintf(':VOLTage%d:AMPLitude %g',...
                        ch, amp));
                    xfprintf(f,sprintf(':VOLTage%d:OFFSet %g',...
                        ch, offset));
                end
            end
            
            % run
            if (run == 1 && sum(sum(obj.channelMapping)) ~= 0)
                xfprintf(f, sprintf(':FUNCtion:MODE ARBitrary'));
                xfprintf(f, ':INIT:IMMediate');
            end
            
            % close the connection
            if (~exist('keepOpen', 'var') || keepOpen == 0)
                fclose(f);
            end
        end
        
        function EnableOutput(obj,chan)
            if nargin <2
                chan = [1,4];
            end
            % open the VISA connection
            f = obj.Init();
            fopen(f);
            % enable output of certain channel
            for idx = 1:length(chan)
                ch = chan(idx);
                xfprintf(f, sprintf(':OUTPut%d ON', ch));
            end
            % close the connection
            if (~exist('keepOpen', 'var') || keepOpen == 0)
                fclose(f);
            end
        end
        
        function DisableOutput(obj,chan)
            if nargin <2
                chan = [1,4];
            end
            % open the VISA connection
            f = obj.Init();
            fopen(f);
            % enable output of certain channel
            for idx = 1:length(chan)
                ch = chan(idx);
                xfprintf(f, sprintf(':OUTPut%d OFF', ch));
            end
            % close the connection
            if (~exist('keepOpen', 'var') || keepOpen == 0)
                fclose(f);
            end
        end
        
        function ApplyChannelSetting(obj,chan)
            % apply current channel setting to AWG
            arb = obj.arbConfig;
            if (isfield(arb,'amplitude'))
                if (size(arb.amplitude, 2) < 4)
                    arb.amplitude = repmat(arb.amplitude, 1, 2);
                end
                xfprintf(f, sprintf(':VOLTage%d:AMPLitude %g', chan, arb.amplitude(chan)));
            end
            if (isfield(arb,'offset'))
                if (size(arb.offset, 2) < 4)
                    arb.offset = repmat(arb.offset, 1, 2);
                end
                xfprintf(f, sprintf(':VOLTage%d:OFFSet %g', chan, arb.offset(chan)));
            end
        end
        
        function result = SetSkew(obj,data,delay)
            if obj.flagNotification
                fprintf('Adding skew triggers reloading the data to AWG\n');
            end
            obj.arbConfig.skew = delay;
            result = obj.SendDataToAWG(data);
        end
        
        function [response] = Query_Calibration(obj,channel,amp)
            obj.DevObj = obj.Init();
            % open the connection
            fopen(obj.DevObj);
            % set the data source to Channel
            txt = query(obj.DevObj,sprintf(':CHAR%d? %d',channel,amp));
            y = textscan(txt(2:end-2),'%f','Delimiter',',');
            response = y{1};
            response = reshape(response,3,[]).';
            % get the data
            fclose(obj.DevObj);
        end
        
        function retVal = SetAmp(obj,chan,amp)
            % chan: Channel ID
            % amp: Amplitude to be set
            if amp > 1 || amp < 0
                error('invalid amplitude value');
            end
            f = obj.Init();
            fopen(f);
            retVal = obj.xfprintf(f,sprintf(':VOLTage%d:AMPLitude %g',...
                chan, amp));
            fclose(f);
            flushoutput(f);
            flushinput(f);
            % update the channel setting
            obj.arbConfig.amplitude(chan) = amp;
        end
        
        function retVal = ReadAmp(obj,chan)
            % chan: Channel ID
            str = obj.Read(sprintf(':VOLTage%d:AMPLitude?',chan));
            retVal = str2double(str);
        end
        
        % This function (directly call iqtools) is OBSOLETE!!!
        function result = SendDataToAWG_OBSOLETE(obj,data)
            % check the validity of data to be sent to AWG
            if mod(length(data),obj.arbConfig.segmentGranularity)
                error('Data length does not satisfy the granularity requirement!');
            end
            % if no problem, call iqdownload to send
            result = iqdownload(data, obj.AWGSamplingRate,...
                'arbConfig',obj.arbConfig,...
                'channelMapping',obj.channelMapping,...
                'run',obj.flagRunAfterLoad);
        end
        
        function retVal = xfprintf(~, f, s, ignoreError)
            % Send the string s to the instrument object f
            % and check the error status
            % if ignoreError is set, the result of :syst:err is ignored
            % returns 0 for success, -1 for errors
            
            retVal = 0;
            % % set debugScpi=1 in MATLAB workspace to log SCPI commands
            %     if (evalin('base', 'exist(''debugScpi'', ''var'')'))
            %         fprintf('cmd = %s\n', s);
            %     end
            fprintf(f, s);
            result = query(f, ':syst:err?');
            if (isempty(result))
                fclose(f);
                errordlg({'The M8196A firmware did not respond to a :SYST:ERRor query.' ...
                    'Please check that the firmware is running and responding to commands.'}, 'Error');
                retVal = -1;
                return;
            end
            if (~exist('ignoreError', 'var') || ignoreError == 0)
                while (~strncmp(result, '0,No error', 10) && ~strncmp(result, '0,"No error"', 12))
                    errordlg({'M8196A firmware returns an error on command:' s 'Error Message:' result});
                    result = query(f, ':syst:err?');
                    retVal = -1;
                end
            end
        end
        
    end
end