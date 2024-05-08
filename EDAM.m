classdef EDAM < handle
    %UNTITLED Summary of this class goes here
    %   Detailed explanation goes here
    events
        ImpedanceDataEvent
    end

    properties
        portInitialized = false;
        serialPort = [];
        StopProcess = false;
        WhileRunning = false;
        oneSecondBuffer = zeros(1,37500);
        counter = 0;
        idx
        idx2
        impedances = false;
        ImpedanceValues
        makeBuffer
        result = [];
        zf = [];
    end

    methods
        function obj = EDAM(portName)
            obj.portInitialized = false;

            if nargin > 0
                obj = obj.initializePort(portName);
            end
        end

        function obj = initializePort(obj, portName)
            if isempty(obj.serialPort)
                obj.serialPort = serialport(portName, 3000000, "Timeout", 10);
                disp("Serial port object created successfully");
                obj.startOfFrame();
            else
                error('Serial port object is already initialized.');
            end
        end

        function obj = ImpedancesOn(obj)
            write(obj.serialPort, 17, "uint8")
            obj.impedances = true;
        end

        function obj = ImpedancesOff(obj)
            write(obj.serialPort, 18, "uint8")
            obj.impedances = false;
        end
        
        function obj = startOfFrame(obj)
            obj.flushSerialPort();
            % get start of frame
            data2 = read(obj.serialPort, 100, "uint8");
            ind = find(data2 == 255);
            % check if frame is of correct format
            if size(ind,2) == 1
                reminder = 100 - ind;
                get_reminder = 75 - reminder-1;
                if(get_reminder<0)
                    get_reminder = 75+get_reminder;
                end
                read(obj.serialPort, get_reminder, "uint8");
            elseif size(ind,2) > 1
                rem = ind(2);
                get_reminder = 75 - rem-1;
                if(get_reminder<0)
                    get_reminder = 75+get_reminder;
                end
                read(obj.serialPort, get_reminder, "uint8");
            end
            obj.portInitialized = true;
            disp("Port initialized successfully");
        end

        function flushSerialPort(obj)
            flush(obj.serialPort);
        end

        function obj = extractFrames(obj)
            global FrameRecorder;
            if obj.portInitialized
                obj.oneSecondBuffer = zeros(1,37500);
                while obj.oneSecondBuffer(1,1) == 0
                    if isempty(obj.serialPort) || ~isvalid(obj.serialPort)
                        error('Serial port object is not valid or properly initialized.');
                    end
                    oneFrame = read(obj.serialPort, 75, "uint8");
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
                        garb = read(obj.serialPort, grr, "uint8");
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
            
            obj.result = obj.makeBuffer; 
            
            if obj.impedances
                obj.extractImpedances();
                notify(obj, 'ImpedanceDataEvent');
                output_array = obj.ImpedancesOnFinalOutput();
            elseif ~obj.impedances
                output_array = obj.ImpedancesOffFinalOutput();
            end
        end

        function output = ImpedancesOffFinalOutput(obj)
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

            output = out;
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

        function output = ImpedancesOnFinalOutput(obj)
            firstFiterArray = filter([0.85, 0, 0.85], [1, 0, 0.7], obj.result, [], 2);
            secondFiterArray = filter([0.8, 0.8], [1, 0.6], firstFiterArray, [], 2);

            cutFreq = 0.5; 
            filterOrder = 3;
            Wn = (2*cutFreq)/500; 
            [bL,aL] = butter(filterOrder, Wn, 'high');

            sectionSize=500;
            out=zeros(size(secondFiterArray));

            for i=0:size(secondFiterArray,2)/sectionSize-1
                range=i*500+1:(i+1)*500;
                in=secondFiterArray(:,range);
                [out(:,range),obj.zf] = filter(bL,aL,in,obj.zf,2);
            end
            
            output = out;
        end

        function obj = stopAcquisition(obj)
            obj.StopProcess = true;
            
        end

        function delete(obj)
            delete(obj.serialPort);
        end

        function mb = make_buffer(obj, A)
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
                obj.impedances = false;
            else
                obj.impedances = true;
            end
            mb=channel_data;
        end

    end
end