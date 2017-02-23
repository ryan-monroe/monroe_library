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


function fft_quadplex_4x_draw(FFTSize,coeff_bit_width,input_bit_width,inter_stage_bit_width, ...
    output_bit_width, shift_arr,max_distro_size_coeff,register_coeffs, mux_latency_arr, stage_mid_delay, bram_latency_fft,...
    bram_latency_unscr,unscr_din_latency,  real_inputs, share_coeffs,arch,muxsel_delay)
if ~exist('muxsel_delay','var')
    muxsel_delay=0;
end
% %
% %
% xBlock;
% % 
% FFTSize = 6;
% coeff_bit_width=  18*ones(1,FFTSize-2);
% input_bit_width = 18;
% output_bit_width = 18;
% 
% inter_stage_bit_width = 18*ones(1,FFTSize-1); %up to 24
% shift_arr = ones(1,FFTSize);
% max_distro_size_coeff = 4;
% max_distro_size_delay = 4;
% register_coeffs = 0;
% 
% stage_pre_delay = 0;
% stage_mid_delay = 1;
% stage_post_delay = 0;
% 
% 
% 
% bram_latency_fft = 0;
% bram_latency_unscr = 1;
% unscr_din_latency = 0;
% mux_latency_arr = 0;
% real_inputs=0;
% share_coeffs=0;
% arch='virtex_5';

%  
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



if(length(stage_mid_delay)==1)
    stage_mid_delay=stage_mid_delay*ones(FFTSize/2,1);
end


if(length(mux_latency_arr)==1)
    mux_latency_arr=mux_latency_arr*ones(FFTSize/2,1);
end

assert(isInt(FFTSize/2))
bram_latency_fft=bram_latency_fft+2;
bram_latency_unscr=bram_latency_unscr+2;

if(length(inter_stage_bit_width) == 1)
    inter_stage_bit_width = inter_stage_bit_width * ones(1,FFTSize-1);
end

inter_stage_bit_width = [inter_stage_bit_width , output_bit_width];



% for(i = 1:FFTSize)
%     optional_delay_arr(i,:) = [stage_pre_delay, stage_mid_delay, stage_post_delay];
% end


if(length(coeff_bit_width) == 1)
    coeff_bit_width = coeff_bit_width * ones(1,FFTSize-2);
end
if(length(shift_arr) == 1)
    shift_arr = shift_arr * ones(1,FFTSize-2);
end
 

%I/O
iSync = xInport('sync');
oSync = xOutport('sync_out');

if(real_inputs==1)
    iDataIn = {xInport('in0'),xInport('in1'),xInport('in2'),xInport('in3')};
    oDataOut = {xOutport('out0'), xOutport('out1'), xOutport('out2'), xOutport('out3')};
    
    sCram0In{1} = iDataIn{1};
    sCram0In{2} = iDataIn{2};
    sCram1In{1} = iDataIn{3};
    sCram1In{2} = iDataIn{4};
    
    sInA = xCram(sCram0In, 'cram0');
    sInB = xCram(sCram1In, 'cram1');
else
    iDataIn = {xInport('in0'),xInport('in1'),xInport('in2'),xInport('in3')};
    oDataOut = {xOutport('out0'), xOutport('out1'),xOutport('out2'), xOutport('out3')};
   
    
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
    
    stage_delay_arr = [4, (10*ones(1,(FFTSize/2)-1))]+2;%plus 2 for rounding
    blockTemp = xBlock(struct('source', str2func('quadplex_cmd_v2'), 'name','quadplex_muxsel_gen'), ...
        {FFTSize, coeff_bit_width, register_coeffs, max_distro_size_coeff, stage_delay_arr, mux_latency_arr, stage_mid_delay,muxsel_delay}, ...
        {iSync}, {sCoeffAll,sSelAll,sSyncCoreOut});
end

if(~isempty(find(shift_arr==2, 1)))
    sScaleIn = xInport('scale');
else
    sScaleIn = xConstVal(0,'Signed', 32,0,'const_scale_ignore');
end

stageDataOut = [iDataIn {iSync}];
for stageNum=1:FFTSize/2
    sCoeffStage{stageNum} = xSignal;
    
    blockName =  strcat('sel_slice',num2str(stageNum));
    sSelStage{stageNum} = xSlice(sSelAll,2,'upper',-2*(stageNum-1),blockName);
    
    if(stageNum~=1)
                coeffOffset = -6 * sum(coeff_bit_width(1:(stageNum-2)));
        
        blockName = strcat('coeff_slice',num2str(stageNum));
        sCoeffStage{stageNum} = xSlice(sCoeffAll,  coeff_bit_width(stageNum-1)*6 , 'upper', coeffOffset, ...
            blockName);
        stageDataIn = [stageDataOut sCoeffStage(stageNum) sSelStage(stageNum) ];
    else
        
        stageDataIn = [stageDataOut sSelStage(stageNum) ];
    end
    
    
    for i=1:5
        stageDataOut{i}=xSignal;
    end
    
%     if(stageNum==1)
%             blockName = strcat('stage_',num2str(stageNum));
%     blockTemp = xBlock(struct('source', str2func('quadplex_stage_n_draw_lw'), 'name',blockName), ...
%         {FFTSize, stageNum, input_bit_width, coeff_bit_width(stageNum),...
%         inter_stage_bit_width(stageNum), bram_latency_fft, shift_arr(stageNum), mux_latency_arr(stageNum), arch});
%     blockTemp.bindPort(stageDataIn([1,2,3,5,7]), stageDataOut);
%     else 
        if(stageNum==1)
            ibw=input_bit_width;
            cbw=coeff_bit_width(1);
        else
            ibw=inter_stage_bit_width(stageNum-1);
            cbw=coeff_bit_width(stageNum-1);
        end
        if(stageNum== FFTSize/2)
            obw=output_bit_width;
        else
            obw=inter_stage_bit_width(stageNum);
        end
        
    blockName = strcat('stage_',num2str(stageNum));
    blockTemp = xBlock(struct('source', str2func('quadplex_stage_n_draw_v3'), 'name',blockName), ...
        {FFTSize, stageNum, ibw, cbw, obw, bram_latency_fft, ...
        shift_arr(stageNum), mux_latency_arr(stageNum), stage_mid_delay(stageNum), arch,muxsel_delay});
    blockTemp.bindPort(stageDataIn, stageDataOut);
%     end
        
end
    blockTemp = xBlock(struct('source', str2func('quadplex_cplx_unscrambler_draw'), 'name','quadplex_cplx_unscrambler'), ...
        {FFTSize, output_bit_width, mux_latency_arr(end), bram_latency_unscr,muxsel_delay});
    blockTemp.bindPort([stageDataOut(1:4), {sSyncCoreOut}], [oDataOut,{oSync}]);
% 
% for i=1:4
%     oDataOut{i}.bind(stageDataOut{i});
% end
% oSync.bind(sSyncCoreOut);
return
