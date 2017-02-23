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


function sOut = xReinterpret(sIn, forceArithType, arithType, forceBinPt, binPt, name)


if(forceArithType == 1)
    forceArithType = 'on';
    
    
    signalTypeGood = (strcmpi(arithType, 'signed') || ...
        strcmpi(arithType, 'unsigned'));
    if(~signalTypeGood)
        throwError('The arith mode must be either ''Signed'', ''Unsigned''');
    end
else
    forceArithType = 'off';
    arithType = 'Signed';
end

if(forceBinPt == 1)
    forceBinPt = 'on';
    if((~isInt(binPt))|| binPt < 0)
        strError = strcat('The binal point must be a positive integer; binPt = ', num2str(binPt));
        throwError(strError);
    end
else
    forceBinPt = 'off';
end

arithType = proper(arithType);

sOut = xSignal;

blockTemp =     xBlock(struct('source', 'Reinterpret', 'name', name), ...
    struct('force_arith_type', forceArithType, 'arith_type', arithType, ...
    'force_bin_pt', forceBinPt, 'bin_pt', binPt), {sIn}, {sOut});



