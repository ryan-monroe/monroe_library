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


function bit_reverse_draw(nBits)
%bit reverser

% 
% xBlock;
% nBits=5;
% pathToBlock = 'path:bit_reverse';

% if (exist('calledFromInit') == 0) % then we are calling this from another xBlock drawer, and the variables were passed by struct.  This allows us to use the xBlocks caching feature.
%     %it is necessary because xBlocks dosen't like you calling functions
%     %with arguments while drawing another xBlocks object.  The workaround
%     %is to put all your arguments in a global variable and just set them
%     %immeadiately before calling the argument.  By making this check, we
%     %pull the variables directly from the argument list, if we are calling
%     %this via an init command (thus fufilling the caching prerequsites),
%     %and from a struct if calling from within an xBlocks function (thus
%     %fufilling the function call requirements)
%     nBits=drawing_parameters.nBits;
% end


iIn = xInport('in');
oOut = xOutport('out');


for(i= 1:nBits)
    sSlices{nBits-i+1} = xSignal;
    
    blockName = strcat('slice', num2str(i));
    sSlices{nBits-i+1} = xSliceBool(iIn,'upper', -1*(i-1), blockName);
    %blockTemp = xBlock('Slice', struct('nbits', 1, 'boolean_output','off', 'mode', 'Lower Bit Location + Width', 'base1', 'MSB of Input', 'base0', 'MSB of Input', 'bit1', -1*(i-1), 'bit0', -1*(i-1)), {iIn}, {sSlices{nBits-i+1}});
end

sOut = xConcat(sSlices, 'concat');
oOut.bind(sOut);