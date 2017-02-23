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


function sOut = xBulkDelayr(sIn, numInputs, delay_arr, name)

if(~isInt([numInputs, delay_arr]))
    throwError('the number of inputs and delay array must both be integers.');
end

if(numInputs<1)
    strError = strcat('the number of inputs and delay array must both be integers; numInputs = ',num2str(numInputs));
    throwError(strError);
end


if(length(delay_arr) == 1)
    delay_arr = delay_arr * ones(1,numInputs);
elseif(length(delay_arr) ~= numInputs)
    throwError('delay length must be either an integer or an array numInputs long');
end

for(i = 1:numInputs)
    sOut{i} = xSignal;
end

bBulkDelay = xBlock(struct('source',str2func('bulk_delayr_draw'), ...
    'name', name),{numInputs, delay_arr});
bBulkDelay.bindPort(sIn, sOut);
