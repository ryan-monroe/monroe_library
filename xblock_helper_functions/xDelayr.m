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


function sOut = xDelayr(sIn,latency, name)


if(~isInt(latency))
    strError = strcat('error: delay latency must be an integer; latency= ', num2str(latency));
    throwError(strError);
end
if(latency < 0)
    strError = strcat('error: delay latency must be greater than 0; latency= ', num2str(latency));
    throwError(strError);
elseif(latency > 0)
    sOut = xSignal;
    
    bDelay = xBlock(struct('source', 'Delay', 'name', name), ...
        struct('latency', latency, 'reg_retiming', 'on'), ...
        {sIn}, ...
        {sOut});
    
else
    sOut = sIn;
end