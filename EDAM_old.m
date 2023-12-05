classdef EDAM 
    properties
        portInitialized = false;
        isRunning = false;
        WhileRunning = false;
        setPause = false;
        getImpedances = true;
        s = [];
        ImpedanceValues
        y_filtered = [];
        app
        M = zeros(23, 500);
        
    end

    methods
        function obj = EDAM(portName, app) ..."COM3" 
            
            obj.portInitialized = false;
            obj.app = app;

            if nargin > 0
                obj = obj.initializePort(portName);
            end
        end

        function obj = initializePort(obj, portName)
            if isempty(obj.s)
                obj.s = serialport(portName, 3000000, "Timeout", 10);
                disp("Serial port object created successfully");
                data2 = read(obj.s, 100, "uint8");
                ind = find(data2 == 255, 1);
                if ind<25
                    ind = ind+75;
                end
                rem = 100-ind;
                gr = 75-rem-1;
                if(gr<0)
                    gr = 75+gr;
                end
                read(obj.s, gr, "uint8");
                obj.portInitialized = true;
                disp("Port initialized successfully");
            else
                error('Serial port object is already initialized.');
            end
            cla(obj.app.UIAxes);
            cla(obj.app.UIAxes2);
        end

        function y_f = frameAcquisition(obj)
            if obj.portInitialized
                disp("Frame aquisition starting...");
                iteration =1;
                obj.isRunning = true;
                obj.setPause = false;
                tic
                while iteration <= 10 && obj.isRunning && ~obj.setPause
                    se = zeros(23, 150);
                    obj.M = zeros(23, 500);
                    y2 = zeros(23, 100);
                    y = zeros(23, 100);

                    for i = 1:11
                        NWT = [];
                        while size(NWT,2) < 3750
                            if isempty(obj.s) || ~isvalid(obj.s)
                                error('Serial port object is not valid or properly initialized.');
                            end

                            first = read(obj.s, 75, "uint8");
                            if (first(1) == 255 && first(75) == 0)
                                NWT = [NWT, first];
                            else
                                idx = find(first == 255, 1);
                                rem2 = 75 - idx;
                                grr = 75-rem2-1;
                                if(grr == 0)
                                    grr = 75;
                                end
                                read(obj.s, grr, "uint8");
                            end
                            if size(NWT, 2) == 3750
                                break;
                            end
                        end
                        if size(NWT, 2) == 3750
                            disp("Frame acquired successfully");
                            mb = obj.make_buffer(NWT);

                            %get impedences
                            mb_reshaped = reshape(mb(:, 1:8), [], 2, 4); % Reshape mb into a 23x2x4 array
                            diff_1 = abs(mb_reshaped(:, :, 1) - mb_reshaped(:, :, 3)) / 2;
                            diff_2 = abs(mb_reshaped(:, :, 2) - mb_reshaped(:, :, 4)) / 2;
                            GI2 = max(diff_1, diff_2);
                            GI2 = GI2 * 265000000;
                            obj.ImpedanceValues = mean(GI2, 2); % Compute row-wise average (along dimension 2)
                            obj.ImpedanceValues = squeeze(obj.ImpedanceValues); % Remove singleton dimensions if any
                            obj.ImpedanceValues = obj.ImpedanceValues(1:end-2);

                            se(:, 1:50) = mb;
                            se = circshift(se, [0, -50]);
                            y = filter([0.85, 0, 0.85], [1, 0, 0.7], se);
                            y2 = filter([0.8, 0.8], [1, 0.6], y);
                            obj.M(:, 1:50) = y2(:, 51:100);
                            obj.M = circshift(obj.M, [0, -50]);

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
                obj.y_filtered = highpass(obj.M, 0.5, 500, 'Steepness', 0.8, 'StopbandAttenuation', 30);
                if obj.getImpedances 
                    %obj.app.impedanceData();
                    functionHandle();
                end
            else
                error('Serial port is not properly initialized.');
            end
            y_f = obj.y_filtered;
        end

        function pauseAcquisition(obj)
            obj.setPause = true;
            functionHandle = @impedanceData;
        end

        function ImpOn(obj)
                obj.getImpedances = true;
        end

        function ImpOff(obj)
                obj.getImpedances = false;
        end

        function delete(obj)
            delete(obj.s);
        end

        function mb = make_buffer(~, A)
            idx = find(A == 255);
            linearIdx = bsxfun(@plus, idx.', 2:70);
            mask = ismember(1:numel(A), linearIdx(:));
            TempACC = A(mask);
            Msb = TempACC(1, 1:3:end);
            converted_indices = false(size(Msb));
            for i = 1:length(Msb)
                if Msb(i) >= 128 && Msb(i) <= 255
                    Msb(i) = - (255 - Msb(i) + 1); % 2's complement
                    converted_indices(i) = true; % Mark this index as converted
                end
            end
            Lsb2 = TempACC(1, 2:3:end);
            Lsb2(converted_indices) = - (255 - Lsb2(converted_indices) + 1); % 2's complement
            Lsb1 = TempACC(1, 3:3:end);
            Lsb1(converted_indices) = - (255 - Lsb1(converted_indices) + 1); % 2's complement
            Msb = (Msb / 2) .* 2^14;
            Lsb2 = (Lsb2 / 2) .* 2^7;
            Lsb1 = Lsb1 / 2;
            TempC = Msb + Lsb2 + Lsb1;
            TempC = TempC * 2^3 * (5 / 3) * (1 / 2^32);
            buff = reshape(TempC, 23, []);
            buff(end-2:end, :) = buff(end-2:end, :) * (2.5 / 1.667);
            mb = buff;
        end
    end
end
