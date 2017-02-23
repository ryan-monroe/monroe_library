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


function quadplex_cplx_unscrambler_draw(FFTSize, bit_width, mux_latency, bram_latency,muxsel_delay)
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
% % arch='virtex_6';
% % 
% FFTSize=6;
% bit_width=18;
% mux_latency=0;
% bram_latency=2;
% xBlock;


max_delay_fabric=32;
if(length(mux_latency)==1)
    mux_latency=ones(4,1)*mux_latency;
end
%% inports
in{1} = xInport('in0');
in{2} = xInport('in1');
in{3} = xInport('in2');
in{4} = xInport('in3');

iSync = xInport('sync');


%% outports
out{1} = xOutport('out0');
out{2} = xOutport('out1');
out{3} = xOutport('out2');
out{4} = xOutport('out3');

oSync = xOutport('sync_out');

%% diagram

% delay_lens = 2^(FFTSize-2*FFTStage).*(1:3);
vectorLen=FFTSize-2;


sCrammed=xCram(in,'cram');

sRevved = xSignal;
sRevSyncOut=xSignal;
blockName = ['bit_rev_radix4'];
bRev =  xBlock(struct('source', @singleBitReverseRadix4, 'name', blockName), ...
        {vectorLen}, ...
        {iSync, sCrammed}, ...
        {sRevSyncOut, sRevved});

    
for i=1:4
    sUnCram{i}=xSignal;
end

bUnCram = xBlock(struct('source', @uncram_draw, 'name', 'uncram'), ...
        {4,bit_width*2,0,'unsigned'}, ...
        {sRevved}, ...
        sUnCram);
    
%% delay commutator (plus counter)

sCountOut = xSignal;
xlsub2_Counter = xBlock(struct('source', 'Counter', 'name', 'Counter'), ...
                        struct('n_bits', FFTSize, ...
                               'rst', 'on', 'start_count',1,...
                               'explicit_period', 'off', ...
                               'use_rpm', 'on'), ...
                        {sRevSyncOut}, ...
                        {sCountOut});
                    
sDC_sel= xSlice(sCountOut,2,'upper',0,'sliceDC');



sDCsyncOut=xSignal;
% for i=1:4
%     sDC_out{i}=xSignal;
% end

blockName = ['delay_commutator'];
bDC =  xBlock(struct('source', @quadplex_delay_commutator, 'name', blockName), ...
        {vectorLen,bram_latency,mux_latency,bit_width,muxsel_delay}, ...
        [{sRevSyncOut} sUnCram {sDC_sel}], ...
        [{oSync} out]);

