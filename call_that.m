timeout = 30;
start_time = datetime('now');
end_time = start_time + seconds(timeout);
while datetime('now') < end_time
    test4
    pause(3);
    %pause(3);
    % Get the handle of the plot axes from test4.m
    %plotAxes = evalin('base', 'plotAxes');
    % Transfer the plot to myAxes in the App Designer
    %copyobj(get(plotAxes, 'children'), app.UIAxes);
    %set(app.UIAxes, 'YTick', D+0.0025, 'YTickLabel', variables);
    %app.UIAxes.YAxis.TickLength = [0, 0];
    %app.UIAxes.XTick = linspace(0, 100, 11);
    %app.UIAxes.XTickLabel = 0:10;
    % Pause for a short duration before the next iteration
end



%myObject = MyClass('COM3');
%myObject.frameAcquisition();

%while datetime('now') < end_time
%    myObject.frameAcquisition();
%    pause(3);
%end




