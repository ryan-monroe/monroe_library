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


function vacc_data(acc_len,iter_len,in_bp,out_bits,arch)



% %
% xBlock;
% FFTSize = 5+2+1;
% FFT_Direct_Size = 2;
% bram_latency = 2;
% bit_width = 18;
% coeff_bit_width = 18;
% out_bit_width = 18;
% shift = 1;

vec_count_linear = 2^FFT_Direct_Size;

half = vec_count_linear/2;
first_half = 1:(half);
second_half = (half+1):(vec_count_linear);

arch_v6 = strcmp(arch,'virtex_6');



vector_len = FFTSize-1-FFT_Direct_Size;

%I/O
iSync = xInport('sync');
oSync = xOutport('sync_out');

for(i=1:vec_count_linear)
    nameIn =  ['din'  num2str(i-1)];
    nameOut = ['dout' num2str(i-1)];
    iDataIn{i} = xInport(nameIn);
    oDataOut{i} = xOutport(nameOut);
end

if(shift==0)
    sScaleIn =   xConstVal(0,'Signed', 32,0,'const_scale_0');
elseif(shift==1)
    sScaleIn =   xConstVal(-1,'Signed', 32,0,'const_scale_0');
else
    sScaleIn = xInport('scale');
end

if(updateCoeffs==1)
    iWe=   xInport('coeff_we');
    iAddr= xInport('coeff_addr');
    iDin=  xInport('coeff_din');
else
    iWe=   {};
    iAddr= {};
    iDin=  {};
end

for(i=1:2:(half))
    sFirstDelay{i}   = xSignal;
    sFirstDelay{i+1} = xSignal;
    
    name = ['ddbf_' num2str((i+1)/2)];
    
    xlsub2_double_delay_bram_fast = xBlock(struct('source', 'monroe_library/double_delay_bram_fast', 'name', name), ...
        struct('delay_len', 2^(vector_len), ...
        'bram_latency', bram_latency));
    xlsub2_double_delay_bram_fast.bindPort({iDataIn{i}, iDataIn{i+1}}, ...
        {sFirstDelay{i}, sFirstDelay{i+1}});
    sFirstDelay{i} = xDelayr(sFirstDelay{i},bram_latency-1,['init_delay_', num2str((i))]);
    sFirstDelay{i+1} = xDelayr(sFirstDelay{i+1},bram_latency-1,['init_delay_', num2str((i+1))]);
    
end

for(i=(half+1):2:vec_count_linear)
    sFirstDelay{i}   = xSignal;
    sFirstDelay{i+1} = xSignal;
    sReorderSyncOut = xSignal;
    name = ['order_reverse_' num2str((i+1)/2)];
    
    xlsub2_order_rev = xBlock(struct('source', 'monroe_library/order_reverse_2in', 'name', name), ...
        struct('reorder_len', vector_len, ...
        'bram_latency', bram_latency));
    xlsub2_order_rev.bindPort({iSync, iDataIn{i}, iDataIn{i+1}}, ...
        {sReorderSyncOut, sFirstDelay{i}, sFirstDelay{i+1}});
    
    
end

sFirstCountOut = xSignal;
bCounter =  xBlock(struct('source', 'Counter', 'name', 'Counter'), ...
    struct('n_bits', vector_len, ...
    'start_count', 3, ...
    'rst', 'on', ...
    'explicit_period', 'off', ...
    'use_rpm', 'on'), ...
    {sReorderSyncOut}, ...
    {sFirstCountOut});

sZero = xConstVal(0, 'unsigned', vector_len, 0, 'zero_relational');

sSel = xSignal;
blockTemp = xBlock(struct('source', 'Relational', 'name', 'Relational'), ...
    {'latency', 1}, ...
    {sFirstCountOut, sZero}, ...
    {sSel});


%now make the muxes and addsubs
for(i=1:half)
    selTemp = xDelay(sSel, 1, ['selDelay' num2str(i)]);
    sAddSubSyncOut = xSignal;
    sMuxIn0 =sFirstDelay{vec_count_linear-i+1};
    sMuxOut{i} = xSignal;
    if(i==1) %then this is the first mux, and occasionally gets X[0], because X - X = 0
        sMuxIn1 =sFirstDelay{1};
    else
        sMuxIn1 = sFirstDelay{vec_count_linear-i+2};
    end
    blockMux = xBlock(struct('source', 'Mux', 'name', ['Mux_stg1_',num2str(i-1)]), ...
        struct('latency', 1), ...
        {selTemp, sMuxIn0, sMuxIn1}, ...
        {sMuxOut{i}});
    
    if(i==half)
        sAddSubSyncIn = sReorderSyncOut;
    else
        sAddSubSyncIn = xConstBool(0,['const_addsub_', num2str(i)]);
    end
    
    %     if(0)
    if(i~=1)
        sRegVals{i} = xSignal;
        sSelDelayed = xDelay(sSel, 1, ['delaySelAgain', num2str(i)]);
        blockName = ['Register_', num2str(i)];
        blockTemp = xBlock(struct('source', 'Register', 'name', blockName), ...
            {'en', 'on'}, ...
            {sFirstDelay{i}, sSelDelayed}, ...
            {sRegVals{i}});
        
        sRegMuxOut{i} = xSignal;
        blockMux = xBlock(struct('source', 'Mux', 'name', ['Mux_stg1_reg_',num2str(i-1)]), ...
            struct('latency', 1), ...
            {sSelDelayed, sFirstDelay{i}, sRegVals{i}}, ...
            {sRegMuxOut{i}});
        sFirstDelay{i}= sRegMuxOut{i};
    else
        sFirstDelay{i} = xDelayr(sFirstDelay{i},1, ['delay_firstMuxes' num2str(i-1)]);
    end
    sEven{i} = xSignal;
    sOdd{i} =  xSignal;
    
    blockSource = 'monroe_library/direct_unscr_addsub';
    if(arch_v6)
        blockSource = [blockSource '_v6'];
    end
    
    
    name = ['direct_unscr_addsub' num2str(i-1)];
    xlsub2_order_rev = xBlock(struct('source', blockSource, 'name', name), ...
        struct('in_bit_width', bit_width, 'out_bit_width', bit_width, 'downshift', 1, 'bin_pt', bit_width-1), ...
        {sFirstDelay{i}, sMuxOut{i}, sAddSubSyncIn}, ...
        {sEven{i}, sOdd{i}, sAddSubSyncOut});
end



%CC1
for(i=1:half)
    sEven_cc1_delay{i} = xDelay(sEven{i}, 2, ['delay_comp_conj_even_', num2str(i-1)]);
    sOdd_cc1_delay{i} = xDelay(sOdd{i}, 2, ['delay_comp_conj_odd_', num2str(i)]);
end

for(i=1:half)
    sOdd_cc1{i}=xSignal;
    sEven_cc1{i}=xSignal;
    blockSource = 'monroe_library/complex_conj_dual_z^-2';
    if(arch_v6)
        blockSource = [blockSource '_v6'];
    end
    
    name = ['complex_conj_1_' num2str((i+1)/2)];
    xlsub2_order_rev = xBlock(struct('source',blockSource, 'name', name), ...
        struct('input_bit_width', bit_width, 'input_bin_pt', bit_width-1), ...
        {sEven{i}, sOdd{i}}, ...
        {sEven_cc1{i}, sOdd_cc1{i}});
    
end

sEven_cc2 = sEven_cc1;
sOdd_cc2 = sOdd_cc1_delay;
sOdd_cc2_delay = sOdd_cc1;
sEven_cc2_delay = sEven_cc1_delay;


%cc2
% for(i=first_half)
%     sEven_cc2_delay{i} = xDelay(sEven_cc1_delay{i}, 4, ['even_cc2_delay', num2str(i-1)]);
%     sOdd_cc2_delay{i} =  xDelay(sOdd_cc1{i}, 4,  ['odd_cc2_delay',  num2str(i-1)]);
%
%     sEven_cc2{i} = xSignal;
%     sOdd_cc2{i} = xSignal;
%
%
%     name = ['complex_conj_2_' num2str((i))];
%         xlsub2_order_rev = xBlock(struct('source', 'monroe_library/complex_conj_dual_z^-2', 'name', name), ...
%         struct('input_bit_width', bit_width, 'input_bin_pt', bit_width-1), ...
%         {sEven_cc1_delay{i}, sOdd_cc1{i}}, ...
%         {sEven_cc2{i}, sOdd_cc2{i}});
% end



sSecondCountOut = xSignal;
bCounter =  xBlock(struct('source', 'Counter', 'name', 'Counter2'), ...
    struct('n_bits', vector_len, ...
    'start_count', 2^vector_len, ...
    'rst', 'on', ...
    'explicit_period', 'off', ...
    'use_rpm', 'on'), ...
    {sAddSubSyncOut}, ...
    {sSecondCountOut});

sZero = xConstVal(0, 'unsigned', vector_len, 0, 'zero_relational2');

sSel2 = xSignal;
blockTemp = xBlock(struct('source', 'Relational', 'name', 'Relational2'), ...
    {'latency', 1}, ...
    {sSecondCountOut, sZero}, ...
    {sSel2});


for(i=1:half)
    sCompConjArr{2*(i-1)+1} =   sEven_cc2{i};
    sCompConjArr{2*(i-1)+2} = sOdd_cc2{i};
    %
    %    sCompConjArr{2*(i-1)+1} =   sEven_cc2_delay{i};
    %    sCompConjArr{2*(i-1)+2} = sOdd_cc2_delay{i};
    
end

%delay bypass for X[0]
bypass_index = vec_count_linear/2+1;
sBypassOut=xSignal;
%sDataBypassIn = xSignal;
blockTemp = xBlock(struct('source', 'monroe_library/delay_bram_fast', 'name', 'dbf_bypass'), ...
    {'delay_len', 2^vector_len, 'bram_latency', bram_latency, 'memory_type', 'Block RAM', 'register_counter', 0}, ...
    {iDataIn{bypass_index}},{sBypassOut});
sBypassOut = xDelay(sBypassOut, 6, 'delay_post_bypass');



bypassDelayR = xSignal;
bypassDelayI = xSignal;

blockTemp = xBlock(struct('source', 'monroe_library/c_to_ri', 'name', 'bypass_c_to_ri_1'), ...
    {'n_bits', bit_width,'bin_pt', bit_width-1}, ...
    {sBypassOut}, ...
    {bypassDelayR,bypassDelayI});

bypassMuxInR = xSignal;
bypassMuxInI = xSignal;

cZeroVal = xConstVal(0,'signed', bit_width, bit_width-1,'bypass_const_1');
cZeroVal1 = xConstVal(0,'signed', bit_width, bit_width-1,'bypass_const_2');

blockTemp = xBlock(struct('source', 'monroe_library/ri_to_c', 'name', 'bypass_ri_to_c1'), ...
    {}, ...
    {bypassDelayR, cZeroVal}, ...
    {bypassMuxInR});

blockTemp = xBlock(struct('source', 'monroe_library/ri_to_c', 'name', 'bypass_ri_to_c2'), ...
    {}, ...
    {bypassDelayI, cZeroVal1}, ...
    {bypassMuxInI});



%mux bank for CC'ed array
for(i=1:vec_count_linear)
    selTemp = xDelay(sSel2, 1, ['sel2Delay' num2str(i)]);
    
    %sMuxIn0 =sFirstDelay{vec_count_linear-i};
    sMux2Out{i} = xSignal;
    if(i-vec_count_linear==0)
        sMuxIn1 = bypassMuxInI;
    elseif(vec_count_linear-i==1)
        sMuxIn1 = bypassMuxInR;
    else
        sMuxIn1 = sCompConjArr{i+2};
    end
    blockMux = xBlock(struct('source', 'Mux', 'name', ['Mux_stg2_', num2str(i)]), ...
        struct('latency', 2), ...
        {selTemp, sCompConjArr{i}, sMuxIn1}, ...
        {sMux2Out{i}});
end

sSyncCoeffIn =  xDelay(sAddSubSyncOut, 4, 'sync_delay1');
sSyncCoeffIn2 = xDelay(sAddSubSyncOut, 5, 'sync_delay2');

sSyncOut = xDelay(sSyncCoeffIn,4,'sync_delay_out');
oSync.bind(sSyncOut);


%%%%%%%%%%%%%%%%%%%%%%%%%%%
%okay, now coefficients and twiddles.  Then we're all done!

%coeff_array = zeros(vec_count_linear, 2^vector_len);
coeff_array = direct_unscr_coeff_calc(2^(FFTSize-1),2^(vector_len));

for(i=1:vec_count_linear)
    if(i<=half)
        outputIndex = i;
        blockNameE=['delay_even_ccMux_' num2str(i-1)];
        blockNameO=['delay_odd_ccMux_' num2str(i-1)];
        a_in = xDelay(sEven_cc2_delay{i},2,blockNameE);
        b_in = xDelay(sOdd_cc2_delay{i},2,blockNameO);
        %         a_in = sEven_cc2_delay{i};
        %         b_in = sOdd_cc2_delay{i};
    else
        outputIndex = vec_count_linear-i+half+1;
        index0=(i-half)*2-1;
        index1=(i-half)*2;
        
        a_in = sMux2Out{index0};
        b_in = sMux2Out{index1};
    end
    
    if(i<=(vec_count_linear/2))
        sCoeffSyncInAct = sSyncCoeffIn;
    else
        sCoeffSyncInAct = sSyncCoeffIn2;
    end
    sCoeffOut{i} = xSignal;
    if(updateCoeffs)
        sWe_this = xSliceBool(iWe,'upper',i-8, ['slice_coeff_we_' num2str(i-1)]);
    else
        sWe_this={};
    end
    
    
    if(coeffRange==1)
        coeffFracWid=coeff_bit_width-2;
    else
        coeffFracWid=coeff_bit_width-1;
    end
    
    blockName = strcat('coeff_gen',num2str(i-1));
    blockTemp = xBlock(struct('source', str2func('coeff_gen_dual_draw_v2'), 'name',blockName), {coeff_array(1:2^(coeff_step_rate):end,i), 'Block RAM', coeff_bit_width,coeffFracWid, coeff_step_rate , 0, 0, updateCoeffs});
    blockTemp.bindPort({sCoeffSyncInAct, sWe_this, iAddr, iDin}, {sCoeffOut{i}});
    
    blockSource = 'monroe_library/unscr_twid';
    if(shift~=2)
        blockSource = [blockSource '_noscale'];
        sScaleIn=[];
    end
    if(arch_v6)
        blockSource = [blockSource '_v6'];
    end
    
    
    sync_in = xConstBool(0,['const0_',num2str(i)]);
    sTempOut=xSignal;
    blockMux = xBlock(struct('source', blockSource, 'name', ['unscr_twid', num2str(outputIndex-1)]), ...
        struct(...
        'a_n_bits',bit_width,...
        'a_bin_pt', bit_width-1,...
        'b_n_bits', bit_width,...
        'b_bin_pt', bit_width-1,...
        'w_n_bits', coeff_bit_width,...
        'w_bin_pt', coeffFracWid,...
        'a_delay', 1, ...
        'apbw_delay', 0,...
        'out_n_bits', out_bit_width ,...
        'downshift_at_end', shift, ...
        'scale', shift, ...
        'stage', FFTSize), ...
        {a_in, b_in, sCoeffOut{i}, sync_in, sScaleIn}, ...
        {sTempOut , xSignal,  xSignal});
    oDataOut{outputIndex}.bind(sTempOut);
    
end