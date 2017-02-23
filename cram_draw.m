% Monroe_Library: mask script
% Author: Ryan Monroe

% Copyright 2007, 2005, by the California Institute of Technology. 
% ALL RIGHTS RESERVED. United States Government Sponsorship
% acknowledged. Any commercial use must be negotiated with the Office
% of Technology Transfer at the California Institute of Technology.

% This software may be subject to U.S. export control laws. By
% accepting this software, the user agrees to comply with all
% applicable U.S. export laws and regulations. User has the
% responsibility to obtain export licenses, or other export authority
% as may be required before exporting such information to foreign
% countries or providing access to foreign persons. 


function cram_draw(numInputs)

% xBlock;
% numInputs=5;
% pathToBlock = 'path:cram';

for(i= 1:numInputs)
    iDataIn{i} = xInport(strcat('in', num2str(i-1)));
end

oOut = xOutport('out');

if(numInputs > 1)
    sConcatIn = {xSignal, xSignal};
    for(i = 1:numInputs)
        blockName = strcat('reinterpret_', num2str(i)); 
        sConcatIn{i} = xReinterpret(iDataIn{i}, 1, 'Unsigned', 1, 0, blockName);
    end
    
    sConcatOut = xConcat(sConcatIn, 'concat');
    oOut.bind(sConcatOut);
else
    blockName = 'reinterpret';
        sReinterpretOut = xReinterpret(iDataIn{i}, 1, 'Unsigned', 1, 0, blockName);
        oOut.bind(sReinterpretOut);
end