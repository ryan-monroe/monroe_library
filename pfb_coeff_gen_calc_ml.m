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


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%                                                                             %
%   Center for Astronomy Signal Processing and Electronics Research           %
%   http://seti.ssl.berkeley.edu/casper/                                      %
%   Copyright (C) 2008 Terry Filiba                                           %
%                                                                             %
%   This program is free software; you can redistribute it and/or modify      %
%   it under the terms of the GNU General Public License as published by      %
%   the Free Software Foundation; either version 2 of the License, or         %
%   (at your option) any later version.                                       %
%                                                                             %
%   This program is distributed in the hope that it will be useful,           %
%   but WITHOUT ANY WARRANTY; without even the implied warranty of            %
%   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the             %
%   GNU General Public License for more details.                              %
%                                                                             %
%   You should have received a copy of the GNU General Public License along   %
%   with this program; if not, write to the Free Software Foundation, Inc.,   %
%   51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.               %
%                                                                             %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function [coeff_vector,max_gain,total_coeffs, windowval, sync] = pfb_coeff_gen_calc_ml(PFBSize,TotalTaps,WindowType,n_inputs,nput,fwidth,a)
% Calculate the bram coeffiecients for the pfb_coeff_gen block
%
% coeff_vector = pfb_coeff_gen_calc(PFBSize,n_inputs,a)
%
% Valid varnames for this block are:
% PFBSize = Size of the FFT (2^FFTSize points).
% TotalTaps = Total number of taps in the PFB
% WindowType = The type of windowing function to use.
% n_inputs = Number of parallel input streams
% nput = Which input this is (of the n_inputs parallel).
% fwidth = The scaling of the bin width (1 is normal).
% a = Index of this rom

% Set coefficient vector
alltaps = TotalTaps*2^PFBSize;
if(strcmp(WindowType,'blackman'))
    windowval=blackman(alltaps,'symmetric').';
elseif(strcmp(WindowType,'hamming'))
    windowval=hamming(alltaps,'symmetric').';
else
    windowval = transpose(window(WindowType, alltaps));
end
sync = sinc(fwidth*([(0:alltaps-1)+0.5]/(2^PFBSize)-TotalTaps/2));
total_coeffs = windowval .* sync;
for i=1:alltaps/2^n_inputs,
    buf(i)=total_coeffs((i-1)*2^n_inputs + nput + 1);
end
coeff_vector = buf((a-1)*2^(PFBSize-n_inputs)+1 : a*2^(PFBSize-n_inputs));

%now, find the maximum output gain:
for(i=0:(TotalTaps-1))
    ind1=(2^PFBSize)*i+1;
    ind2=ind1+2^PFBSize-1;
    coeff_frame(:,i+1) = total_coeffs(ind1:ind2);
end

max_gain = max(sum(abs(coeff_frame),2));
coeff_vector = (coeff_vector/max_gain);
1+1;
% coeff_vector = abs(coeff_vector);
