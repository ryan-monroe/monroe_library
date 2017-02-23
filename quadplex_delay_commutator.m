% Monroe_Library: mask script
% Author: Ryan Monroe

% Copyright 2007, 2005, by the California Institute of Technology.
% ALL RIGHTS RESERVED. United States Government Sponsorship
% acknowledged. Any commercial use must be negotiated with the Office
% of Technology Transfer at the California Institute of Technology.
% % 
% This software may be subject to U.S. export control laws. By
% accepting this software, the user agrees to comply with all
% applicable U.S. export laws and regulations. User has the
% responsibility to obtain export licenses, or other export authority
% as may be required before exporting such information to foreign
% countries or providing access to foreign persons.


function quadplex_delay_commutator(vectorLen, bram_latency, mux_latency, input_bit_width,muxsel_delay)
% 
% 
% xBlock;
% vectorLen=4;
% bram_latency=2;
% mux_latency=0;
% input_bit_width=18;



max_delay_fabric=32;
if(length(mux_latency)==1)
    mux_latency=ones(4,1)*mux_latency;
end
%% inports
iSync = xInport('sync');
in{1} = xInport('in0');
in{2} = xInport('in1');
in{3} = xInport('in2');
in{4} = xInport('in3');
iMuxSel = xInport('mux_sel');

%% outports
oSync = xOutport('sync_out');

out{1} = xOutport('out0');
out{2} = xOutport('out1');
out{3} = xOutport('out2');
out{4} = xOutport('out3');

%% diagram

delay_lens = [0 2^(vectorLen).*(1:3)]+muxsel_delay;
syncDelayLen=delay_lens(4)+mux_latency(end);

%% delay blocks
for i=1:4
    delays_in{i,1} = in{i};
    delays_in{i,2} = xSignal;
    delays_out{i,1} = xSignal;
    delays_out{i,2} = xSignal;
    if(i>1)
        if(delay_lens(i)>max_delay_fabric)
            blockName = ['multi_delay_bram_fast_quadplex_' num2str(delay_lens(i))];
            bMultiDelay =  xBlock(struct('source', @multi_delay_bram_fast_draw, 'name', blockName), ...
                {2,delay_lens(i),input_bit_width*2,0, ...
                'Unsigned',bram_latency,0}, ...
                delays_in(i,:), ...
                delays_out(i,:));
        else
            delays_out{i,1} = xDelayr(delays_in{i,1},delay_lens(i), ['delay_ddbf0_' num2str(i)]);
            delays_out{i,2} = xDelayr(delays_in{i,2},0, ['delay_ddbf1_' num2str(i)]);
            mux_latency(5-i)=mux_latency(5-i)+delay_lens(i);
        end
    else
        delays_out{i,1}.bind(delays_in{i,1});
        delays_out{i,2}.bind(delays_in{i,2});
        
    end
    
end

blockName = 'commutator';
blockTemp = xBlock(struct('source', 'monroe_library/radix4_commutator', 'name', blockName), ...
    struct('latencies', mux_latency,'counter_adjust_latency',muxsel_delay), ...
    [{iMuxSel}; delays_out(:,1)], ...
    delays_in(end:-1:1,2));

butterfly_data_in_reo = delays_out(end:-1:1,2);

for i=1:4
    out{i}.bind(butterfly_data_in_reo{i});
end

sSyncDelayOut = xSignal;
if(syncDelayLen >16)
    bSyncDelay = xBlock('monroe_library/sync_delay_fast', struct('delay_len', syncDelayLen), {iSync}, {sSyncDelayOut});
else
    xlsub2_sync_delay_fast = xBlock(struct('source', 'Delay', 'name', 'sync_delay'), ...
        struct('latency', syncDelayLen), ...
        {iSync}, ...
        {sSyncDelayOut});
end

oSync.bind(sSyncDelayOut);
