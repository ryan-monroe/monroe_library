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


function quadplex_stage_n_draw(FFTSize, FFTStage, input_bit_width, coeff_bit_width, output_bit_width, bram_latency, shift, mux_latency,arch)
%
% xBlock;
% FFTSize=6;
% FFTStage=2;
% input_bit_width=18;
% coeff_bit_width=18;
% output_bit_width=18;
%
% bram_latency=2;
% shift=1;
% delay_arr= [0,0,0];
% mux_latency=0;
% arch='virtex_6';
%


max_delay_fabric=16;
if(length(mux_latency)==1)
    mux_latency=ones(4,1)*mux_latency;
end
%% inports
in{1} = xInport('a');
in{2} = xInport('b');
in{3} = xInport('c');
in{4} = xInport('d');

iSync = xInport('sync');

if(FFTStage > 1)
    iCoeff = xInport('coeff');
    for i=1:3
        sCoeffSlice{i} = xSignal;
    end
    blockName = 'coeff_uncram';
    bMultiDelay =  xBlock(struct('source', @uncram_draw, 'name', blockName), ...
        {3,2*coeff_bit_width,0,'unsigned'}, ...
        {iCoeff}, ...
        sCoeffSlice);
else
    sCoeff1 = xConstVal(1, 'signed', coeff_bit_width, coeff_bit_width-2, 'const1');
    sCoeff0 = xConstVal(0, 'signed', coeff_bit_width, coeff_bit_width-2, 'const0');
    sCoeff_cram = xCram({sCoeff1 sCoeff0}, 'cram_coeff');
    for i=1:3
        sCoeffSlice{i} = sCoeff_cram;
    end
end
iMuxSel = xInport('mux_sel');
iScale = xInport('scale');

%% outports
out{1} = xOutport('w');
out{2} = xOutport('x');
out{3} = xOutport('y');
out{4} = xOutport('z');

oSync = xOutport('sync_out');

%% diagram

% delay_lens = 2^(FFTSize-2*FFTStage).*(1:3);
vectorLen=FFTSize-2*FFTStage;

%% delay blocks

sDCsyncOut=xSignal;
for i=1:4
    butterfly_data_in_reo{i}=xSignal;
end

blockName = ['delay_commutator'];
bDC =  xBlock(struct('source', @quadplex_delay_commutator, 'name', blockName), ...
    {vectorLen,bram_latency,mux_latency,input_bit_width}, ...
    [{iSync} in {iMuxSel}], ...
    [{sDCsyncOut} butterfly_data_in_reo]);



butterfly_in = [{sDCsyncOut}, butterfly_data_in_reo, sCoeffSlice];
if(FFTStage==1)
    
    blockName = 'butterfly_radix4_dumb';
    blockTemp = xBlock(struct('source', 'monroe_library/butterfly_radix4_lw', 'name', blockName), ...
        struct('data_width', input_bit_width, 'data_bp', input_bit_width-1, 'coeff_width', coeff_bit_width, 'coeff_bp', coeff_bit_width-2, 'out_bits', output_bit_width));
    blockTemp.bindPort(butterfly_in(1:5),[{oSync} out]);
else
    
    blockName = 'butterfly_radix4_dumb';
    blockTemp = xBlock(struct('source', 'monroe_library/butterfly_radix4_dumb_rev3', 'name', blockName), ...
        struct('data_width', input_bit_width, 'data_bp', input_bit_width-1, 'coeff_width', coeff_bit_width, 'coeff_bp', coeff_bit_width-2, 'out_bits', output_bit_width));
    blockTemp.bindPort(butterfly_in,[{oSync} out]);
end
% blockTemp.bindPort([butterfly_in], ...
%     [{oSync} out]);

