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


function bulk_bit_select_draw(numInputs, width_in, width_out)
% xBlock;
% 
% numInputs = 4;
% width_in=18;
% width_out=8;
% pathToBlock = 'path:bulk_delay_draw';

shiftIn=  xInport('shift_in');

for(i = 1:numInputs)
   sIn{i} = xInport(strcat('in', num2str(i)));
   sOut{i} = xOutport(strcat('out', num2str(i)));
   sR{i}=xSignal;
   sI{i}=xSignal;
   
   sR_shifted{i}=xSignal;
   sI_shifted{i}=xSignal;
   
   
    stri=num2str(i);
   name_c2ri=['c2ri_' stri];
       c2ri = xBlock(struct('source', 'monroe_library/c_to_ri', 'name', name_c2ri), ...
        struct('n_bits', width_in,'bin_pt', 0), ...
        sIn(i), ...
        [sR(i), sI(i)]);

    name_shiftR=['dsp48e1_variable_shift_r_' stri];
       bShiftR = xBlock(struct('source', 'monroe_library/dsp48e1_variable_shift_v3', 'name', name_shiftR), ...
        struct('data_n_bits', width_in, 'out_n_bits' ,  width_out), ...
        [sR(i), {shiftIn}], ...
        sR_shifted(i));

    name_shiftI=['dsp48e1_variable_shift_i_' stri];
       bShiftI = xBlock(struct('source', 'monroe_library/dsp48e1_variable_shift_v3', 'name', name_shiftI), ...
        struct('data_n_bits', width_in, 'out_n_bits' ,  width_out), ...
        [sI(i), {shiftIn}], ...
        sI_shifted(i));

    name_cram=['cram_' stri];
    sOut_temp=xCram([sR_shifted(i), sI_shifted(i)], name_cram);
    
    sOut{i}.bind(sOut_temp);
end