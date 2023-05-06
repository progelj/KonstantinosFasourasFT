function v = make_buffer(A)
    %where A is data3
    idx = find(A == 255);
    
    Fc = A(idx+1);
    
    % Create a linear index vector that selects the desired elements
    linearIdx = bsxfun(@plus, idx.', 2:70);
    
    % Convert the linear index vector to a logical mask
    mask = ismember(1:numel(A), linearIdx(:));
    TempACC = A(mask);
    
    Msb = TempACC(1,1:3:end);
    Lsb2 = TempACC(1,2:3:end);
    Lsb1 = TempACC(1,3:3:end);
    Msb = (Msb/2).*2^14;
    Lsb2 = (Lsb2/2).*2^7;
    Lsb1 = Lsb1/2;
    TempC = Msb+Lsb2+Lsb1;
    TempC = TempC*2^3;
    %convertion to mVolt
    TempC = TempC*(5/3)*(1/2^32);

    % Extract every 23 elements and reshape them into a matrix
    buff = reshape(TempC, 23, []);

    % extract the remaining variables from data
    ImpCheck = A(idx+71);
    VoltageCheck = A(idx+72);
    Trig1 = A(idx+73);
    Trig2 = A(idx+74);
    
    %get impedences
    %Take the greater of the two differences
    GI = [max(abs(buff(:,1) - buff(:,3))/2,abs(buff(:,2) - buff(:,4))/2)];
    GI = GI * 265000000;
    
    v = buff;
    
end


