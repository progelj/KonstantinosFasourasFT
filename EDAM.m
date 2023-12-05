classdef EDAM_cc < handle
    events
        ImpedanceDataEvent
    end
    properties
        portInitialized = false;
        isRunning = false;
        WhileRunning = false;
        setPause = false;
        getImpedances = false;
        serial_port = [];
        ImpedanceValues
        finalFiterArray = [];
        oneSecondArray = zeros(23, 500);
        oneTenthOfSecondArray =[]
        secondFiterArray = zeros(23, 100);
        firstFiterArray = zeros(23, 100);
        save_flag = false
        subtract
        ImpedanceFlag = false
    end

    methods
        function obj = EDAM_cc(portName) 
            % Construct an instance of this class, it initializes the port and
            % app object and then calls the initializePort function if
            % possible.
            obj.portInitialized = false;

            if nargin > 0
                obj = obj.initializePort(portName);
            end
        end

        function obj = initializePort(obj, portName)
            % this method makes a connection with the serial port in
            % order to extract the data from the eeg device. then we find
            % the first start of frame (sof) and display that everything is
            % ready.
            if isempty(obj.serial_port)
                obj.serial_port = serialport(portName, 3000000, "Timeout", 10);
                disp("Serial port object created successfully");
                % % to disable the impedance check ------------------------
                write(obj.serial_port, 18, "uint8")
                % get start of frame
                data2 = read(obj.serial_port, 100, "uint8");
                ind = find(data2 == 255, 1);
                if ind<25
                    ind = ind+75;
                end
                reminder = 100-ind;
                get_reminder = 75-reminder-1;
                if(get_reminder<0)
                    get_reminder = 75+gr;
                end
                read(obj.serial_port, get_reminder, "uint8");
                obj.portInitialized = true;
                disp("Port initialized successfully");
            else
                error('Serial port object is already initialized.');
            end
            
        end

        function output_array = frameAcquisition(obj)
            % this method has 10 iterations, it extracts data worth of 0.1
            % second ten times and checks for their credibility, then it
            % creates the chaannels and apply 3 filters on them. Also it
            % extracts the impedances too for later use. Its output is the
            % buffer that will get plotted.
            if obj.portInitialized
                disp("Frame aquisition starting...");
                iteration =1;
                obj.isRunning = true;
                obj.setPause = false;
                tic
                while iteration <= 10 && obj.isRunning && ~obj.setPause
                    % prepareForFilters = zeros(23, 150);
                    obj.oneSecondArray = zeros(23, 500);

                    for i = 1:10
                        obj.oneTenthOfSecondArray = [];
                        while size(obj.oneTenthOfSecondArray,2) < 3750
                            if isempty(obj.serial_port) || ~isvalid(obj.serial_port)
                                error('Serial port object is not valid or properly initialized.');
                            end

                            oneFrame = read(obj.serial_port, 75, "uint8");
                            if (oneFrame(1) == 255 && oneFrame(75) == 0)
                                obj.oneTenthOfSecondArray = [obj.oneTenthOfSecondArray, oneFrame];
                            else
                                idx = find(oneFrame == 255, 1);
                                rem2 = 75 - idx;
                                grr = 75-rem2-1;
                                if(grr == 0)
                                    grr = 75;
                                end
                                read(obj.serial_port, grr, "uint8");
                            end
                            if size(obj.oneTenthOfSecondArray, 2) == 3750
                                break;
                            end
                        end
                        if size(obj.oneTenthOfSecondArray, 2) == 3750
                            disp("Frame acquired successfully");
                            makeBuffer = obj.make_buffer(obj.oneTenthOfSecondArray);
                            if ~obj.save_flag
                                obj.subtract = makeBuffer(:,1);
                                obj.save_flag = true;
                            end

                            %get impedences
                            % if obj.ImpedanceFlag == true
                            %     makeBuffer_reshaped = reshape(makeBuffer(:, 1:8), [], 2, 4); % Reshape mb into a 23x2x4 array
                            %     diff_1 = abs(makeBuffer_reshaped(:, :, 1) - makeBuffer_reshaped(:, :, 3)) / 2;
                            %     diff_2 = abs(makeBuffer_reshaped(:, :, 2) - makeBuffer_reshaped(:, :, 4)) / 2;
                            %     extractImpedances = max(diff_1, diff_2);
                            %     extractImpedances = extractImpedances * 265000000;
                            %     obj.ImpedanceValues = mean(extractImpedances, 2); % Compute row-wise average (along dimension 2)
                            %     obj.ImpedanceValues = squeeze(obj.ImpedanceValues); % Remove singleton dimensions if any
                            %     obj.ImpedanceValues = obj.ImpedanceValues(1:end-2);
                            % end

                            result = makeBuffer - obj.subtract;
                            % prepareForFilters(:, 1:50) = makeBuffer;
                            % prepareForFilters = circshift(prepareForFilters, [0, -50]);
                            obj.firstFiterArray = filter([0.85, 0, 0.85], [1, 0, 0.7], result, [], 2);
                            obj.secondFiterArray = filter([0.8, 0.8], [1, 0.6], obj.firstFiterArray, [], 2);
                            obj.oneSecondArray(:, 1:50) = obj.secondFiterArray;
                            obj.oneSecondArray = circshift(obj.oneSecondArray, [0, -50]);

                        end
                        pause(0.1 - toc)
                        if ~obj.isRunning || obj.setPause
                            obj.isRunning = false;
                            obj.setPause = true;
                            disp("Frame acquisition paused");
                            break;
                        end
                        iteration = iteration +1;
                    end
                    obj.isRunning = false;
                end
                toc
                disp("end")
                obj.finalFiterArray = highpass((obj.oneSecondArray)', 0.5, 500); %, 'Steepness', 0.8, 'StopbandAttenuation', 30);
                obj.finalFiterArray = (obj.finalFiterArray)';
                if obj.getImpedances 
                    notify(obj, 'ImpedanceDataEvent');
                end
            else
                error('Serial port is not properly initialized.');
            end
            % obj.save_flag = false;
            output_array = obj.finalFiterArray;
        end

        function pauseAcquisition(obj)
            obj.setPause = true;
        end

        function ImpedancesOn(obj)
                obj.getImpedances = true;
        end

        function ImpedancesOff(obj)
                obj.getImpedances = false;
        end

        function delete(obj)
            delete(obj.serial_port);
        end

        function mb = make_buffer(obj, A)
            % this method gets the extracted data from the eeg device ad
            % constructs the channels.
            index = find(A == 255);
            locate_69_B = bsxfun(@plus, index.', 2:70);
            extract_69_B = ismember(1:numel(A), locate_69_B(:));

            temp_array = A(extract_69_B);
            MSB = temp_array(1,1:3:end);
            binaryBuffer = dec2bin(MSB, 8); % Convert to binary (8 bits)
            sevenBitsMSB = binaryBuffer(:, 1:7); % Extract 7 most significant bits
            MSB7 = bin2dec(sevenBitsMSB); % Convert back to decimal
            indices_to_convert = MSB7 >= 64 & MSB7 <= 127;
            MSB7(indices_to_convert) = -(127 - MSB7(indices_to_convert) );

            LSB2 = temp_array(1,2:3:end);
            binaryBuffer2 = dec2bin(LSB2, 8);
            sevenBitsLSB2 = binaryBuffer2(:, 1:7); % Extract 7 most significant bits
            LSB27 = bin2dec(sevenBitsLSB2); % Convert back to decimal
            LSB27(indices_to_convert) = - (127 - LSB27(indices_to_convert) ); % 2's complement
            
            LSB1 = temp_array(1,3:3:end);
            binaryBuffer3 = dec2bin(LSB1, 8);
            sevenBitsLSB1 = binaryBuffer3(:, 1:7); % Extract 7 most significant bits
            LSB17 = bin2dec(sevenBitsLSB1); % Convert back to decimal
            LSB17(indices_to_convert) = - (127 - LSB17(indices_to_convert) + 1); % 2's complement
            
            MSB7 = (MSB7/2).*2^14;
            LSB27 = (LSB27/2).*2^7;
            LSB17 = (LSB17/2);
            channel_array = MSB7+LSB27+LSB17;
            channel_array = channel_array*2^3;
            channel_array = channel_array*(5/3)*(1/2^32);

            buffer = reshape(channel_array, 23, []);
            buffer(end-2:end, :) = buffer(end-2:end, :) * (2.5 / 1.667);
            if A(72) == 18
                obj.ImpedanceFlag = false;
            else
                obj.ImpedanceFlag = true;
            end
            mb = buffer;
        end
    end
end