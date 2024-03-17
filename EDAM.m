classdef EDAM < handle
    %UNTITLED Summary of this class goes here
    %   Detailed explanation goes here
    events
        ImpedanceDataEvent
    end

    properties
        portInitialized = false;
        serial_port = [];
        setPause = false;
        isRunning = false;
        WhileRunning = false;
        oneSecondBuffer = zeros(1,37500);
        counter = 0;
        idx
        idx2
        getImpedances = false;
        ImpedanceValues
        makeBuffer
        subtract
        save_flag = false;
        result = [];
        zf = [];
    end

    methods
        function obj = EDAM(portName)
            %UNTITLED Construct an instance of this class
            %   Detailed explanation goes here
            obj.portInitialized = false;

            if nargin > 0
                obj = obj.initializePort(portName);
            end
        end

        function obj = initializePort(obj, portName)
            %METHOD1 Summary of this method goes here
            %   Detailed explanation goes here
            if isempty(obj.serial_port)
                obj.serial_port = serialport(portName, 3000000, "Timeout", 10);
                disp("Serial port object created successfully");
                obj.startOfFrame();
            else
                error('Serial port object is already initialized.');
            end
        end

        function obj = ImpedancesOn(obj)
            write(obj.serial_port, 17, "uint8")
            obj.getImpedances = true;
        end

        function obj = ImpedancesOff(obj)
            write(obj.serial_port, 18, "uint8")
            obj.getImpedances = false;
        end
        
        function obj = startOfFrame(obj)
            obj.flushSerialPort();
            % get start of frame
            data2 = read(obj.serial_port, 100, "uint8");
            ind = find(data2 == 255);
            % check if frame is of correct format
            if size(ind,2) == 1
                reminder = 100 - ind;
                get_reminder = 75 - reminder-1;
                if(get_reminder<0)
                    get_reminder = 75+get_reminder;
                end
                read(obj.serial_port, get_reminder, "uint8");
            elseif size(ind,2) > 1
                rem = ind(2);
                get_reminder = 75 - rem-1;
                if(get_reminder<0)
                    get_reminder = 75+get_reminder;
                end
                read(obj.serial_port, get_reminder, "uint8");
            end
            obj.portInitialized = true;
            disp("Port initialized successfully");
        end

        function flushSerialPort(obj)
            flush(obj.serial_port);
        end

        function obj = extractFrames(obj)
            global FrameRecorder;
            if obj.portInitialized
                obj.oneSecondBuffer = zeros(1,37500);
                while obj.oneSecondBuffer(1,1) == 0
                    if isempty(obj.serial_port) || ~isvalid(obj.serial_port)
                        error('Serial port object is not valid or properly initialized.');
                    end
                    oneFrame = read(obj.serial_port, 75, "uint8");
                    % we store the data for later investigation
                    FrameRecorder{obj.counter+1} = {oneFrame};
                    obj.counter = obj.counter + 1;

                    obj.idx = find(oneFrame == 255);
                    % check if frame is of correct format
                    if (oneFrame(1) == 255 && size(obj.idx,2) == 1)
                        obj.oneSecondBuffer(:, 1:75) = oneFrame;
                        obj.oneSecondBuffer = circshift(obj.oneSecondBuffer, [0, -75]);
                    elseif (oneFrame(1) ~= 255 && size(obj.idx,2) == 1 )
                        grr = obj.idx-1;
                        garb = read(obj.serial_port, grr, "uint8");
                        FrameRecorder{obj.counter+1} = {garb};
                        obj.counter = obj.counter + 1;
                    else
                        if size(obj.idx,2)>1
                            oneFrame(obj.idx(2:end)) = bitset(oneFrame(obj.idx(2:end)), 1, 0);
                        end
                        obj.idx2 = find(oneFrame == 255);
                        if (oneFrame(1) == 255 && size(obj.idx2,2) == 1)
                            obj.oneSecondBuffer(:, 1:75) = oneFrame;
                            obj.oneSecondBuffer = circshift(obj.oneSecondBuffer, [0, -75]);
                        else
                            disp("error")
                        end
                    end
                end
            end
        end

        function output_array = constructBuffer(obj)
            obj.makeBuffer = obj.make_buffer(obj.oneSecondBuffer);
            if ~obj.save_flag
                obj.subtract = obj.makeBuffer(:,1);
                obj.save_flag = true;
            end
            obj.result = obj.makeBuffer - obj.subtract;
            
            if obj.getImpedances
                obj.extractImpedances();
                notify(obj, 'ImpedanceDataEvent');
                output_array = obj.ImpOnFilters();
            elseif ~obj.getImpedances
                output_array = obj.ImpOffNoFilters();
            end
        end

        function output = ImpOffNoFilters(obj)
            output = obj.result;
        end

        function obj = extractImpedances(obj)
            %get impedances
            makeBuffer_reshaped = reshape(obj.makeBuffer(:, 1:8), [], 2, 4); % Reshape mb into a 23x2x4 array
            diff_1 = abs(makeBuffer_reshaped(:, :, 1) - makeBuffer_reshaped(:, :, 3)) / 2;
            diff_2 = abs(makeBuffer_reshaped(:, :, 2) - makeBuffer_reshaped(:, :, 4)) / 2;
            extractImpedances = max(diff_1, diff_2);
            extractImpedances = extractImpedances * 265000000;
            obj.ImpedanceValues = mean(extractImpedances, 2); % Compute row-wise average (along dimension 2)
            obj.ImpedanceValues = squeeze(obj.ImpedanceValues); % Remove singleton dimensions if any
            obj.ImpedanceValues = obj.ImpedanceValues(1:end-2);
        end

        function output = ImpOnFilters(obj)
            cutFreq = 0.5; 
            filterOrder = 3;
            Wn = (2*cutFreq)/500; 
            [bL,aL] = butter(filterOrder, Wn, 'high');

            sectionSize=500;
            out=zeros(size(obj.result));

            for i=0:size(obj.result,2)/sectionSize-1
                range=i*500+1:(i+1)*500;
                in=obj.result(:,range);
                [out(:,range),obj.zf] = filter(bL,aL,in,obj.zf,2);
            end
            % data2 = filter(bL, aL, obj.result, [], 2);
            output = out;
        end

        function obj = pauseAcquisition(obj)
            obj.setPause = true;
        end

        function delete(obj)
            delete(obj.serial_port);
        end

        function mb = make_buffer(obj, A)
            % this method gets the extracted data from the eeg device ad
            % constructs the channels.
            
            Data = uint8(A);
            starts = find(Data == 255);
            b0 = starts(1:end);
            num_channels = 23;

            channel_data = zeros(num_channels, length(b0));
            for CH = 1:num_channels
                % Extract data for the current channel
                B1 = Data(b0 + 2 + 3*(CH - 1));
                B2 = Data(b0 + 3 + 3*(CH - 1));
                B3 = Data(b0 + 4 + 3*(CH - 1));

                % Process the data for negative numbers
                B1c = bitcmp(B1);
                B1c = bitset(B1c, 1, 0);
                B2c = bitcmp(B2);
                B2c = bitset(B2c, 1, 0);
                B3c = bitcmp(B3);
                B3c = bitset(B3c, 1, 0);

                B = (double(B1) .* 2^13 + double(B2) .* 2^6 + double(B3) ./ 2) .* 2^3;
                negB = -(double(B1c) .* 2^13 + double(B2c) .* 2^6 + double(B3c) ./ 2) .* 2^3;
                B(B1 > 127) = negB(B1 > 127);

                % Store the processed data in the matrix
                channel_data(CH, :) = B * 5 / 3 * 2^(-32);
            end
            if Data(72) == 18
                obj.getImpedances = false;
            else
                obj.getImpedances = true;
            end
            mb=channel_data;

        end

    end
end
