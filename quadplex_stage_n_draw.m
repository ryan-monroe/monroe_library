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
% FFTStage=1;
% input_bit_width=18;
% coeff_bit_width=18;
% output_bit_width=18;

% bram_latency=2;
% shift=1;
% delay_arr= [0,0,0];
% mux_latency=0;



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

delay_lens = 2^(FFTSize-2*FFTStage).*(1:3);
syncDelayLen=delay_lens(3);
delays_bram = delay_lens<=max_delay_fabric;

%% delay blocks
for i=1:4
    delays_in{i,1} = in{i};
    delays_in{i,2} = xSignal;
    delays_out{i,1} = xSignal;
    delays_out{i,2} = xSignal;
    if(i>1)
        if(delay_lens(i-1)>max_delay_fabric)
            blockName = ['multi_delay_bram_fast_quadplex_' num2str(delay_lens(i-1))];
            bMultiDelay =  xBlock(struct('source', @multi_delay_bram_fast_draw, 'name', blockName), ...
                {2,delay_lens(i-1),input_bit_width*2,0, ...
                'Unsigned',bram_latency,0}, ...
                delays_in(i,:), ...
                delays_out(i,:));
        else
            delays_out{i,1} = xDelayr(delays_in{i,1},delay_lens(i-1), ['delay_ddbf0_' num2str(i)]);
            delays_out{i,2} = xDelayr(delays_in{i,2},0, ['delay_ddbf1_' num2str(i)]);
            mux_latency(5-i)=mux_latency(5-i)+delay_lens(i-1);
        end
    else
        delays_out{i,1}.bind(delays_in{i,1});
        delays_out{i,2}.bind(delays_in{i,2});
        
    end
    
end

blockName = 'commutator';
blockTemp = xBlock(struct('source', 'monroe_library/radix4_commutator', 'name', blockName), ...
    struct('latencies', mux_latency), ...
    [{iMuxSel}; delays_out(:,1)], ...
    delays_in(end:-1:1,2));

butterfly_data_in_reo = delays_out(end:-1:1,2);


sSyncDelayOut = xSignal;
if(syncDelayLen >16)
    bSyncDelay = xBlock('monroe_library/sync_delay_fast', struct('delay_len', syncDelayLen), {iSync}, {sSyncDelayOut});
else
    xlsub2_sync_delay_fast = xBlock(struct('source', 'Delay', 'name', 'sync_delay'), ...
        struct('latency', syncDelayLen), ...
        {iSync}, ...
        {sSyncDelayOut});
end

butterfly_in = {sSyncDelayOut; butterfly_data_in_reo{1}; butterfly_data_in_reo{2}; sCoeffSlice{1}; butterfly_data_in_reo{3}; sCoeffSlice{2}; butterfly_data_in_reo{4}; sCoeffSlice{3}};

blockName = 'butterfly_radix4_dumb';
blockTemp = xBlock(struct('source', 'monroe_library/butterfly_radix4_dumb', 'name', blockName), ...
    struct('data_width', input_bit_width, 'data_bp', input_bit_width-1, 'coeff_width', coeff_bit_width, 'coeff_bp', coeff_bit_width-2, 'out_bits', output_bit_width));
% blockTemp.bindPort([butterfly_in], ...
%     [{oSync} out]);

blockTemp.bindPort(butterfly_in,[{oSync} out]);