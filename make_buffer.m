function v = make_buffer(A)
    idx = find(A == 255);
    
    linearIdx = bsxfun(@plus, idx.', 2:70);
    mask = ismember(1:numel(A), linearIdx(:));

    TempACC = A(mask);
    Msb = TempACC(1,1:3:end);
    converted_indices = false(size(Msb));
    for i = 1:length(Msb)
        if Msb(i) >= 128 && Msb(i) <= 255
            Msb(i) = - (255 - Msb(i) + 1); % 2's complement
            converted_indices(i) = true; % Mark this index as converted
        end
    end
    Lsb2 = TempACC(1,2:3:end);
    Lsb2(converted_indices) = - (255 - Lsb2(converted_indices) + 1); % 2's complement
    Lsb1 = TempACC(1,3:3:end);
    Lsb1(converted_indices) = - (255 - Lsb1(converted_indices) + 1); % 2's complement
    Msb = (Msb/2).*2^14;
    Lsb2 = (Lsb2/2).*2^7;
    Lsb1 = (Lsb1/2); 
    TempC = Msb+Lsb2+Lsb1;
    TempC = TempC*2^3;
    TempC = TempC*(5/3)*(1/2^32);

    buff = reshape(TempC, 23, []);
    
    v = buff;
    
end


