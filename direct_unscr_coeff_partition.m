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


function coeff_bram = direct_unscr_coeff_partition(coeff,n,div)
coeff_bram = zeros(n/div, div*2)';
for(i=1:(n/div))
    index1=1 + div*(i-1);
    index2 = index1+div-1;
    coeff_split(:,i) = coeff(index1:index2);    
    
    coeff_bram(:,i) = [imag(coeff_split(:,i))' real(coeff_split(:,i))']';
end
