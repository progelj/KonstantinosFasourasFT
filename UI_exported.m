classdef UI_exported < matlab.apps.AppBase

    % Properties that correspond to app components
    properties (Access = public)
        UIFigure                matlab.ui.Figure
        ImpedancesoffButton     matlab.ui.control.Button
        StopAcquisitionButton   matlab.ui.control.Button
        ImpedancesonButton      matlab.ui.control.Button
        StartAcquisitionButton  matlab.ui.control.Button
        PauseAcquisitionButton  matlab.ui.control.Button
        MakeConnectionButton    matlab.ui.control.Button
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
        saved_flag = false;
        step
        displayBuffer
        distancesBetweenChannels
        newBuffer
        output_array
    end

    properties (Access = private)
        EDAMP
    end 
    methods (Access = private)
        
        function plotSignalData (app)
            % this function runs every second and calls the
            % frameAcquisition from EDAM in order to extract the new data
            % from the EEG device. Then it concatenates data worth up to 3
            % seconds and displays them.
            app.displayBuffer = [];
            plot(app.UIAxes, app.displayBuffer);
            xlim(app.UIAxes, [0 1500]); 

            variables={'f7','fp1','fp2','f8','f3','fz','f4','c3','cz','p8','p7','pz','p4','t3','p3','o1','o2','c4','t4','a2','ac1','ac2','ac3'};
            % distancesBetweenChannels = [0.01, 0.02, 0.03, 0.04, 0.05, 0.06, 0.07, 0.08, 0.09, 0.1, 0.11, 0.12, 0.13, 0.14, 0.15, 0.16, 0.17, 0.18, 0.19, 0.2, 0.21, 0.22, 0.23];
            % %D = 0.0005:0.0005:0.0115;
            % distancesBetweenChannels = distancesBetweenChannels';

            xline(app.UIAxes, 500, '--');
            xline(app.UIAxes, 1000, '--');
            
            while app.EDAMP.WhileRunning && ~app.EDAMP.setPause
                app.EDAMP.isRunning = true;
                app.output_array = app.EDAMP.frameAcquisition();

                if ~app.saved_flag
                    app.step = max(app.output_array(:));
                    app.distancesBetweenChannels = 0:app.step:app.step*22;
                    app.distancesBetweenChannels = app.distancesBetweenChannels';
                    app.saved_flag = true;
                end
                
                tic
                app.newBuffer = app.output_array + app.distancesBetweenChannels;
                app.displayBuffer = [app.displayBuffer, app.newBuffer];

                if size(app.displayBuffer, 2) > 1500
                    app.displayBuffer = app.displayBuffer(:, end-1500:end);
                end
                
                pause(0.8);
                plot(app.UIAxes, app.displayBuffer');
                yticks(app.UIAxes, app.distancesBetweenChannels);
                yticklabels(app.UIAxes, variables);
                xticks(app.UIAxes, linspace(0, 1500, 4));
                xticklabels(app.UIAxes, 0:4);
                xline(app.UIAxes, 500, '--');
                xline(app.UIAxes, 1000, '--');

                if ~app.EDAMP.WhileRunning || app.EDAMP.setPause
                    app.EDAMP.WhileRunning = false;
                    app.EDAMP.setPause = true;
                    disp("Frame acquisition paused");
                    break;
                end
                toc
                pause(0.1);
                % app.output_array = [];
            end
        end

        function plotImpedanceData (app, src, event)
            % this function checks the values of the impedances and gives
            % them the appropriate color based on their value; red for
            % missplaced sensors, dark green for perfectly placed sensors,
            % light green for good placed sensors
            cla(app.UIAxes2);

            ImpedanceValuesUI = src.ImpedanceValues;
            colors = zeros(size(app.Sensors, 1), 3); 

            % for i = 1:size(app.Sensors, 1)
            %     if i <= numel(app.EDAMP.ImpedanceValues) && app.EDAMP.ImpedanceValues(i) < 2500
            %         colors(i, :) = [0, 0.5, 0];  % Dark green
            %     elseif i <= numel(app.EDAMP.ImpedanceValues) && app.EDAMP.ImpedanceValues(i) > 5000
            %         colors(i, :) = [1, 0, 0];  % Red
            %     else
            %         colors(i, :) = [0.5, 0.8, 0.5];  % Light green
            %     end
            % end

            % Define conditions
            condition1 = ImpedanceValuesUI < 2500;
            condition2 = ImpedanceValuesUI > 5000;

            % Set colors based on conditions
            colors(condition1, :) = [0, 0.5, 0];  % Dark green
            colors(condition2, :) = [1, 0, 0];    % Red

            % Default color (light green)
            default_color = [0.5, 0.8, 0.5];
            colors(~(condition1 | condition2), :) = default_color;

            scatter(app.UIAxes2, app.Sensors(:, 1), app.Sensors(:, 2), 200, colors, 'filled');

            xlabel(app.UIAxes2, ' ');
            ylabel(app.UIAxes2, 'Back to Front');
            title(app.UIAxes2, "Sensor's Status");

            xlim(app.UIAxes2, [0 1]);
            ylim(app.UIAxes2, [0 1]);
        end

        function clearAxis (app)
            % this function clears the plot responsible for displaying
            % the impedances
            cla(app.UIAxes2);
            colors = [0.5, 0.5, 0.5];
            scatter(app.UIAxes2, app.Sensors(:, 1), app.Sensors(:, 2), 200, colors, 'filled');
        end

    end

    % Callbacks that handle component events
    methods (Access = private)

        % Button pushed function: MakeConnectionButton
        function MakeConnectionButtonPushed(app, event)
            % % Get a list of available serial ports
            % ports = serialportlist("all");
            % 
            % % Initialize a flag to check if the USB drive was found
            % usbDriveFound = false;
            % 
            % % Initialize the port name variable
            % usbPortName = '';
            % 
            % % Define a function to check if a port is valid
            % checkPort = @(port) fopen(serialport(port, 'BaudRate', 3000000), 'Status');
            % 
            % % Use arrayfun to apply the checkPort function to all ports
            % portStatus = arrayfun(checkPort, ports);
            % 
            % % Find the first valid port
            % index = find(portStatus, 1);
            % 
            % if ~isempty(index)
            %     usbDriveFound = true;
            %     usbPortName = ports{index};
            % end
            % 
            % if usbDriveFound
            %     disp(['USB Drive found on port: ' usbPortName]);
            % else
            %     disp('USB Drive not found.');
            % end
            
            %   HERE IS WHERE YOU INSERT THE PORT NAME MANUALLY -> usbPortName
            if isempty(app.EDAMP) || ~isa(app.EDAMP, 'EDAM') || ~app.EDAMP.portInitialized
                app.EDAMP = EDAM("COM3"); ..."COM3"
            end

            set(app.StartAcquisitionButton, 'Enable', 'on')
            set(app.MakeConnectionButton, 'Enable', 'off')
        end

        % Button pushed function: PauseAcquisitionButton
        function PauseAcquisitionButtonPushed(app, event)
            app.EDAMP.isRunning = false;
            app.EDAMP.WhileRunning = false;
            disp('Paused');
            app.EDAMP.pauseAcquisition();

            set(app.StopAcquisitionButton, 'Enable', 'on')
            set(app.PauseAcquisitionButton, 'Enable', 'off')
        end

        % Button pushed function: StartAcquisitionButton
        function StartAcquisitionButtonPushed(app, event)
            set(app.PauseAcquisitionButton, 'Enable', 'on')
            set(app.ImpedancesoffButton, 'Enable', 'on')
            set(app.StartAcquisitionButton, 'Enable', 'off')
            
            addlistener(app.EDAMP, 'ImpedanceDataEvent', @(src, event) plotImpedanceData(app, src, event));
            if ~app.EDAMP.WhileRunning
                app.EDAMP.WhileRunning = true;
                app.EDAMP.setPause = false;
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
            app.EDAMP.isRunning = false;
            app.EDAMP.WhileRunning = false;
            disp('Terminated Connection');
            app.step = [];
            app.saved_flag = false;
            app.EDAMP.delete();
            app.EDAMP = [];

            set(app.MakeConnectionButton, 'Enable', 'on')
            set(app.StartAcquisitionButton, 'Enable', 'off')
            set(app.PauseAcquisitionButton, 'Enable', 'off')
            set(app.ImpedancesoffButton, 'Enable', 'off')
            set(app.ImpedancesonButton, 'Enable', 'off')
            set(app.StopAcquisitionButton, 'Enable', 'off')
        end

        % Button pushed function: ImpedancesoffButton
        function ImpedancesoffButtonPushed(app, event)
            app.EDAMP.ImpedancesOff();
            app.clearAxis();

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
            app.UIAxes2.Position = [857 44 415 378];

            % Create MakeConnectionButton
            app.MakeConnectionButton = uibutton(app.UIFigure, 'push');
            app.MakeConnectionButton.ButtonPushedFcn = createCallbackFcn(app, @MakeConnectionButtonPushed, true);
            app.MakeConnectionButton.FontName = 'Arial';
            app.MakeConnectionButton.FontSize = 18;
            app.MakeConnectionButton.Position = [982 743 166 31];
            app.MakeConnectionButton.Text = 'Make Connection';

            % Create PauseAcquisitionButton
            app.PauseAcquisitionButton = uibutton(app.UIFigure, 'push');
            app.PauseAcquisitionButton.ButtonPushedFcn = createCallbackFcn(app, @PauseAcquisitionButtonPushed, true);
            app.PauseAcquisitionButton.FontName = 'Arial';
            app.PauseAcquisitionButton.FontSize = 18;
            app.PauseAcquisitionButton.Enable = 'off';
            app.PauseAcquisitionButton.Position = [982 622 166 31];
            app.PauseAcquisitionButton.Text = 'Pause Acquisition';

            % Create StartAcquisitionButton
            app.StartAcquisitionButton = uibutton(app.UIFigure, 'push');
            app.StartAcquisitionButton.ButtonPushedFcn = createCallbackFcn(app, @StartAcquisitionButtonPushed, true);
            app.StartAcquisitionButton.FontName = 'Arial';
            app.StartAcquisitionButton.FontSize = 18;
            app.StartAcquisitionButton.Enable = 'off';
            app.StartAcquisitionButton.Position = [982 684 166 31];
            app.StartAcquisitionButton.Text = 'Start Acquisition';

            % Create ImpedancesonButton
            app.ImpedancesonButton = uibutton(app.UIFigure, 'push');
            app.ImpedancesonButton.ButtonPushedFcn = createCallbackFcn(app, @ImpedancesonButtonPushed, true);
            app.ImpedancesonButton.FontSize = 18;
            app.ImpedancesonButton.Enable = 'off';
            app.ImpedancesonButton.Position = [984 499 166 31];
            app.ImpedancesonButton.Text = 'Impedances on';

            % Create StopAcquisitionButton
            app.StopAcquisitionButton = uibutton(app.UIFigure, 'push');
            app.StopAcquisitionButton.ButtonPushedFcn = createCallbackFcn(app, @StopAcquisitionButtonPushed, true);
            app.StopAcquisitionButton.FontName = 'Arial';
            app.StopAcquisitionButton.FontSize = 18;
            app.StopAcquisitionButton.Enable = 'off';
            app.StopAcquisitionButton.Position = [982 561 166 31];
            app.StopAcquisitionButton.Text = 'Stop Acquisition';

            % Create ImpedancesoffButton
            app.ImpedancesoffButton = uibutton(app.UIFigure, 'push');
            app.ImpedancesoffButton.ButtonPushedFcn = createCallbackFcn(app, @ImpedancesoffButtonPushed, true);
            app.ImpedancesoffButton.FontSize = 18;
            app.ImpedancesoffButton.Enable = 'off';
            app.ImpedancesoffButton.Position = [984 437 166 31];
            app.ImpedancesoffButton.Text = 'Impedances off';

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