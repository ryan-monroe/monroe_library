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


function fft_wideband_real_draw_ml_v6(FFTSize  ,n_sim_inputs  ,input_bit_width  ,coeff_bit_width ,inter_stage_bit_width ...
    ,output_bit_width ,register_coeffs_biplex  ,register_coeffs_direct ,delay_between_biplex_direct ,delay_output  ...
    ,inter_stage_delays_direct  ,shift_array  ,super_unscr  ,coeff_group_arr_in ,max_distro_size_coeff  ...
    ,max_distro_size_delay ,biplex_delay_mid  ,biplex_delay_end ,biplex_mux_latency  ...
    ,biplex_bram_latency_fft ,biplex_bram_latency_unscr  ,unscr_din_latency, ...
    direct_coeff_step_rate,updateCoeffs, coeffRange,arch)
%  xBlock;
% 
% FFTSize = 14;
% n_sim_inputs = 3;
% input_bit_width = 18;
% coeff_bit_width = 18; %arr
% inter_stage_bit_width = 18; %arr
% output_bit_width = 18;
% register_coeffs_biplex = 0;
% register_coeffs_direct = 0;
% delay_between_biplex_direct = 0;
% delay_output = 0;
% 
% inter_stage_delays_direct = 0;
% shift_array = 1;%arr
% super_unscr = 1;%hardcode (for now)
% coeff_group_arr_in = [1,1;1,2];
% max_distro_size_coeff = 4;
% max_distro_size_delay = 4;
% biplex_delay_mid = 0;
% biplex_delay_end = 0;
% biplex_mux_latency = 0;
% biplex_bram_latency_fft = 3;
% biplex_bram_latency_unscr = 3;
% unscr_din_latency = 0;
% direct_coeff_step_rate=0;
% updateCoeffs=0;
% coeffRange=0;
% arch='virtex_5';




share_coeffs_biplex =1;  %I hereby releive the user of this choice.  Also, I releive me the obligation of developing the 'no' path

if(length(coeff_bit_width) == 1)
    coeff_bit_width = coeff_bit_width *ones(1,FFTSize);
end


if(length(shift_array) == 1)
    shift_array = shift_array *ones(1,FFTSize);
end
shift_array = shift_array(1:FFTSize);


% larger_fft_size = 13;
% coeff_bit_width = 18*ones(FFTSize, 1);
% register_coeffs = 1;
% delay_input = 1;
% delay_output = 1;
% sync_tree_input = 1;
% optional_delay_arr = [1,1,1];
% coeff_group_arr_in = [];
% coeff_stage_step_arr = zeros(1,FFTSize);
%
% input_bit_width = 18;
% inter_stage_bit_width = 18*ones(1,FFTSize-1);
% output_bit_width = 18;
% shift_arr = ones(1,FFTSize);
% pathToBlock = 'path:fft_direct';
%
%


defaultGroup=0;



if(length(biplex_mux_latency) == 1)
    biplex_mux_latency = biplex_mux_latency *ones(1,FFTSize-1);
end




biplex_len = FFTSize - n_sim_inputs;
biplex_stages = 1:biplex_len;
iSync = xInport('sync');
oSync = xOutport('sync_out');

if(length(inter_stage_bit_width) == 1)
    inter_stage_bit_width = inter_stage_bit_width*ones(1,FFTSize-1);
end


if(length(direct_coeff_step_rate)==1)
    direct_coeff_step_rate= direct_coeff_step_rate*ones(1,n_sim_inputs);
end


inter_stage_bit_width_biplex = inter_stage_bit_width(biplex_stages);
inter_stage_bit_width_direct = inter_stage_bit_width((biplex_len+1):end);


for(i = 1: 2^n_sim_inputs)
    iData{i} = xInport(strcat('in',num2str(i-1)));
    sSyncBiplexOut{i}=xSignal;
end


iSync1 = xInport('sync1');


if(~isempty(find(shift_array==2,1)))
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

if(share_coeffs_biplex ==1)
    for(i = 1:biplex_len)
       optional_delay_arr(i,:) = [0, biplex_delay_mid, biplex_delay_end];
    end
      stage_delay_arr = [2 4 (6*ones(1,biplex_len-2))];
      
      loop_run_len = max((2^(n_sim_inputs-3)),1);
    for(i=1:loop_run_len) 
        sCoeffIn{i} = xSignal;
        sSelIn{i} = xSignal;
        sCoeffSyncOut{i} = xSignal;
        
        if(i<loop_run_len/2+1)
            syncCoeff = iSync;
        else
            syncCoeff=iSync1;
        end
        
        blockTemp = xBlock(struct('source', str2func('biplex_coeff_muxsel_gen_draw_v2'), 'name',['biplex_muxsel_gen_', num2str(i-1)]), ...
            {biplex_len, coeff_bit_width(biplex_stages(1:(end-2))), ...
            register_coeffs_biplex, max_distro_size_coeff, optional_delay_arr, ...
            stage_delay_arr, biplex_mux_latency}, ...
            {syncCoeff}, {sCoeffIn{i},sSelIn{i},sCoeffSyncOut{i}});
    end
end


if(super_unscr == 0)
    for(i = 1: 2^n_sim_inputs)
        sBiplexOut{i} = xSignal;
        oData{i} = xOutport(strcat('out',num2str(i-1)));
    end
    
    direct_stages = (biplex_len+1):FFTSize;
    
    
    for(i=0:4:((2^n_sim_inputs)-1))
        biplex_num = i/4;
        
        
        
        if(biplex_num<(2^(n_sim_inputs-3)))
            coeff_index=biplex_num;
            
        else
            coeff_index = 2^(n_sim_inputs-2)-biplex_num-1;
        end
        
        if(coeff_index <(2^(n_sim_inputs-4)+1))
            biplex_sync = iSync;
        else
            biplex_sync = iSync1;
        end
        
        coeff_index=coeff_index+1;
        signal_indices=(i+1):(i+4);
        
        
        if(~isempty(find(shift_array(biplex_stages)==2,1)))
            sScaleInBiplex = sScaleIn;
        else
            sScaleInBiplex = {};
        end

        
        blockName = ['fft_biplex_4x_', num2str(i/4)];
        xBlock( struct('name', blockName, 'source', str2func('fft_biplex_4x_draw')), ...
            {  ...
            biplex_len,...
            coeff_bit_width(biplex_stages(1:(end-2))),...
            input_bit_width,...
            inter_stage_bit_width_biplex(1:(end-1)),...
            min(23,inter_stage_bit_width_biplex(end)), ...
            shift_array(biplex_stages),...
            max_distro_size_coeff,...
            max_distro_size_delay,...
            register_coeffs_biplex,...
            0,...
            biplex_delay_mid,...
            biplex_delay_end,...
            biplex_mux_latency, ...
            biplex_bram_latency_fft, ...
            biplex_bram_latency_unscr,...
            unscr_din_latency,...
            1 , 1,arch ...
            }, ...
            ...
            {biplex_sync, iData{signal_indices}, sCoeffIn{coeff_index},  sSelIn{coeff_index},  sCoeffSyncOut{coeff_index}, sScaleInBiplex}, ...
            {sSyncBiplexOut{i+1},sBiplexOut{signal_indices}});
    end
    
            blockName = 'fft_direct';
            
            
            
            if(~isempty(find(shift_array(direct_stages)==2,1)))
                sScaleInDirect = sScaleIn;
            else
                sScaleInDirect = {};
            end
            
            xBlock( struct('name', blockName, 'source', str2func('fft_direct_draw')), ...
            {  ...
            FFTSize-biplex_len, ...
            FFTSize, ...
            min(23,inter_stage_bit_width_biplex(end)),...
            coeff_bit_width(direct_stages-2), ...
            inter_stage_bit_width_direct, ...
            output_bit_width, ...
            register_coeffs_direct, ...
            0, ...
            delay_output,...
            delay_between_biplex_direct, ...
            inter_stage_delays_direct, ...
            coeff_group_arr_in, ...
            direct_coeff_step_rate, ...
            shift_array(direct_stages) ...
            ,arch...
            }, ...
            ...
            {sSyncBiplexOut{1}, sBiplexOut{:}, sScaleInDirect}, ...
            {oSync,oData{:}});
        
        
        
else
    
        for(i = 1: 2^(n_sim_inputs-1))
        sBiplexOut{i} = xSignal;
        oData{i} = xOutport(strcat('out',num2str(i-1)));
    end
    
    direct_stages = (biplex_len+1):(FFTSize-1);
    for(i=0:4:((2^n_sim_inputs)-1))
        
        biplex_num = i/4;
        if(biplex_num<(2^(n_sim_inputs-3)))
            coeff_index=biplex_num;
        else
            coeff_index = 2^(n_sim_inputs-2)-biplex_num-1;
        end
        coeff_index=coeff_index+1;
        
        if(coeff_index <(2^(n_sim_inputs-4)+1))
            biplex_sync = iSync;
        else
            biplex_sync = iSync1;
        end
        
        signal_indices=((i/2)+1):((i/2)+2);
        
        cramIn1 = {iData{i+1},iData{i+2}};
        cramIn2 = {iData{i+3},iData{i+4}};
        
        name1 = ['cram_', num2str(i/4),'_1'];
        name2 = ['cram_', num2str(i/4),'_2'];
        
        
        sIn1= xCram(cramIn1, name1);
        sIn2= xCram(cramIn2, name2);
        
        
        if(~isempty(find(shift_array(biplex_stages)==2,1)))
            sScaleInBiplex = sScaleIn;
        else
            sScaleInBiplex = {};
        end
        
        blockName = ['fft_biplex_', num2str(i/4)];
        xBlock( struct('name', blockName, 'source', str2func('fft_biplex_4x_draw')), ...
            {  ...
            biplex_len,...
            coeff_bit_width(biplex_stages(1:(end-2))),...
            input_bit_width,...
            inter_stage_bit_width_biplex(1:(end-1)),...
            min(23,inter_stage_bit_width_biplex(end)), ...
            shift_array(biplex_stages),...
            max_distro_size_coeff,...
            max_distro_size_delay,...
            register_coeffs_biplex,...
            0,...
            biplex_delay_mid,...
            biplex_delay_end,...
            biplex_mux_latency, ...
            biplex_bram_latency_fft, ...
            biplex_bram_latency_unscr,...
            unscr_din_latency,...
            0 , 1 ,arch
            ...
            }, ...
            ...
            {biplex_sync, sIn1, sIn2, sCoeffIn{coeff_index},  sSelIn{coeff_index},  sCoeffSyncOut{coeff_index}, sScaleInBiplex}, ...
            {sSyncBiplexOut{i+1},sBiplexOut{signal_indices}});
    end
    
    
    for(i=1:2^(n_sim_inputs-1))
        sDirectOut{i}=xSignal;
    end
    sDirectSyncOut= xSignal;
            blockName = 'fft_direct';
            
            
                 
            if(~isempty(find(shift_array(direct_stages(1:(end-1)))==2,1)))
                sScaleInDirect = sScaleIn;
            else
                sScaleInDirect = {};
            end
            
        xBlock( struct('name', blockName, 'source', str2func('fft_direct_draw')), ...
            {  ...
            FFTSize-biplex_len-1, ...
            FFTSize-1, ...
            min(23,inter_stage_bit_width_biplex(end)),...
            coeff_bit_width(direct_stages-2), ...
            inter_stage_bit_width_direct(1:(end-1)), ...
            inter_stage_bit_width_direct(end), ...
            register_coeffs_direct, ...
            0, ...
            delay_output,...
            delay_between_biplex_direct, ...
            inter_stage_delays_direct, ...
            coeff_group_arr_in, ...
            direct_coeff_step_rate(1:end-1), ...
            shift_array(direct_stages) ....
            ,arch...
            }, ...
            ...
            {sSyncBiplexOut{1}, sBiplexOut{:}, sScaleInDirect}, ...
            {sDirectSyncOut,sDirectOut{:}});
        
        
        
        blockName = 'fft_direct_unscr';
        
        if(shift_array(end)==2)
            sScaleInDirectUnscr = sScaleIn;
        else
            sScaleInDirectUnscr = {};
        end
        
       xBlock( struct('name', blockName, 'source', str2func('fft_direct_unscr_ml_draw_v10')), ...
            {  ...
            FFTSize ,...
            n_sim_inputs-1,...
            biplex_bram_latency_unscr ,...
            inter_stage_bit_width_direct(end) ,...
            coeff_bit_width(end),...
            output_bit_width ,...
            shift_array(end), ...
            direct_coeff_step_rate(end), updateCoeffs, coeffRange,arch
            }, ...
            ...
            {sDirectSyncOut,sDirectOut{:}, sScaleInDirectUnscr, iWe, iAddr, iDin}, ...
            {oSync, oData{:}});
        
        
    
        
    
end