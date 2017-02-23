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


function fft_direct_stage_draw(FFTSize, FFTStage, input_bit_width, coeff_bit_width, output_bit_width, total_fft_stage,scale,arch,this_stage_hires)


% xBlock;
%
% FFTSize = 3;
% FFTStage = 1;
% input_bit_width = 18;
% coeff_bit_width = 18;
% output_bit_width =  18;
% shift = 1;
% pathToBlock = 'path:fft_direct_stage_draw';

% iSync = xInport('sync_arr');
% oSync = xOutport('sync_out_arr');






if((~isInt([FFTSize, FFTStage, input_bit_width, coeff_bit_width, output_bit_width])))
    strError = 'every single input parameter must be an integer';
    throwError(strError);
elseif(FFTStage > FFTSize)
    throwError('FFTStage must be < FFTSize');
elseif(input_bit_width <0)
    strError = strcat('The input bit width must be positive; input_bit_width = ', num2str(input_bit_width));
    throwError(strError);
elseif(coeff_bit_width <0)
    strError = strcat('The coefficient bit width must be positive; coeff_bit_width = ', num2str(coeff_bit_width));
    throwError(strError);
elseif(coeff_bit_width >18 )
    strError = strcat('The coefficient bit width must be no greater than 18; coeff_bit_width = ', num2str(coeff_bit_width));
    throwError(strError);
elseif(output_bit_width <0)
    strError = strcat('The output bit width must be positive; output_bit_width = ', num2str(output_bit_width));
    throwError(strError);
end



arch_v6 = strcmp(arch,'virtex_6');

sShift = xInport('scale_in');

if(scale~=2)
    blockSource = 'monroe_library/twiddle_cheap_noscale';
    sShift=[];
else
    blockSource = 'monroe_library/twiddle_cheap';
end


if(arch_v6)
    blockSource = [blockSource '_v6'];
end

if(this_stage_hires)
    blockSource = [blockSource '_hires'];
end

for(i = 1:(2^(FFTSize-1)))
    a_in{i} = xInport(strcat('in', num2str(i-1), '_A'));
    b_in{i} = xInport(strcat('in', num2str(i-1), '_B'));
    
    sCoeff{i} = xSignal;
    %    sSync{i} = xSignal;
    
    oApBW{i} = xOutport(strcat('ApBW_', num2str(i-1)));
    oAmBW{i} = xOutport(strcat('AmBW_', num2str(i-1)));
    
end
iCoeff = xInport('coeff_arr');


bUnCramCoeff= xBlock(struct('source', str2func('uncram_draw'), 'name', 'uncram_coeff'), ...
    {2^(FFTSize-1), coeff_bit_width*2, 0, 'Unsigned'}, ...
    {iCoeff},sCoeff);

% bUnCramSync= xBlock(struct('source', str2func('uncram_draw'), 'name', 'uncram_sync'), ...
%     {2^(FFTSize-1), 1, 0, 'Unsigned'}, ...
%     {iSync},sSync);
sSync = xConstBool(0,'const_sync');

for(i = 1:(2^(FFTSize-1)))
    sSyncOut{i} = xSignal;
    
    bTwiddleCheap = xBlock(struct('source', blockSource, 'name', strcat('twiddle_', num2str(FFTStage), 'x', num2str(i-1))), ...
        struct('a_n_bits',input_bit_width, 'a_bin_pt', input_bit_width-1, ...
        'b_n_bits', input_bit_width, 'b_bin_pt', input_bit_width-1, ...
        'w_n_bits', coeff_bit_width, 'w_bin_pt', coeff_bit_width-2, 'a_delay', ...
        0, 'apbw_delay', 0, 'out_n_bits', output_bit_width, 'stage', total_fft_stage,'scale', scale), ...
        {a_in{i}, b_in{i},  sCoeff{i}, sSync, sShift}, ...
        {oApBW{i}, oAmBW{i}});
end

% sConcatOut = xConcat(sSyncOut);
% oSync.bind(sConcatOut);
