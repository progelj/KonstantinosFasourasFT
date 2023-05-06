%initialize vectors
%se = zeros(23,30);
K = zeros(23,100);
M = zeros(23, 10);
y2 = zeros(23,10);
y = zeros(23,10);
ts = zeros(23,3);
%access port and manipulate t get the start frame
s = serialport("COM3", 3000000, "Timeout", 10);
data = read(s, 100, "uint8");
ind = find(data == 255, 1);
rem = 100-ind;
gr = 75-rem-1;
if(gr<0)
    gr = 75+gr;
    %check and see if need to +1
end
getRem = read(s,gr,"uint8");
%start

NWT = read(s,750,"uint8");

mb = make_buffer(NWT);
%shift it every time we get new frame of 750 elements
%se(:,1:10) = mb;
%se = circshift(se, [0,-10]);


for i=1:10
    if(i==1)
        ts = [mb(:,i),mb(:,i+1)];
        y = filter([0.85,0,0.85],[1,0,0.7],ts);
        y2 = filter([0.8,0.8],[1,0.6],y);
        M(:,1)=y2(:,1);
        M = circshift(M, [0,-1]);
    elseif(i>=2 && i<=9)
        ts = [mb(:,i-1),mb(:,i),mb(:,i+1)];
        y = filter([0.85,0,0.85],[1,0,0.7],ts);
        y2 = filter([0.8,0.8],[1,0.6],y);
        M(:,1)=y2(:,2);
        M = circshift(M, [0,-1]);
    else
        ts = [mb(:,i-1),mb(:,i)];
        y = filter([0.85,0,0.85],[1,0,0.7],ts);
        y2 = filter([0.8,0.8],[1,0.6],y);
        M(:,1)=y2(:,2);
        M = circshift(M, [0,-1]);   
    end

end

K(:,1:10)=M(:,:);
K = circshift(K, [0,-10]);
toc
%filters
%y = filter([0.85,0,0.85],[1,0,0.7],se);
%y2 = filter([0.8,0.8],[1,0.6],y);
%extract the middle one
%M(:,1)=y2(:,2);
%M = circshift(M, [0,-1]);
%final filter
toc
y_filtered = highpass(K, 0.5, 500,Steepness=0.5,StopbandAttenuation=30);

%,Steepness=0.5,StopbandAttenuation=30



%---------------------ploting
b = y_filtered(1:20,1:80);
variables={'f7','fp1','fp2','f8','f3','fz','f4','c3','cz','p8','p7','pz','p4','t3','p3','o1','o2','c4','t4','a2'};
t = tiledlayout(20,1);
axes = gobjects(20,1);
for i = 1:1:size(b, 1)    %buff where y2
    ax = nexttile;
    plot(ax, b(i,1:end))
    set(ax, 'xcolor', 'w', 'ycolor', 'w', 'xtick', [], 'ytick', [])
    ax.YLabel.String = variables(i);
    ax.YLabel.Color = 'black';
    ax;
end
set(gcf, 'color', 'white');
set(gcf, 'InvertHardCopy', 'off');
xlabel('t','Color','black');



