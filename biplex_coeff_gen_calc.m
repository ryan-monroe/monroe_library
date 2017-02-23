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


function ActualCoeffs = biplex_coeff_gen_calc(FFTSize, FFTStage)
Coeffs = 0:2^(FFTStage-1)-1;

% Compute the complex, bit-reversed values of the twiddle factors
%br_indices = Coeffs; %bit_rev(Coeffs, FFTSize-1);
br_indices = bit_rev(Coeffs, FFTSize-1);
br_indices = -2*pi*1j*br_indices/2^FFTSize;
ActualCoeffs = exp(br_indices);
%ActualCoeffsStr = 'exp(-2*pi*1j*(bit_rev(Coeffs, FFTSize-1))/2^FFTSize)';