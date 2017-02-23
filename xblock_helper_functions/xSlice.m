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


function sOut = xSlice(sIn, bitWidth, sliceMode, dist_from_endpoint, name)


if(strcmpi(sliceMode, 'lower'))
    sliceMode = 'Lower Bit Location + Width';
    sliceBase = 'LSB of Input';
    if(dist_from_endpoint < 0)
        strError = strcat('When sliceMode is ''lower'', dist_from_endpoint must be non-negative; dist_from_endpoint = ', dist_from_endpoint);
        throwError(strError);
    end
elseif(strcmpi(sliceMode, 'upper'))
    sliceBase = 'MSB of Input';
    sliceMode = 'Upper Bit Location + Width';
    if(dist_from_endpoint > 0)
        strError = strcat('When sliceMode is ''upper'', dist_from_endpoint must be non-positive; dist_from_endpoint = ', dist_from_endpoint);
        throwError(strError);
    end
else
    strError = strcat('sliceMode must be either ''upper'' or ''lower''; sliceMode = ', sliceMode);
    throwError(strError);
end



sOut = xSignal;

bSlice = xBlock(struct('source', 'Slice', 'name', name), struct( ...
    'nbits', bitWidth, 'boolean_output','off', 'mode', sliceMode, ...
    'base1', sliceBase, 'base0', sliceBase, 'bit1', dist_from_endpoint, ...
    'bit0', dist_from_endpoint), ...
    {sIn}, {sOut});