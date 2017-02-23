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


function block_nor_draw(bits, logical_function)


%% inports
iIn = xInport('in');
%% outports
oNor = xOutport('out');
%% diagram

ind=1;
for i=bits
    signalsNored{ind}=xSlice(iIn,1,'lower',i,['slice_' num2str(i)]);
    ind=ind+1;
end
if(length(signalsNored)>1)
    blockTemp=xBlock('Logical',{'logical_function',logical_function,'inputs',length(bits),'latency',0},signalsNored,{oNor});
else
    passthru= strcmp(logical_function,'AND') || strcmp(logical_function,'OR') || strcmp(logical_function,'XOR');
    if(passthru)
        oNor.bind(signalsNored{1});
    else
        blockTemp = xBlock('Inverter',{'latency',0}, signalsNored,{oNor});
    end
end
end

