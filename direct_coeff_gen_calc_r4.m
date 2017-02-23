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


function ActualCoeffs = direct_coeff_gen_calc_r4(FFTSize, FFTStage, LargerFFTSize, StartStage, tap_in_stage)

% FFTSize = 4;
% FFTStage = 4;
% LargerFFTSize = 14;
% StartStage = 11;
% tap_in_stage = 2;



stage=FFTStage;
i= tap_in_stage; %zero to (2^FFTSize) -1
redundancy = 2^(LargerFFTSize - FFTSize);

r=0:redundancy-1;
n = bit_reverse(r, LargerFFTSize - FFTSize);
Coeffs = floor((i+n*2^(FFTSize-1))/2^(LargerFFTSize-(StartStage+stage-1)));
br_indices = bit_rev(Coeffs, LargerFFTSize-1);
br_indices = -2*pi*1j*br_indices/2^LargerFFTSize;
ActualCoeffs = exp(br_indices);