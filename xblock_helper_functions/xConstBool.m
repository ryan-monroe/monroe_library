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


function sOut = xConstBool(value, name)

if((value ~= 0) && (value ~= 1))
   throwError(strcat('value must be either 0 or 1; value = ' , num2str(value)));
end


sOut = xSignal;

bConstantBool = xBlock(struct('source', 'Constant', 'name', name), ...
    struct('arith_type', 'Boolean', 'const', value, 'explicit_period', 'on'), ...
    {}, {sOut});
