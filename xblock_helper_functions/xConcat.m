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


function sOut = xConcat(sIn,name)

% block: fft_stage_n_improved/fft_stage_6/delay_end
if(iscell(sIn) ~= 1)
    throwError('error: must be cell array');
end

[vertSize, concatSize] = size(sIn);
if(vertSize ~= 1)
    throwError('error: must be 1-by-N sized cell array');
end


if(concatSize == 1)
    sOut = sIn;
else
    sOut = xSignal;
    
    bConcat = xBlock(struct('source', 'Concat', 'name', name), ...
        struct('num_inputs', concatSize), ...
        sIn, {sOut});
end