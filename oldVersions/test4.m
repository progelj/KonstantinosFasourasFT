
%% Section1

global portInitialized
if isempty(portInitialized)
    se = zeros(23,30);
    M = zeros(23, 100);
    y2 = zeros(23,20);
    y = zeros(23,20);
    %NWT = zeros(1,750);
    s = serialport("COM3", 3000000, "Timeout", 10);
    data2 = read(s, 100, "uint8");
    ind = find(data2 == 255, 1);
    if ind<25
        ind = ind+75;
    end
    rem = 100-ind;
    gr = 75-rem-1;
    if(gr<0)
        gr = 75+gr;
    end
    getRem = read(s,gr,"uint8");
    portInitialized = true;
end

for i=1:10
    timeout = 10;  
    start_time = tic;
    tic
    NWT = [];

    while toc(start_time) <= timeout
        first = read(s, 75, "uint8");
        if (first(1) == 255 && first(75) == 0)
            NWT = [NWT, first];
        else
            idx = find(first == 255, 1);
            rem2 = 75-idx;
            grr = rem2-1;
            if(grr<0)
                grr = 75+grr;
            end
            getRem = read(s,grr,"uint8");
        end
        if size(NWT, 2) == 750
            break;  
        end
    end

    if size(NWT, 2) == 750
        disp("Frame acquired successfully");
        mb = make_buffer(NWT);

        %get impedences
        mb_reshaped = reshape(mb(:, 1:8), [], 2, 4); % Reshape mb into a 23x2x4 array
        diff_1 = abs(mb_reshaped(:, :, 1) - mb_reshaped(:, :, 3)) / 2;
        diff_2 = abs(mb_reshaped(:, :, 2) - mb_reshaped(:, :, 4)) / 2;
        GI2 = max(diff_1, diff_2);
        GI2 = GI2 * 265000000;
        GI_avg2 = mean(GI2, 2); % Compute row-wise average (along dimension 2)
        GI_avg2 = squeeze(GI_avg2); % Remove singleton dimensions if any
        GI_avg2 = GI_avg2(1:end-3);
        %

        se(:,1:10) = mb;
        se = circshift(se, [0,-10]);
        
        y = filter([0.85,0,0.85],[1,0,0.7],se);
       
        y2 = filter([0.8,0.8],[1,0.6],y);
        M(:,1:10)=y2(:,11:20);
        M = circshift(M, [0,-10]);
    else
        disp("Frame acquisition failed");
    end
    pause(0.1 - toc) 
end
%% Section2
disp("end")
y_filtered = highpass(M, 0.5, 500,Steepness=0.5,StopbandAttenuation=30);

cla(app.UIAxes);

variables={'f7','fp1','fp2','f8','f3','fz','f4','c3','cz','p8','p7','pz','p4','t3','p3','o1','o2','c4','t4','a2','ac1','ac2','ac3'};   
D = [0.01, 0.02, 0.03, 0.04, 0.05, 0.06, 0.07, 0.08, 0.09, 0.1, 0.11, 0.12, 0.13, 0.14, 0.15, 0.16, 0.17, 0.18, 0.19, 0.2, 0.21, 0.22, 0.23];
D = D';
YP = y_filtered + D;


plot(app.UIAxes, YP');
yticks(app.UIAxes, D+0.0025);
yticklabels(app.UIAxes, variables);
app.UIAxes.YAxis.TickLength = [0, 0];

xticks(app.UIAxes, linspace(0, 100, 11));
xticklabels(app.UIAxes, 0:10);

Sensors =[
  [0.22, 0.7],   ...F7
  [0.37, 0.85],   ...Fp1
  [0.63, 0.85],   ...Fp2
  [0.78, 0.7],   ...F8
  [0.35, 0.68],   ...F3
  [0.5, 0.65],   ...Fz
  [0.65, 0.68],   ...F4
  [0.33, 0.5],   ...C3
  [0.5, 0.5],   ...Cz
  [0.78, 0.3],   ...P8
  [0.22, 0.3],   ...P7
  [0.5, 0.35],   ...Pz
  [0.65, 0.32],   ...P4
  [0.2, 0.5],   ...T7
  [0.35, 0.32],   ...P3
  [0.37, 0.15],   ...O1
  [0.63, 0.15],   ...O2
  [0.67, 0.5],   ...C4
  [0.8, 0.5],   ...T8
  ...[0.08, 0.5],  ...A1
  [0.92, 0.5]   ...A2
];

colors = zeros(size(GI_avg2, 1), 3);
colors(GI_avg2 < 2500, :) = repmat([0, 0.5, 0], sum(GI_avg2 < 2500), 1); % Dark green
colors(GI_avg2 >= 2500 & GI_avg2 <= 5000, :) = repmat([0.56, 0.93, 0.56], sum(GI_avg2 >= 2500 & GI_avg2 <= 5000), 1); % Light green
colors(GI_avg2 > 5000, :) = repmat([1, 0, 0], sum(GI_avg2 > 5000), 1); % Red

% Plotting
pl = scatter(app.UIAxes2, Sensors(:, 1), Sensors(:, 2), [], colors, 'filled');
pl.SizeData = 200;
xlabel(app.UIAxes2, 'X');
ylabel(app.UIAxes2, 'Y');
title(app.UIAxes2, 'Sensor Locations');
xlim(app.UIAxes2, [0 1]);
ylim(app.UIAxes2, [0 1]);


