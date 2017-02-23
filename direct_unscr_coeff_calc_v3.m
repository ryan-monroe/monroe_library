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


function out = direct_unscr_coeff_calc(n, div, which_result)

% n = 128;
% div=32;
% use_second_reorder = 0;
clear coeff index1 index2 coeff_bram coeff_split;


coeff=exp(-1j*(0:(n-1))*pi/n)';

if(which_result==0)
    out=coeff;
    return;
end

coeff_bram = direct_unscr_coeff_partition(coeff,n,div);

if(which_result==1)
    out=coeff_bram;
    return;
end
out = direct_unscr_coeff_reorder(n, div, coeff_bram);








































