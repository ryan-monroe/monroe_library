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


function out = direct_unscr_coeff_calc(n, div, use_second_reorder)

% n = 128;
% div=32;
% use_second_reorder = 0;
clear coeff index1 index2 coeff_bram coeff_split;


coeff=exp(-1j*(0:(n-1))*pi/n)';
coeff_bram = zeros(n/div, div*2)';
for(i=1:(n/div))
    index1=1 + div*(i-1);
    index2 = index1+div-1;
    coeff_split(:,i) = coeff(index1:index2);    
    
    coeff_bram(:,i) = [imag(coeff_split(:,i))' real(coeff_split(:,i))']';
end

 end1= n/div/2+1;

if(~use_second_reorder)    
    coeff_bram = direct_unscr_coeff_reorder(n, div, coeff_bram);
end
out = coeff_bram;
% 
%  reals(1:32) =   coeff_bram(33:64, 1);
%  reals(33:64) =  coeff_bram(33:64, 2);
%  reals(65:96) =  coeff_bram(33:64, 3);
%  reals(97:128) = coeff_bram(33:64, 4);
% 
% imags(1:32) =   coeff_bram(1:32, 1);
% imags(33:64) =  coeff_bram(1:32, 2);
% imags(65:96) =  coeff_bram(1:32, 3);
% imags(97:128) = coeff_bram(1:32, 4);
% 
% close all;
% plot(reals); hold on; plot(imags, 'r');
% 
% 
% 
% 
% 








































