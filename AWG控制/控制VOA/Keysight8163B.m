classdef Keysight8163B < Device
    % copyright Tianwai@PSRL,KAIST
    % 2018/09/05: add TCPIP support, add dual channel support
    % 2019/01/24: add GPIB support for the auto calibration
    % 2022/07/14: remove IPAddr from the properties as it is now defined in
    %               Device.m
    % 2022/07/15: introduce SlotChannelInfo and chID_to_slot_chan_vec to
    %               improve the compability of the code
    
    properties
        SlotChannelInfo;
    end

    properties (Dependent = true)
        
    end

    methods
        function obj = Keysight8163B(addr)
            % addr: address, could be number (for GPIB) or string (for TCP)
            if nargin <1
                addr = 20;
            end
            obj.Addr = addr;
            % determine the address type and connection method
            if ischar(addr)
                obj.ConnectionType = 'TCPIP';
            elseif isa(addr,'double')
                obj.ConnectionType = 'GPIB';
            else
                error('Please input correct address!');
            end
            % set device name
            obj.DeviceName = 'Keysight 8163B Lightwave Multimeter';
            obj.VISA_Vendor = 'Keysight';
            % collect slot channel info
            obj.SlotChannelInfo = obj.CollectSlotChannelInfo();
        end

        function SlotChannelInfo = CollectSlotChannelInfo(obj)
            % initial value
            SlotChannelInfo = zeros(4,2);
            id = 0;
            % check the module model
            for idx = 1:2
                txt = obj.Read(sprintf(':slot%d:idn?',idx));
                if ~isempty(txt)
                    tmp = regexp(txt,',','split');
                    slotModel = tmp{2};
                    if strcmpi(slotModel,'81635A')
                    SlotChannelInfo(id+1,:) = [idx,1];
                    SlotChannelInfo(id+2,:) = [idx,2];
                    id = id + 2;
                    else
                        SlotChannelInfo(id+1,:) = [idx,1];
                    id = id + 1;
                    end
                end
            end
            SlotChannelInfo(id+1:end,:) = [];
        end
        

        function Pow = Read_Power_by_Channel_ID(obj,chID)
            % The channel ID (chID) is defined as the chID-th port in the
            % power meter, from the up to down in channel, from left to 
            % right in slot
            %
            % this function is combined into Read_Power(slot,channel)

            slot_chan_mat = obj.SlotChannelInfo;
            
            id = size(slot_chan_mat,1);
            if chID > id
                error('The chID is larger than the total number of channels!');
            end
            obj.DevObj = obj.Init();
            fopen(obj.DevObj);
            Pow = str2double(query(obj.DevObj,...
                sprintf('fetc%d:chan%d:pow?',...
                slot_chan_mat(chID,1),...
                slot_chan_mat(chID,2))));
            fclose(obj.DevObj);
        end

        function slot_chan_vec = chID_to_slot_chan_vec(obj,chIDs)
            % get the slot & channel configurations of the device
            slot_chan_mat = obj.SlotChannelInfo;
            NumPhysicalChannels = size(slot_chan_mat,1);
            % check chID
            if numel(chIDs) == 1 % a single number
                if chIDs > NumPhysicalChannels
                    error('The chID is larger than the total number of channels!');
                end
                slot_chan_vec = slot_chan_mat(chIDs,:);
            elseif numel(chIDs) == 2
                vec = reshape(chIDs,1,[]);
                if ~all(sum(slot_chan_mat-vec,1))
                    slot_chan_vec = reshape(chIDs,1,[]);
                else
                    error('Wrong channel & slot pair, please check!');
                end
            end
        end
        
        function Pow = Read_Power(obj,slot,channel)
            % Slot: | slot 1 | slot 2 |   screen   |
            % Chan: | Ch1,Ch2| slot 2 |   screen   |
            % channel is the id of channel in the module with two monitoring
            % channels such as 81635A
            %
            % if only slot is input while channel is left blank
            %   if slot is a single number, slot = chID
            %       channel ID (chID) is defined as the chID-th port in the
            %       power meter, from the up to down in channel, from left to 
            %       right in slot
            %   if slot is a 1x2 or 2x1 vector
            %       same as [slot, channel]

            if nargin == 2
                channel = [];
                chID = slot;
                slot_chan_vec = obj.chID_to_slot_chan_vec(chID);
            end

            if nargin == 3
                slot_chan_vec = obj.chID_to_slot_chan_vec([slot,channel]);
            end
            
            % read power
            obj.DevObj = obj.Init();
            fopen(obj.DevObj);
            Pow = str2double(query(obj.DevObj,...
                sprintf('fetc%d:chan%d:pow?',...
                slot_chan_vec(1),...
                slot_chan_vec(2))));
            fclose(obj.DevObj);
        end
        
        function AutoCalibration(obj,CaliChNo,RefChNo)
            % 20190124 add support for old 8163B mainframe
            fprintf('The channel to be calibrated is %d\n',CaliChNo);
            fprintf('The channel used as a reference is %d\n',RefChNo);
            fprintf('If no problem, press any key to continue...\n');
            pause();
            % convert from chIDs to SlotChannelVecs
            scv_ref = obj.chID_to_slot_chan_vec(RefChNo);
            scv_cali = obj.chID_to_slot_chan_vec(CaliChNo);

            % read the current calibration values
            dev = obj.Init();
            fopen(dev);
            cmd = sprintf(':sens%d:chan%d:corr?',scv_ref(1),scv_ref(2));
            thisRefChCaliVal = str2double(query(dev,cmd));
            cmd = sprintf(':sens%d:chan%d:corr?',scv_cali(1),scv_cali(2));
            thisCaliChCaliVal = str2double(query(dev,cmd));
            % read the current power of each channel
            thisRefOptPow = obj.Read_Power(RefChNo)+thisRefChCaliVal;
            thisCaliOptPow = obj.Read_Power(CaliChNo)+thisCaliChCaliVal;
            % set the calibration value of the calibrated channel
            newCaliVal = thisCaliOptPow - thisRefOptPow;
            fopen(dev);
            cmd = sprintf(':sens%d:chan%d:corr %1.6f', ...
                scv_cali(1),scv_cali(2),newCaliVal);
            fprintf(dev,cmd);
            fclose(dev);

            % output the updated calibration value
            fprintf('Updated calibration value: Ch%d(Ref): %1.4fdB; Ch%d(Target): %1.4fdB\n',...
                RefChNo,thisRefChCaliVal,CaliChNo,newCaliVal);


        end
        
        function ClearCalibrate(obj,chID)
            slot_chan_vec = obj.chID_to_slot_chan_vec(chID);

            dev = obj.Init();
            fopen(dev);
            cmd = sprintf(':sens%d:chan%d:corr 0',slot_chan_vec(1),slot_chan_vec(2));
            fprintf(dev,cmd);
            % read back
            cmd = sprintf(':sens%d:chan%d:corr?',slot_chan_vec(1),slot_chan_vec(2));
            caliVal = str2double(query(dev,cmd));
            fprintf('Channel %d current calibration value is %1.6f\n',chID,caliVal);
            fclose(dev);
        end
        
        function Set_WL(obj,chID,wave)
            % wave: wavelength, unit: nm
            slot_chan_vec = obj.chID_to_slot_chan_vec(chID);
           
            cmd = sprintf(':sens%d:chan%d:pow:wav %1.1fnm',...
                slot_chan_vec(1),slot_chan_vec(2),wave);

            obj.Set(cmd);
            fprintf('The wavelength of Channel %d has been set to be %1.1f nm.\n',...
                chID,wave);
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
        
        function SetAverageTime(obj,chID,time)
            % time unit: second

            slot_chan_vec = obj.chID_to_slot_chan_vec(chID);
            
            cmd = sprintf(':outp%d:chan%d:atim %1.1f', ...
                slot_chan_vec(1),slot_chan_vec(2),time);
            
            obj.Set(cmd);
            fprintf('The averaging time of Channel %d has been set to be %d ms.\n',...
                chID,time*1e3);
        end
        
    end
end