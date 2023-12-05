classdef MyClass51 
    properties
        portInitialized = false;
        isRunning = false;
        WhileRunning = false;
        s = [];
        GI_avg2
        y_filtered = [];
        app
        M = zeros(23, 500);
        Sensors = [
                0.22, 0.7;   % F7
                0.37, 0.85;  % Fp1
                0.63, 0.85;  % Fp2
                0.78, 0.7;   % F8
                0.35, 0.68;  % F3
                0.5, 0.65;   % Fz
                0.65, 0.68;  % F4
                0.33, 0.5;   % C3
                0.5, 0.5;    % Cz
                0.78, 0.3;   % P8
                0.22, 0.3;   % P7
                0.5, 0.35;   % Pz
                0.65, 0.32;  % P4
                0.2, 0.5;    % T7
                0.35, 0.32;  % P3
                0.37, 0.15;  % O1
                0.63, 0.15;  % O2
                0.67, 0.5;   % C4
                0.8, 0.5;    % T8
                0.08, 0.5;   % A1
                0.92, 0.5    % A2
                ];
    end

    methods
        function obj = MyClass51(portName, app) ..."COM3"
            
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
                obj.app.PauseButtonPressed = false;
                tic
                while iteration <= 10 && obj.isRunning && ~obj.app.PauseButtonPressed
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
                            obj.GI_avg2 = mean(GI2, 2); % Compute row-wise average (along dimension 2)
                            obj.GI_avg2 = squeeze(obj.GI_avg2); % Remove singleton dimensions if any
                            obj.GI_avg2 = obj.GI_avg2(1:end-2);

                            se(:, 1:50) = mb;
                            se = circshift(se, [0, -50]);
                            y = filter([0.85, 0, 0.85], [1, 0, 0.7], se);
                            y2 = filter([0.8, 0.8], [1, 0.6], y);
                            obj.M(:, 1:50) = y2(:, 51:100);
                            obj.M = circshift(obj.M, [0, -50]);

                        end
                        pause(0.1 - toc)
                        if ~obj.isRunning || obj.app.PauseButtonPressed
                            obj.isRunning = false;
                            obj.app.PauseButtonPressed = true;
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
                if obj.app.getImpedances 
                    obj.plotSensorData();
                end
            else
                error('Serial port is not properly initialized.');
            end
            y_f = obj.y_filtered;
        end

        function startAcquisition(obj)
            if obj.isRunning
                disp("Frame acquisition is already running.");
                return;
            end

            obj.isRunning = true;
            obj.frameAcquisition();
        end

        function stopAcquisition(obj)
            obj.isRunning = false;
            obj.delete();
        end

        function pauseAcquisition(obj)
            obj.app.PauseButtonPressed = true;
        end

        function ImpOn(obj)
                obj.app.getImpedances = true;
        end

        function ImpOff(obj)
                obj.app.getImpedances = false;
                cla(obj.app.UIAxes2);
                colors = [0.5, 0.5, 0.5];
                scatter(obj.app.UIAxes2, obj.Sensors(:, 1), obj.Sensors(:, 2), 200, colors, 'filled');
        end

        function plotData(obj)
            YP = [];
            plot(obj.app.UIAxes, YP);
            xlim(obj.app.UIAxes, [0 1500]); 

            variables={'f7','fp1','fp2','f8','f3','fz','f4','c3','cz','p8','p7','pz','p4','t3','p3','o1','o2','c4','t4','a2','ac1','ac2','ac3'};
            D = [0.01, 0.02, 0.03, 0.04, 0.05, 0.06, 0.07, 0.08, 0.09, 0.1, 0.11, 0.12, 0.13, 0.14, 0.15, 0.16, 0.17, 0.18, 0.19, 0.2, 0.21, 0.22, 0.23];
            %D = 0.0005:0.0005:0.0115;
            D = D';

            xline(obj.app.UIAxes, 500, '--');
            xline(obj.app.UIAxes, 1000, '--');
            
            while obj.WhileRunning && ~obj.app.PauseButtonPressed
                obj.isRunning = true;
                y_f = obj.frameAcquisition();

                tic
                this = y_f + D;
                YP = [YP, this];

                if size(YP, 2) > 1500
                    YP = YP(:, end-1500:end);
                end
                
                pause(0.3);
                plot(obj.app.UIAxes, YP');
                yticks(obj.app.UIAxes, D + 0.00015);
                yticklabels(obj.app.UIAxes, variables);
                xticks(obj.app.UIAxes, linspace(0, 1500, 4));
                xticklabels(obj.app.UIAxes, 0:4);
                xline(obj.app.UIAxes, 500, '--');
                xline(obj.app.UIAxes, 1000, '--');

                if ~obj.WhileRunning || obj.app.PauseButtonPressed
                    obj.WhileRunning = false;
                    obj.app.PauseButtonPressed = true;
                    disp("Frame acquisition paused");
                    break;
                end
                toc
                pause(0.1);
            end
        end

        function plotSensorData(obj)
            cla(obj.app.UIAxes2);
            
            colors = zeros(size(obj.Sensors, 1), 3); 

            for i = 1:size(obj.Sensors, 1)
                if i <= numel(obj.GI_avg2) && obj.GI_avg2(i) < 2500
                    colors(i, :) = [0, 0.5, 0];  % Dark green
                elseif i <= numel(obj.GI_avg2) && obj.GI_avg2(i) > 5000
                    colors(i, :) = [1, 0, 0];  % Red
                else
                    colors(i, :) = [0.5, 0.8, 0.5];  % Light green
                end
            end

            scatter(obj.app.UIAxes2, obj.Sensors(:, 1), obj.Sensors(:, 2), 200, colors, 'filled');

            xlabel(obj.app.UIAxes2, ' ');
            ylabel(obj.app.UIAxes2, 'Back to Front');
            title(obj.app.UIAxes2, "Sensor's Status");

            xlim(obj.app.UIAxes2, [0 1]);
            ylim(obj.app.UIAxes2, [0 1]);
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
            Lsb2 = TempACC(1, 2:3:end);
            Lsb1 = TempACC(1, 3:3:end);
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