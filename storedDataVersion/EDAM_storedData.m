classdef EDAM_storedData < handle
    events
        myEvent
    end
    properties
        portInitialized = false;
        isRunning = false;
        WhileRunning = false;
        setPause = false;
        getImpedances = false;
        recorded_data = [];
        ind    
        ImpedanceValues
        finalFiterArray = [];
        secondFiterArray
        % oneSecondArray = zeros(23, 500);
        save_flag = false;
        subtract
        bufferArray = [];
    end

    methods
        function obj = EDAM_storedData(portName) ..."COM3"
            
            obj.portInitialized = false;
            
            obj = obj.initializePort(portName);
        end

        function obj = initializePort(obj, portName)
            if isempty(obj.recorded_data)
                obj.recorded_data = load(portName);
                obj.portInitialized = true;
                % disp(obj.recorded_data)
                obj.ind = find(obj.recorded_data.data == 255, 1); %new line
                disp("Port initialized successfully");
            else
                error('Serial port object is already initialized.');
            end
        end

        function output_array = frameAcquisition(obj)
            if obj.portInitialized
                disp("Data aquisition starting...");
                % iteration =1;
                obj.isRunning = true;
                obj.setPause = false;
                tic
                % iteration <= 10 &&
                while obj.isRunning && ~obj.setPause
                    % prepareForFilters = zeros(23, 150);
                    
                    % secondFiterArray = zeros(23, 100);
                    % firstFiterArray = zeros(23, 100);

                    while size(obj.bufferArray,2) < 712500
                        if isempty(obj.recorded_data)
                            error('Serial port object is not valid or properly initialized.');
                        end

                        oneFrame = obj.recorded_data.data(obj.ind:obj.ind+74); %new line
                        if (oneFrame(1) == 255 && oneFrame(75) == 0)
                            obj.bufferArray = [obj.bufferArray, oneFrame];
                        else
                            disp("discard frame at: "+obj.ind)
                            break;
                        end
                        if size(obj.bufferArray, 2) == 712500
                            break;
                        end
                        obj.ind = obj.ind + 75;
                    end
                    if size(obj.bufferArray, 2) == 712500
                        makeBuffer = obj.make_buffer(obj.bufferArray);
                        if ~obj.save_flag
                            obj.subtract = makeBuffer(:,1);
                            obj.save_flag = true;
                        end
                        result = makeBuffer - obj.subtract;
                        firstFiterArray = filter([0.85, 0, 0.85], [1, 0, 0.7], result, [], 2);
                        obj.secondFiterArray = filter([0.8, 0.8], [1, 0.6], firstFiterArray, [], 2);
                        pause(0.1 - toc)
                    end
                    if ~obj.isRunning || obj.setPause
                        obj.isRunning = false;
                        obj.setPause = true;
                        disp("Frame acquisition paused");
                        break;
                    end
                    if (obj.ind >= 730000) % ...size(obj.recorded_data.data,2)-40500)
                            obj.setPause = true;
                        obj.isRunning = false;
                        disp("Finished the recorded data");
                        break;
                    end
                    % iteration = iteration +1;

                    % for i = 1:11
                    %     oneTenthOfSecondArray = [];
                    % 
                    %     while size(oneTenthOfSecondArray,2) < 3750
                    %         if isempty(obj.recorded_data) 
                    %             error('Serial port object is not valid or properly initialized.');
                    %         end
                    % 
                    %         oneFrame = obj.recorded_data.data(obj.ind:obj.ind+74); %new line
                    %         if (oneFrame(1) == 255 && oneFrame(75) == 0)
                    %             oneTenthOfSecondArray = [oneTenthOfSecondArray, oneFrame];
                    %         else
                    %             disp("error") 
                    %             break;
                    %         end
                    %         if size(oneTenthOfSecondArray, 2) == 3750
                    %             break;
                    %         end
                    %         obj.ind = obj.ind + 75;
                    %     end
                    %     %disp("out "+obj.ind)
                    %     if size(oneTenthOfSecondArray, 2) == 3750
                    %         disp("Frame acquired successfully");
                    %         makeBuffer = obj.make_buffer(oneTenthOfSecondArray);
                    % 
                    %         %get impedences
                    %         makeBuffer_reshaped = reshape(makeBuffer(:, 1:8), [], 2, 4); % Reshape mb into a 23x2x4 array
                    %         diff_1 = abs(makeBuffer_reshaped(:, :, 1) - makeBuffer_reshaped(:, :, 3)) / 2;
                    %         diff_2 = abs(makeBuffer_reshaped(:, :, 2) - makeBuffer_reshaped(:, :, 4)) / 2;
                    %         extractImpedances = max(diff_1, diff_2);
                    %         extractImpedances = extractImpedances * 265000000;
                    %         obj.ImpedanceValues = mean(extractImpedances, 2); % Compute row-wise average (along dimension 2)
                    %         obj.ImpedanceValues = squeeze(obj.ImpedanceValues); % Remove singleton dimensions if any
                    %         obj.ImpedanceValues = obj.ImpedanceValues(1:end-2);
                    % 
                    %         if ~obj.save_flag
                    %             obj.subtract = makeBuffer(:,1);
                    %             obj.save_flag = true;
                    %         end
                    %         result = makeBuffer - obj.subtract;
                    %         % firstFiterArray = filter([0.85, 0, 0.85], [1, 0, 0.7], result,[],2);
                    % 
                    %         % secondFiterArray = filter([0.8, 0.8], [1, 0.6], firstFiterArray,[],2);
                    % 
                    %         % [finalFiterArray,something] = highpass((secondFiterArray)', 0.5, 500);
                    %         % finalFiterArray = (finalFiterArray)';
                    % 
                    %         prepareForFilters(:, 1:50) = result;
                    %         prepareForFilters = circshift(prepareForFilters, [0, -50]);
                    %         firstFiterArray = filter([0.85, 0, 0.85], [1, 0, 0.7], prepareForFilters, [], 2);
                    %         secondFiterArray = filter([0.8, 0.8], [1, 0.6], firstFiterArray, [], 2);
                    %         obj.oneSecondArray(:, 1:50) = secondFiterArray(:, 51:100);
                    %         obj.oneSecondArray = circshift(obj.oneSecondArray, [0, -50]);
                    % 
                    %     end
                    %     pause(0.1 - toc)
                    %     if ~obj.isRunning || obj.setPause
                    %         obj.isRunning = false;
                    %         obj.setPause = true;
                    %         disp("Frame acquisition paused");
                    %         break;
                    %     end
                    %     if (obj.ind >= 730000) ...size(obj.recorded_data.data,2)-40500)
                    %         obj.setPause = true;
                    %         obj.isRunning = false;
                    %         disp("Finished the recorded data");
                    %         break;
                    %     end
                    %     iteration = iteration +1;
                    % end
                    obj.isRunning = false;
                end
                toc
                %disp("out "+obj.ind)
                % disp(size(obj.secondFiterArray))
                disp("Data acquisition finished")
                obj.finalFiterArray = highpass((obj.secondFiterArray)', 0.5, 500); % ..., 'Steepness', 0.8, 'StopbandAttenuation', 30);
                obj.finalFiterArray = (obj.finalFiterArray)';
                if obj.getImpedances 
                    notify(obj, 'myEvent');
                end
            else
                error('Serial port is not properly initialized.');
            end
            output_array = obj.finalFiterArray;
        end

        function pauseAcquisition(obj)
            obj.setPause = true;
        end

        function ImpOn(obj)
                obj.getImpedances = true;
        end

        function ImpOff(obj)
                obj.getImpedances = false;
        end

        % function plotData(obj)
        %     maxDataPoints = 1500;  
        %     YP = [];
        %     plot(obj.app.UIAxes, YP);
        %     xlim(obj.app.UIAxes, [0 maxDataPoints]); 
        % 
        %     variables={'f7','fp1','fp2','f8','f3','fz','f4','c3','cz','p8','p7','pz','p4','t3','p3','o1','o2','c4','t4','a2','ac1','ac2','ac3'};
        %     %D = [0.01, 0.02, 0.03, 0.04, 0.05, 0.06, 0.07, 0.08, 0.09, 0.1, 0.11, 0.12, 0.13, 0.14, 0.15, 0.16, 0.17, 0.18, 0.19, 0.2, 0.21, 0.22, 0.23];
        %     %D = [0.005, 0.01, 0.015, 0.02, 0.025, 0.03, 0.035, 0.04, 0.045, 0.05, 0.055, 0.06, 0.065, 0.07, 0.075, 0.08, 0.085, 0.09, 0.095, 0.1, 0.105, 0.11, 0.115];
        %     D = 0.0001:0.0001:0.0023;
        %     D = D';
        % 
        %     while obj.WhileRunning && ~obj.app.PauseButtonPressed
        %         obj.isRunning = true;
        %         %disp(" 1: " +size(YP, 2))
        %         y_f = obj.frameAcquisition();
        %         tic
        %         this = y_f + D;
        %         YP = [YP, this];
        %         %disp(" 2: " +size(YP, 2))
        % 
        %         if size(YP, 2) > 1500
        %             YP = YP(:, end-1500:end);
        %         end
        % 
        %         pause(0.3);
        %         plot(obj.app.UIAxes, YP');
        %         yticks(obj.app.UIAxes, D + 0.00015);
        %         yticklabels(obj.app.UIAxes, variables);
        % 
        %         if ~obj.WhileRunning || obj.app.PauseButtonPressed
        %             obj.WhileRunning = false;
        %             obj.app.PauseButtonPressed = true;
        %             disp("Frame acquisition paused");
        %             break;
        %         end
        %         toc
        %         pause(0.1);
        %     end
        %     %mike@cognionics.com, info@cognionics.com
        % end

        % function plotSensorData(obj)
        %     cla(obj.app.UIAxes2);
        % 
        %     colors = zeros(size(obj.Sensors, 1), 3); 
        % 
        %     for i = 1:size(obj.Sensors, 1)
        %         if i <= numel(obj.ImpedanceValues) && obj.ImpedanceValues(i) < 2500
        %             colors(i, :) = [0, 0.5, 0];  % Dark green
        %         elseif i <= numel(obj.ImpedanceValues) && obj.ImpedanceValues(i) > 5000
        %             colors(i, :) = [1, 0, 0];  % Red
        %         else
        %             colors(i, :) = [0.5, 0.8, 0.5];  % Light green
        %         end
        %     end
        % 
        %     % condition1 = obj.ImpedanceValues < 2500;
        %     % condition2 = obj.ImpedanceValues > 5000;
        %     % 
        %     % % Set colors based on conditions
        %     % colors(condition1, :) = [0, 0.5, 0];  % Dark green
        %     % colors(condition2, :) = [1, 0, 0];    % Red
        %     % 
        %     % % Default color (light green)
        %     % default_color = [0.5, 0.8, 0.5];
        %     % colors(~(condition1 | condition2), :) = default_color;
        % 
        %     scatter(obj.app.UIAxes2, obj.Sensors(:, 1), obj.Sensors(:, 2), 200, colors, 'filled');
        % 
        %     xlabel(obj.app.UIAxes2, ' ');
        %     ylabel(obj.app.UIAxes2, 'Back to Front');
        %     title(obj.app.UIAxes2, "Sensor's Status");
        % 
        %     xlim(obj.app.UIAxes2, [0 1]);
        %     ylim(obj.app.UIAxes2, [0 1]);
        % end

        % function delete(obj)
        %     delete(obj.serial_port.data5);
        % end

        function mb = make_buffer(~, A)
            index = find(A == 255);
            locate_69_B = bsxfun(@plus, index.', 2:70);
            extract_69_B = ismember(1:numel(A), locate_69_B(:));

            temp_array = A(extract_69_B);
            % MSB = temp_array(1,1:3:end);
            % 
            % indices_to_convert = MSB >= 128 & MSB <= 255;
            % MSB(indices_to_convert) = -(255 - MSB(indices_to_convert) );
            % converted_indices(indices_to_convert) = true;
            % 
            % LSB2 = temp_array(1,2:3:end);
            % LSB2(converted_indices) = - (255 - LSB2(converted_indices) ); % 2's complement
            % LSB1 = temp_array(1,3:3:end);
            % LSB1(converted_indices) = - (255 - LSB1(converted_indices) + 1); % 2's complement
            % MSB = (MSB/2).*2^14;
            % LSB2 = (LSB2/2).*2^7;
            % LSB1 = (LSB1/2);
            % channel_array = MSB+LSB2+LSB1;
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
            mb = buffer;
        end
    end
end