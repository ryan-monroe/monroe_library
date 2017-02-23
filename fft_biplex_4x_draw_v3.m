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


function fft_biplex_4x_draw_v2(FFTSize,coeff_bit_width,input_bit_width,output_bit_width, inter_stage_bit_width, shift_arr,max_distro_size_coeff,max_distro_size_delay,register_coeffs,stage_pre_delay,stage_mid_delay,stage_post_delay,mux_latency_arr, bram_latency_fft, bram_latency_unscr,unscr_din_latency, real_inputs, share_coeffs,arch, max_lowres_bit_width, use_packed_unscrambler)
% %
%
% xBlock;
% 
% FFTSize = 5;
% coeff_bit_width=  18*ones(1,FFTSize-2);
% input_bit_width = 18;
% output_bit_width = 18;
% 
% inter_stage_bit_width = 18*ones(1,FFTSize-1); %up to 24
% shift_arr = ones(1,FFTSize);
% max_distro_size_coeff = 1;
% max_distro_size_delay = 1;
% register_coeffs = 0;
% 
% stage_pre_delay = 0;
% stage_mid_delay = 0;
% stage_post_delay = 0;
% 
% 
% 
% bram_latency_fft = 2;
% bram_latency_unscr = 2;
% unscr_din_latency = 0;
% pathToBlock = 'path:biplex';
% mux_latency_arr = 0;
% 
% %  
% %%%%%%%%%%%%%%%%%%%%5





%arrays:
% coeff_bit_width
% inter_stage_bit_width
% shift_arr
% 
% 
% %scalars
% FFTSize
% input_bit_width %%
% output_bit_width %%
% max_distro_size_coeff
% max_distro_size_delay
% stage_pre_delay
% stage_mid_delay
% stage_post_delay
% 
% 
% 
% 
% 
% 
% %bools
% register_coeffs %%
% bram_latency_fft%%
% bram_latency_unscr %%
% unscr_din_latency %%
 disp('enter: biplex draw')

if(~exist('use_packed_unscrambler','var'))
    use_packed_unscrambler=0;
end
if(length(inter_stage_bit_width) == 1)
    inter_stage_bit_width = inter_stage_bit_width *ones(1,FFTSize-1);
end

if(length(coeff_bit_width) == 1)
    coeff_bit_width = coeff_bit_width *ones(1,FFTSize-2);
end

if(length(shift_arr) == 1) 
    shift_arr = shift_arr *ones(1,FFTSize);
end


if(length(mux_latency_arr) == 1)
    mux_latency_arr = mux_latency_arr *ones(1,FFTSize);
end

%check that everything is an ingeger:
if((~isInt([FFTSize, input_bit_width, max_distro_size_coeff, max_distro_size_delay, stage_pre_delay ...
        ,stage_mid_delay,stage_post_delay, register_coeffs,bram_latency_fft,bram_latency_unscr,unscr_din_latency])))
    strError = 'The following parameters must be integers: FFTSize, larger_FFTSize, register_coeffs,delay_input';
    throwError(strError);
elseif( (~isInt(inter_stage_bit_width)) || (~isInt(coeff_bit_width)) ||  (~isInt(shift_arr)) || (~isInt(mux_latency_arr)))
    strError = 'The following parameter arrays must be composed entirely of integers: optional_delay_arr, coeff_bit_width, shift_arr, mux_latency_arr';
    throwError(strError);
    
    %check that the arrays are of the correct sizes
elseif(length(inter_stage_bit_width) ~= (FFTSize-1))
    strError = strcat('the array ''inter_stage_bit_width'' must be FFTSize-1 elements long;  length(inter_stage_bit_width) = ', num2str(length(inter_stage_bit_width)));
    throwError(strError);
elseif((length(coeff_bit_width)) ~= FFTSize-2)
    strError = strcat('the array ''coeff_bit_width'' must be FFTSize-2 elements long;  length(coeff_bit_width) = ', num2str(length(coeff_bit_width)));
    throwError(strError);
elseif(length(shift_arr) ~= FFTSize)
    strError = strcat('the array ''shift_arr'' must be FFTSize elements long;  length(shift_arr) = ', num2str(length(shift_arr)));
    throwError(strError);

%check that everything is inside the allowed bounds

elseif(((min(inter_stage_bit_width) < 0))|| max(inter_stage_bit_width) > 25)
    strError = strcat('inter_stage_bit_width must composed of positive integers no greater than 25; inter_stage_bit_width = ', num2str(inter_stage_bit_width));
    throwError(strError);
elseif(((min(coeff_bit_width) < 0))|| max(coeff_bit_width) > 18)
    strError = strcat('coeff_bit_width must composed of positive integers no greater than 18; coeff_bit_width = ', num2str(coeff_bit_width));
    throwError(strError);
elseif(((min(shift_arr) < 0))|| max(shift_arr) > 2)
    strError = strcat('shift_arr must composed of all 0''s, 1''s and 2''s; shift_arr = ', num2str(shift_arr));
    throwError(strError);
    
    
    
    

elseif(FFTSize <0 || FFTSize > 25)
    throwError('FFTSize must be a positive integer no greater than 25'); %25 is arbitrary.
elseif(input_bit_width < 0)
    strError = strcat('input_bit_width must be non-negative; input_bit_width= ', num2str(input_bit_width));
    throwError(strError);
elseif(output_bit_width < 0)
    strError = strcat('output_bit_width must be non-negative; output_bit_width= ', num2str(output_bit_width));
    throwError(strError);
elseif(input_bit_width < 0)
    strError = strcat('input_bit_width must be non-negative; input_bit_width= ', num2str(input_bit_width));
    throwError(strError);
elseif(max_distro_size_coeff < 0)
    strError = strcat('max_distro_size_coeff must be non-negative; max_distro_size_coeff= ', num2str(max_distro_size_coeff));
    throwError(strError);
elseif(max_distro_size_delay < 0)
    strError = strcat('max_distro_size_delay must be non-negative; max_distro_size_delay= ', num2str(max_distro_size_delay));
    throwError(strError);    
elseif(stage_pre_delay < 0)
    strError = strcat('stage_pre_delay must be non-negative; stage_pre_delay= ', num2str(stage_pre_delay));
    throwError(strError);    
elseif(stage_mid_delay < 0)
    strError = strcat('stage_mid_delay must be non-negative; stage_mid_delay= ', num2str(stage_mid_delay));
    throwError(strError);    
elseif(stage_post_delay < 0)
    strError = strcat('stage_post_delay must be non-negative; stage_post_delay= ', num2str(stage_post_delay));
    throwError(strError);    
    
    
    %bools
elseif(register_coeffs ~= 0 && register_coeffs ~= 1)
    strError = strcat('register_coeffs must be 0 or 1; register_coeffs= ', num2str(register_coeffs));
    throwError(strError);
elseif(bram_latency_fft ~= 2 && bram_latency_fft ~= 3)
    strError = strcat('bram_latency_fft must be 2 or 3; bram_latency_fft= ', num2str(bram_latency_fft));
    throwError(strError);
    elseif(bram_latency_unscr ~= 2 && bram_latency_unscr ~= 3)
    strError = strcat('bram_latency_unscr must be 2 or 3; bram_latency_unscr= ', num2str(bram_latency_unscr));
    throwError(strError);
elseif(unscr_din_latency ~= 0 && unscr_din_latency ~= 1)
    strError = strcat('unscr_din_latency must be 0 or 1; unscr_din_latency= ', num2str(unscr_din_latency));
    throwError(strError);

end








inter_stage_bit_width = [inter_stage_bit_width , output_bit_width];
stage_hires = inter_stage_bit_width > max_lowres_bit_width;
stage_hires(1:2)=0;

for(i = 1:FFTSize)
    optional_delay_arr(i,:) = [stage_pre_delay, stage_mid_delay, stage_post_delay];
end


if(length(coeff_bit_width) == 1)
    coeff_bit_width = coeff_bit_width * ones(1,FFTSize-2);
end


%I/O
iSync = xInport('sync');
oSync = xOutport('sync_out');

if(real_inputs==1)
    
    if(use_packed_unscrambler)
        
    iDataIn = {xInport('in0'),xInport('in1'),xInport('in2'),xInport('in3')};
    oDataOut = {xOutport('out01'), xOutport('out23')};
    
    sCram0In{1} = iDataIn{1};
    sCram0In{2} = iDataIn{2};
    sCram1In{1} = iDataIn{3};
    sCram1In{2} = iDataIn{4};
    
    sInA = xCram(sCram0In, 'cram0');
    sInB = xCram(sCram1In, 'cram1');
    else
    iDataIn = {xInport('in0'),xInport('in1'),xInport('in2'),xInport('in3')};
    oDataOut = {xOutport('out0'), xOutport('out1'), xOutport('out2'), xOutport('out3')};
    
    sCram0In{1} = iDataIn{1};
    sCram0In{2} = iDataIn{2};
    sCram1In{1} = iDataIn{3};
    sCram1In{2} = iDataIn{4};
    
    sInA = xCram(sCram0In, 'cram0');
    sInB = xCram(sCram1In, 'cram1');
    end
else
    iDataIn = {xInport('in0'),xInport('in1')};
    oDataOut = {xOutport('out0'), xOutport('out1')};
    
    sInA = iDataIn{1};
    sInB = iDataIn{2};
    
end


%add a muxsel/coeff generator, which will create all of our coefficients
%as well as generate our mux selects for use throughout the biplex stages.
%this block is extremely cheap compared with the standard formulation, at
%the cost of (of course) complexity.


if(share_coeffs==1)
    sCoeffAll =xInport('coeff');
    sSelAll =xInport('sel');
    sSyncCoreOut =xInport('sync_gen_sel_out');
    
else
    
    sCoeffAll = xSignal;
    sSelAll = xSignal;
    sSyncCoreOut = xSignal;
    
    stage_delay_arr = [2 4 (6*ones(1,FFTSize-2))];
    stage_delay_arr(stage_hires)=5;
    blockTemp = xBlock(struct('source', str2func('biplex_coeff_muxsel_gen_draw_v2'), 'name','biplex_muxsel_gen'), {FFTSize, coeff_bit_width, register_coeffs, max_distro_size_coeff, optional_delay_arr, stage_delay_arr, mux_latency_arr}, {iSync}, {sCoeffAll,sSelAll,sSyncCoreOut});
end

if(~isempty(find(shift_arr==2, 1)))
    sScaleIn = xInport('scale');
else
    sScaleIn = xConstVal(0,'Signed', 32,0,'const_scale_ignore');
end


for(i=1:FFTSize)
    sCoeffStage{i} = xSignal;
    
    
    sSyncOutStage{i} = xSignal;
    sApbwOutStage{i} = xSignal;
    sAmbwOutStage{i} = xSignal;
    
    blockName =  strcat('sel_slice',num2str(i));
    sSelStage{i} = xSliceBool(sSelAll, 'upper', -1*(i-1), blockName);
    
    if((FFTSize-i)>max_distro_size_delay)
        delays_bram = 1;
    else
        delays_bram = 0;
    end
    
    
    if(i==1)
        blockName = strcat('stage_',num2str(i));
        blockTemp = xBlock(struct('source', str2func('biplex_stage_n_draw_v2'), 'name',blockName), {FFTSize, i, input_bit_width, coeff_bit_width(i), inter_stage_bit_width(i), delays_bram, bram_latency_fft, shift_arr(i), optional_delay_arr(i,:), mux_latency_arr(i), arch,stage_hires(i)});
        blockTemp.bindPort({sInA, sInB, iSync, sSelStage{i}, sScaleIn}, {sApbwOutStage{i},sAmbwOutStage{i},sSyncOutStage{i}});
        %blockTemp.bindPort({sInA, sInB, iSync, sSelStage{i}}, {sApbwOutStage{i}})
        
    elseif (i==2)
        
        blockName = strcat('stage_',num2str(i));
        blockTemp = xBlock(struct('source', str2func('biplex_stage_n_draw_v2'), 'name',blockName), {FFTSize, i, inter_stage_bit_width(i-1), coeff_bit_width(i), inter_stage_bit_width(i), delays_bram, bram_latency_fft, shift_arr(i), optional_delay_arr(i,:), mux_latency_arr(i), arch,stage_hires(i)}, ...
            {sApbwOutStage{i-1},sAmbwOutStage{i-1}, sSyncOutStage{i-1}, sSelStage{i}, sScaleIn}, {sApbwOutStage{i},sAmbwOutStage{i},sSyncOutStage{i}});
    else
        coeffOffset = -2 * sum(coeff_bit_width(1:(i-3)));
        
        blockName = strcat('coeff_slice',num2str(i));
        sCoeffStage{i} = xSlice(sCoeffAll,  coeff_bit_width(i-2)*2 , 'upper', coeffOffset, ...
            blockName);
        
        
        blockName = strcat('stage_',num2str(i));
        blockTemp = xBlock(struct('source', str2func('biplex_stage_n_draw_v2'), 'name',strcat('stage_',num2str(i))), {FFTSize, i, inter_stage_bit_width(i-1), coeff_bit_width(i-2), inter_stage_bit_width(i), delays_bram, bram_latency_fft, shift_arr(i), optional_delay_arr(i,:), mux_latency_arr(i), arch,stage_hires(i)}, ...
            {sApbwOutStage{i-1},sAmbwOutStage{i-1}, sSyncOutStage{i-1}, sCoeffStage{i}, sSelStage{i}, sScaleIn}, {sApbwOutStage{i},sAmbwOutStage{i},sSyncOutStage{i}});
    end
    
    
end

if(real_inputs==1)
    if(use_packed_unscrambler)
%         blockTemp = xBlock('casper_library_ffts_internal/bi_real_unscr_2x', ...
%             struct('FFTSize',FFTSize,'n_bits',inter_stage_bit_width(FFTSize),'add_latency',1,'conv_latency',1,'bram_latency',1,'bram_map','off','dsp48_adders','off'));
%         blockTemp.bindPort({sSyncCoreOut, sApbwOutStage{FFTSize},sAmbwOutStage{FFTSize}}, {oSync,oDataOut{1:2}});
%         
        
            blockTemp = xBlock(struct('source', str2func('biplex_2x_unscr_draw'), 'name','biplex_2x_unscr'), {FFTSize, bram_latency_unscr, inter_stage_bit_width(FFTSize), unscr_din_latency}, ...
                {sApbwOutStage{FFTSize},sAmbwOutStage{FFTSize}, sSyncCoreOut},...
                {oDataOut{1:2}, oSync});
    else
        
        blockTemp = xBlock(struct('source', str2func('biplex_4x_unscr_draw'), 'name','biplex_4x_unscr'), {FFTSize, bram_latency_unscr, inter_stage_bit_width(FFTSize), unscr_din_latency}, ...
            {sApbwOutStage{FFTSize},sAmbwOutStage{FFTSize}, sSyncCoreOut},...
        {oDataOut{1:4}, oSync});
    end
else
   xlsub2_biplex_cplx_unscrambler_sub = xBlock(struct('source',str2func('biplex_cplx_unscrambler_init_xblock'), 'name', 'biplex_cplx_unscrambler'), ...
                                        {['/biplex_cplx_unscrambler'],FFTSize,bram_latency_unscr},...
                                        {sApbwOutStage{FFTSize},sAmbwOutStage{FFTSize}, sSyncCoreOut}, ...
                                        {oDataOut{1}, oDataOut{2}, oSync});
 
end
disp('exit: biplex draw')