classdef UI_exported < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure                matlab.ui.Figure
        LoadingLabel            matlab.ui.control.Label
        ImpedancesoffButton     matlab.ui.control.Button
        StopAcquisitionButton   matlab.ui.control.Button
        ImpedancesonButton      matlab.ui.control.Button
        StartAcquisitionButton  matlab.ui.control.Button
        UIAxes2                 matlab.ui.control.UIAxes
        UIAxes                  matlab.ui.control.UIAxes
    end

    properties (Access = public)
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
        outputArray
        savedFlag = false;
        step
        displayBuffer = zeros(23,1500);
        distancesBetweenChannels
        newBuffer
        zf = [];
    end

    properties (Access = private)
        EDAMP
    end
    methods (Access = private)
        
        function plotSignalData(app) 
            plot(app.UIAxes, app.displayBuffer);
            xlim(app.UIAxes, [0 1500]); 

            variables={'f7','fp1','fp2','f8','f3','fz','f4','c3','cz','p8','p7','pz','p4','t3','p3','o1','o2','c4','t4','a2','ac1','ac2','ac3'};
            
            xline(app.UIAxes, 500, '--');
            xline(app.UIAxes, 1000, '--');
            
            while app.EDAMP.WhileRunning && ~app.EDAMP.StopProcess
                tic
                app.EDAMP.extractFrames();
                app.outputArray = app.EDAMP.constructBuffer();
                
                preprocessedBuffer = zeros(23, 500);
                for i = 1:23
                    sensorData = app.outputArray(i, :);

                    detrended_data = detrend(sensorData);

                    minVal = min(detrended_data);
                    maxVal = max(detrended_data);
                    plotRange = maxVal - minVal;

                    rescaledData = (detrended_data - minVal) / plotRange;

                    preprocessedBuffer(i, :) = rescaledData;
                end

                fs = 500;
                cutFreq = 45; 
                filterOrder = 3;
                passband_ripple = 0.5;
                Wn = (2 * cutFreq) / fs; 
                [bL, aL] = cheby1(filterOrder, passband_ripple, Wn, 'low');

                sectionSize = 500; 
                out = zeros(size(preprocessedBuffer));               

                for i = 0:size(preprocessedBuffer, 2) / sectionSize - 1
                    range = i * sectionSize + 1 : (i + 1) * sectionSize; 
                    in = preprocessedBuffer(:, range);
                    [out(:, range), app.zf] = filter(bL, aL, in, app.zf, 2);
                end

                output = out;

                if ~app.savedFlag
                    app.step = max(output(:));
                    app.distancesBetweenChannels = 0:app.step:app.step*22;
                    app.distancesBetweenChannels = app.distancesBetweenChannels';
                    app.savedFlag = true;
                end

                app.newBuffer = output + app.distancesBetweenChannels;
                app.displayBuffer(:, 1:500) = app.newBuffer;
                app.displayBuffer = circshift(app.displayBuffer, [0, -500]);

                pause(0.6);
                app.LoadingLabel.Visible = 'off';
                plot(app.UIAxes, app.displayBuffer');
                yticks(app.UIAxes, app.distancesBetweenChannels);
                yticklabels(app.UIAxes, variables);
                xticks(app.UIAxes, linspace(0, 1500, 4));
                xticklabels(app.UIAxes, 0:4);
                xline(app.UIAxes, 500, '--');
                xline(app.UIAxes, 1000, '--');

                if ~app.EDAMP.WhileRunning || app.EDAMP.StopProcess
                    app.EDAMP.WhileRunning = false;
                    app.EDAMP.StopProcess = true;
                    disp("Frame acquisition paused");
                    break;
                end
                toc
                pause(0.1);
            end
        end

        function plotImpedanceData (app, src, event)
            cla(app.UIAxes2);

            ImpedanceValuesUI = src.ImpedanceValues;
            colors = zeros(size(app.Sensors, 1), 3); 

            for i = 1:size(app.Sensors, 1)
                if i <= numel(ImpedanceValuesUI) && ImpedanceValuesUI(i) < 2500
                    colors(i, :) = [0, 0.5, 0];  % Dark green
                elseif i <= numel(ImpedanceValuesUI) && ImpedanceValuesUI(i) > 5000
                    colors(i, :) = [1, 0, 0];  % Red
                else
                    colors(i, :) = [0.5, 0.8, 0.5];  % Light green
                end
            end

            scatter(app.UIAxes2, app.Sensors(:, 1), app.Sensors(:, 2), 200, colors, 'filled');

            xlabel(app.UIAxes2, ' ');
            ylabel(app.UIAxes2, 'Back to Front');
            title(app.UIAxes2, "Sensor's Status");

            xlim(app.UIAxes2, [0 1]);
            ylim(app.UIAxes2, [0 1]);
        end
        
        function clearAxis (app)
            cla(app.UIAxes2);
            colors = [0.5, 0.5, 0.5];
            scatter(app.UIAxes2, app.Sensors(:, 1), app.Sensors(:, 2), 200, colors, 'filled');
        end
    end

    % Callbacks that handle component events
    methods (Access = private)

        % Button pushed function: StartAcquisitionButton
        function StartAcquisitionButtonPushed(app, event)
            app.LoadingLabel.Visible = 'on';
            set(app.StopAcquisitionButton, 'Enable', 'on')
            set(app.ImpedancesoffButton, 'Enable', 'on')
            set(app.StartAcquisitionButton, 'Enable', 'off')

            if isempty(app.EDAMP) || ~isa(app.EDAMP, 'EDAM') || ~app.EDAMP.portInitialized
                % ADD SERIAL PORT NAME HERE 
                app.EDAMP = EDAM("COM3"); 
            end

            addlistener(app.EDAMP, 'ImpedanceDataEvent', @(src, event) plotImpedanceData(app, src, event));

            if ~app.EDAMP.WhileRunning
                app.EDAMP.WhileRunning = true;
                app.EDAMP.StopProcess = false;
                app.plotSignalData();
            else
                disp('Frame acquisition is already running.');
            end
        end

        % Button pushed function: ImpedancesonButton
        function ImpedancesonButtonPushed(app, event)
            app.EDAMP.ImpedancesOn();
            
            set(app.ImpedancesoffButton, 'Enable', 'on')
            set(app.ImpedancesonButton, 'Enable', 'off')
        end

        % Button pushed function: StopAcquisitionButton
        function StopAcquisitionButtonPushed(app, event)
            %app.EDAMP.isRunning = false;
            app.EDAMP.WhileRunning = false;
            disp('Terminated Connection');
            app.EDAMP.stopAcquisition();
            pause(1)
            app.step = [];
            app.savedFlag = false;
            app.EDAMP.delete();
            app.EDAMP = [];
            
            set(app.StartAcquisitionButton, 'Enable', 'on')
            set(app.ImpedancesoffButton, 'Enable', 'off')
            set(app.ImpedancesonButton, 'Enable', 'off')
            set(app.StopAcquisitionButton, 'Enable', 'off')
        end

        % Button pushed function: ImpedancesoffButton
        function ImpedancesoffButtonPushed(app, event)

            app.clearAxis();
            app.EDAMP.ImpedancesOff();
            
            set(app.ImpedancesonButton, 'Enable', 'on')
            set(app.ImpedancesoffButton, 'Enable', 'off')
        end
    end

    % Component initialization
    methods (Access = private)

        % Create UIFigure and components
        function createComponents(app)

            % Create UIFigure and hide until all components are created
            app.UIFigure = uifigure('Visible', 'off');
            app.UIFigure.Position = [100 100 1316 855];
            app.UIFigure.Name = 'MATLAB App';

            % Create UIAxes
            app.UIAxes = uiaxes(app.UIFigure);
            title(app.UIAxes, 'EEG Signals')
            xlabel(app.UIAxes, 'Time (3 seconds)')
            ylabel(app.UIAxes, 'Channels')
            zlabel(app.UIAxes, 'Z')
            app.UIAxes.XTick = [];
            app.UIAxes.YTick = [];
            app.UIAxes.YTickLabel = '';
            app.UIAxes.FontSize = 12;
            app.UIAxes.Position = [22 44 799 791];

            % Create UIAxes2
            app.UIAxes2 = uiaxes(app.UIFigure);
            title(app.UIAxes2, 'Impedences')
            xlabel(app.UIAxes2, 'X')
            ylabel(app.UIAxes2, 'Y')
            zlabel(app.UIAxes2, 'Z')
            app.UIAxes2.XTick = [];
            app.UIAxes2.YTick = [];
            app.UIAxes2.Position = [859 92 415 378];

            % Create StartAcquisitionButton
            app.StartAcquisitionButton = uibutton(app.UIFigure, 'push');
            app.StartAcquisitionButton.ButtonPushedFcn = createCallbackFcn(app, @StartAcquisitionButtonPushed, true);
            app.StartAcquisitionButton.FontName = 'Arial';
            app.StartAcquisitionButton.FontSize = 18;
            app.StartAcquisitionButton.Position = [986 710 166 31];
            app.StartAcquisitionButton.Text = 'Start Acquisition';

            % Create ImpedancesonButton
            app.ImpedancesonButton = uibutton(app.UIFigure, 'push');
            app.ImpedancesonButton.ButtonPushedFcn = createCallbackFcn(app, @ImpedancesonButtonPushed, true);
            app.ImpedancesonButton.FontSize = 18;
            app.ImpedancesonButton.Enable = 'off';
            app.ImpedancesonButton.Position = [986 583 166 31];
            app.ImpedancesonButton.Text = 'Impedances on';

            % Create StopAcquisitionButton
            app.StopAcquisitionButton = uibutton(app.UIFigure, 'push');
            app.StopAcquisitionButton.ButtonPushedFcn = createCallbackFcn(app, @StopAcquisitionButtonPushed, true);
            app.StopAcquisitionButton.FontName = 'Arial';
            app.StopAcquisitionButton.FontSize = 18;
            app.StopAcquisitionButton.Enable = 'off';
            app.StopAcquisitionButton.Position = [984 648 166 31];
            app.StopAcquisitionButton.Text = 'Stop Acquisition';

            % Create ImpedancesoffButton
            app.ImpedancesoffButton = uibutton(app.UIFigure, 'push');
            app.ImpedancesoffButton.ButtonPushedFcn = createCallbackFcn(app, @ImpedancesoffButtonPushed, true);
            app.ImpedancesoffButton.FontSize = 18;
            app.ImpedancesoffButton.Enable = 'off';
            app.ImpedancesoffButton.Position = [986 525 166 31];
            app.ImpedancesoffButton.Text = 'Impedances off';

            % Create LoadingLabel
            app.LoadingLabel = uilabel(app.UIFigure);
            app.LoadingLabel.HorizontalAlignment = 'center';
            app.LoadingLabel.FontSize = 24;
            app.LoadingLabel.Visible = 'off';
            app.LoadingLabel.Position = [322 469 200 52];
            app.LoadingLabel.Text = 'Loading...';

            % Show the figure after all components are created
            app.UIFigure.Visible = 'on';
        end
    end

    % App creation and deletion
    methods (Access = public)

        % Construct app
        function app = UI_exported

            % Create UIFigure and components
            createComponents(app)

            % Register the app with App Designer
            registerApp(app, app.UIFigure)

            if nargout == 0
                clear app
            end
        end

        % Code that executes before app deletion
        function delete(app)

            % Delete UIFigure when app is deleted
            delete(app.UIFigure)
        end
    end
end