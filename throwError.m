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


function throwError(errorMsg)

%strError = strcat('ERROR: ', errorMsg, char(10), char(13), ';  <error in: ', pathToBlock, ' >');
strError = strcat('ERROR: ', errorMsg, char(10), char(13));

disp(strError);
error(strError);
