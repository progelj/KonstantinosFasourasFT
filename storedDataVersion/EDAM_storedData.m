classdef EDAM_storedData_breakdown < handle
    events
        myEvent
    end
    properties
        dataInitialized = false;
        WhileRunning = false;
        StopProcess = false;
        getImpedances = false;
        ImpedanceValues
        recorded_data = [];
        ind    
        check
        makeBuffer
        result
        save_flag = false;
        subtract
        bufferArray = [];
        idx
        idx2
        frameCounter = [];
        end_frame
        frame_starts
        zf = [];
    end

    methods
        function obj = EDAM_storedData_breakdown(fileName) 
            
            obj.dataInitialized = false;
            
            obj = obj.initializeFile(fileName);
        end

        function obj = initializeFile(obj, fileName)
            if isempty(obj.recorded_data)
                obj.recorded_data = load(fileName);
                obj.dataInitialized = true;

                obj.ind = find(obj.recorded_data.data == 255, 1);
                obj.check = obj.recorded_data.data(obj.ind+71);
                disp(obj.check)
                obj.frame_starts = find(obj.recorded_data.data == 255);
                obj.end_frame = length(obj.frame_starts) - 51;

                disp("Data initialized successfully");
            else
                error('Serial port object is already initialized.');
            end
        end

        function obj = loadData(obj)
            tic
            if obj.dataInitialized
                disp("Data loading starting...");
                % frames_to_store = buffer(frame_starts(1):frame_starts(end_frame)-1);
                obj.bufferArray = [];
                while size(obj.bufferArray,2) < 37500 
                    if size(obj.recorded_data.data, 2) < obj.ind + 37500
                        disp("Data finished")
                        break;
                    end
                    if isempty(obj.recorded_data)
                        error('Serial port object is not valid or properly initialized.');
                    end
                    oneFrame = obj.recorded_data.data(obj.ind:obj.ind+74); 
                    obj.idx = find(oneFrame == 255);
                    if (oneFrame(1) == 255 && oneFrame(74) == 0 && size(obj.idx,2) == 1) 
                        obj.bufferArray = [obj.bufferArray, oneFrame];
                    elseif (oneFrame(1) ~= 255 && size(obj.idx,2) == 1 )
                        grr = obj.idx-1;
                        % grr = 75-obj.idx-1;
                        obj.ind = obj.ind+grr;
                        disp("jumped frame")
                    else
                        if size(obj.idx,2)>1
                            oneFrame(obj.idx(2:end)) = bitset(oneFrame(obj.idx(2:end)), 1, 0);
                        end
                        obj.idx2 = find(oneFrame == 255);
                        if (oneFrame(1) == 255 && size(obj.idx2,2) == 1)
                            obj.bufferArray = [obj.bufferArray, oneFrame];
                        else
                            disp("error")
                        end
                    end
                    if size(obj.bufferArray, 2) == 37500
                        disp("Data ready...")
                        break;
                    end
                    
                    obj.ind = obj.ind + 75;
                end
            end
            toc
        end
        
        function output_array = constructBuffer(obj)
            if size(obj.bufferArray, 2) == 37500
                obj.makeBuffer = obj.make_buffer(obj.bufferArray);
                
                obj.result = obj.makeBuffer; 
            else
                disp("error in constructBuffer")
            end

            if obj.check ==17
                obj.extractImpedances()
                notify(obj, 'myEvent');
                output_array = obj.ImpOnFilters();
            elseif obj.check ==18
                output_array = obj.ImpOffNoFilters();
            end
                
        end

        function output = ImpOffNoFilters(obj)
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

        function output = ImpOnFilters(obj)

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

        function stopAcquisition(obj)
            obj.StopProcess = false;
            
        end

        function ImpOn(obj)
                obj.getImpedances = true;
                obj.check = 17;
        end

        function ImpOff(obj)
                obj.getImpedances = false;
                obj.check = 18;
        end

        function mb = make_buffer(~, A)
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
            mb=channel_data;
        end
    end
end