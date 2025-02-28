classdef YokogawaOSA < Device
    %%%%%%%%%%%%%%%%%%%%%%%%%%%% NOTE %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % 1. The instrument's auto offset function is set to ON by default,
    % and it performs offset of the analog circuits at approximately 
    % 10 minute intervals. The offset process takes about 30 seconds.
    properties
        ipaddr;
    end
    
    methods
        function obj = YokogawaOSA(ipaddr)
            if nargin < 1
                ipaddr = '192.168.0.63';
            end
            obj.ipaddr = ipaddr;
        end
        
        function g = Init(obj)
            RsrcName = strcat('TCPIP-',obj.ipaddr);
            g = instrfind('Type','tcpip','Name',RsrcName,'Tag','');
            if isempty(g)
                g = tcpip(obj.ipaddr,10001);
            else
                fclose(g);
                g = g(1);
            end
            % set the buffer size
            g.InputBufferSize = 8e6;
            g.OutputBufferSize = 8e6;
            % copy g to DevObj for the destructor
            obj.DevObj = g;
        end

        function  ActiveTrace = ReadTraceactive(obj)
            g = obj.Init();
            % open the connection
            fopen(g);
            % authentication
            obj.Authentication(g);
            fprintf(g,'CFORM1');
            fprintf(g,'*cls');
            % read the Active Trace
            ActiveTrace = query(g,sprintf(':TRACe:ACTive?'));
            % close
            fclose(g);
        end 

        function SetCenterWavelengthSpan(obj,center,span)
            g = obj.Init();
            % open the tcpip connection
            fopen(g);
            % authentication
            obj.Authentication(g);
            fprintf(g,'CFORM1');
            pause(0.02);
            % set the center wavelength and span
            fprintf(g,sprintf(':sens:wav:cent %1.4fnm',center));
            pause(0.01);
            fprintf(g,sprintf(':sens:wav:span %1.1fnm',span));
            pause(0.01);
            fclose(g);
        end
        
        function [wavelength,waveform] = GetOSATrace(obj)
%             if nargin < 2
%                 traceid = 'A';
%             end
            ActiveTrace = obj.ReadTraceactive();
            g = obj.Init();
            % open the tcpip connection
            fopen(g);
            % authentication
            obj.Authentication(g);
            fprintf(g,'CFORM1');
            pause(0.01);
            %% Get Data
            flushoutput(g);
            flushinput(g);
            % get the number of samples from OSA configuration
            n_samp = str2double(query(g,':SENS:SWE:POIN?'));
            % get the wavelength data
            get_txt = query(g,sprintf(':TRAC:X? %s,%d,%d',ActiveTrace,1,n_samp));
            x = textscan(get_txt,'%f','delimiter',',');
            wavelength = x{1};
            % get the waveform (power) data, n_avg iterations are averaged
            get_txt = query(g,sprintf(':TRAC:Y? %s,%d,%d',ActiveTrace,1,n_samp));
            y = textscan(get_txt,'%f','delimiter',',');
            waveform = y{1};
            % close the connection
            fclose(g);
        end
        
        function Single(obj)
            g = obj.Init();
            % open the tcpip connection
            fopen(g);
            % authentication
            obj.Authentication(g);
            fprintf(g,'CFORM1');
            % single
            fprintf(g,':init:smode 1'); % single
            fprintf(g,'*cls');
            fprintf(g,':init');
            % wait for operation finishes
            while(str2double(query(g,':stat:oper:even?')))
               pause(0.3); 
            end
            % close
            fclose(g);
        end
        
        function Repeat(obj)
            g = obj.Init();
            % open the tcpip connection
            fopen(g);
            % authentication
            obj.Authentication(g);
            fprintf(g,'CFORM1');
            % repeat
            fprintf(g,':INITiate:SMODe REPEAT'); % repeat
            fprintf(g,'*cls');
            fprintf(g,':init');
            % close
            fclose(g);
        end

        function markerVal = SetMarker(obj,markerid,wavelength)
            g = obj.Init();
            % open the connection
            fopen(g);
            % authentication
            obj.Authentication(g);
            fprintf(g,'CFORM1');
            fprintf(g,'*cls');
            pause(0.02);
            % turn on the Marker
            fprintf(g,sprintf(':CALCULATE:AMARKER %d ON',markerid));
            pause(0.02);
            % set the Marker
            fprintf(g,sprintf(':CALCULATE:AMARKER%d:X %1.3fnm',markerid,wavelength));
            pause(0.02);
            % read the marker value
            markerVal = [];
            while(isempty(markerVal))
                markerVal = str2double(query(g,sprintf(':CALCULATE:AMARKER%d:Y?',markerid)));
            end
            % close
            fclose(g);
        end
        
        function  markerVal = ReadMarkerValue(obj,markerid)
            g = obj.Init();
            % open the connection
            fopen(g);
            % authentication
            obj.Authentication(g);
            fprintf(g,'CFORM1');
            fprintf(g,'*cls');
            % read the marker value
            markerVal = str2double(query(g,sprintf(':CALCULATE:AMARKER%d:Y?',markerid)));
            % close
            fclose(g);
        end
            
        function t = TurnOffMarker(obj) % not work now
            t0 = cputime;
            g = obj.Init();
            t1 = cputime - t0;
            % open the connection
            fopen(g);
            t2 = cputime - t0;
            % authentication
            obj.Authentication(g);
            t3 = cputime - t0;
            % turn off the Marker
            fprintf(g,':CALCulate:MARKer:AOFF');
            t4 = cputime - t0;
            % close
            fclose(g);
            t5 = cputime - t0;
            t = [t1,t2,t3,t4,t5];
        end
        function Authentication(obj,g)
            % g: tcpip object
            % this function must be called after the connection is open
            fprintf(g,'OPEN "anonymous" ""');
            query(g,':stat:oper:even?');
            get_txt = cellstr(query(g,' '));
            if ~strcmp(get_txt{1},'ready')
                error('auth failed!');
            end
%             b = cputime - a;
%             fprintf('time is %1.4f\n',b);
        end
    end
end