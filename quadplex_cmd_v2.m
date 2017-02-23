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


function quadplex_cmd(FFTSize, bit_width, register_coeffs, max_distro_size, stage_delay_arr, mux_latency_arr, stage_mid_delay,muxsel_delay)
%optional_delay_arr: user assigned delays in-between or during each fft stage
%stage_delay_arr: mandatory algorithmic delays for each stage.  as of writing, it is 6 for every stage but the first, which is 3.
%register_coeffs: register the coeffs after pulling them out of the bram. This is managed in the coefficient generators, and is just a passed value
%sel_delay_arr: the incremental ammount of delay we must add to the sel, in addition to all the previous delays.
%coeff_delay_arr: the incremental ammount of delay we must add to the coeff sync pulse, in addition to all the previous delays.

%we will ge generating a sel signal for all stages,
%but only a coeff signal for stages 3 to FFTSize.
% %
clear sCoeff
%
% xBlock;
% %
% FFTSize = 6;
% stage_delay_arr = [10,10,10];
% register_coeffs = 0;
% bit_width = 18*ones(1,FFTSize/2);
% max_distro_size = 3;
% mux_latency_arr = ones(1,FFTSize/2);
% % % %


%fft_delay = total latency across entire FFT
nFFT=2^FFTSize;
fftStages=FFTSize/2;
assert(floor(fftStages)==fftStages);
w = exp(-1j*2*pi/nFFT*[0:(nFFT/2-1)]);

stage_mid_delay=stage_mid_delay+muxsel_delay;

fft_delay = sum(sum(mux_latency_arr) + sum(stage_delay_arr) + sum(stage_mid_delay)) + 2^FFTSize -1;

%I/O
iSync = xInport('sync');

oCoeff = xOutport('coeff');
oSel = xOutport('sel');
oSync = xOutport('sync_out');


coeff_delay_arr(1) = mux_latency_arr(1)+stage_mid_delay(1);
sel_delay_arr(1) = 0;
for(i = 2:fftStages)
    coeff_delay_arr(i) = mux_latency_arr(i)+stage_mid_delay(i);
    sel_delay_arr(i) =  mux_latency_arr(i-1)+stage_mid_delay(i-1);
    if(i ~= 0)
        coeff_delay_arr(i) = coeff_delay_arr(i) + stage_delay_arr(i-1);
        sel_delay_arr(i) = sel_delay_arr(i) + stage_delay_arr(i-1);
    end
end

coeff_delay_arr(2) = sum(coeff_delay_arr(1:2));



%make those coefficients
% sCoeffSync{2} = iSync;
sCoeffSync{1} = xSignal;
bSyncDelay = xBlock('monroe_library/sync_delay_fast', struct('delay_len', 2^(FFTSize-2) + 2^(FFTSize-1) ), {iSync}, {sCoeffSync{1}});

sCoeffCounter = xSignal;
bCountUp = xBlock(struct('source','Counter', 'name', 'Counter_up'), ...
    struct('cnt_type', 'Free Running', 'operation', 'Up', 'start_count',...
    2+register_coeffs, 'cnt_by_val', 1, 'arith_type', 'Unsigned', 'n_bits', FFTSize-2, 'bin_pt', 0, 'load_pin', 'off',...
    'rst', 'on', 'en', 'off', 'period', 1, 'explicit_period', 'on', 'implementation', 'Fabric'), ...
    {sCoeffSync{1}}, {sCoeffCounter});


for(stageNum = 2:fftStages)
    clear coeff_complex
    sCoeffCounterInv = xSignal;
    
    %     sCoeffCounterInv.bind(sCoeffCounter);
    xBlock(struct('source',str2func('single_bit_invert_draw_r4'),'name', strcat('single_bit_invert', num2str(stageNum))), ...
        {FFTSize-1, FFTSize-stageNum*2, 0}, {sCoeffCounter}, {sCoeffCounterInv});
    
    blockName = strcat('coeff_counter_delay_', num2str(stageNum));
    sCoeffCounter = xDelayr(sCoeffCounterInv, coeff_delay_arr(stageNum), blockName);
    
    %if there are too many coefficients, store everything in Block RAM.
    %because we are so efficient in RAM, and fabric is always at a premium,
    %and since with the dual coeff gens we just use one bram18 (thus the
    %butterfly is DSP-limited), we should basically always use BRAMs.
    if( (stageNum*2-1) > max_distro_size)
        memory_type = 'Block RAM';
    else
        memory_type = 'Distributed memory';
    end
    
    effective_stage = 2*stageNum;
    L = 2^effective_stage;
    %         coeff_complex = biplex_coeff_gen_calc(FFTSize,stageNum);
    coeffs_stage = w(1:nFFT/L:(nFFT/4));
    coeff_complex(:,1) = digitrevorder(coeffs_stage,4);
    coeff_complex(:,2) = coeff_complex(:,1).^2;
    coeff_complex(:,3) = coeff_complex(:,1).^3;
    
    
    
    coeff = [imag(coeff_complex); real(coeff_complex)];
    for rr=1:3
%         coeff(:,rr)=fastRounder(coeff(:,rr),1,16,2);
        coeff(:,rr)=double(fi(coeff(:,rr),1,18,16));
    end
    sCoeffSync{stageNum,1} = xSignal;
    
    for i=1:3
        sCoeffStage{i} = xSignal;
        blockName = ['coeff_gen' num2str(stageNum) '_' num2str(i)];
        blockTemp = xBlock(struct('source', str2func('coeff_gen_dual_external_counter_draw_v2'), 'name',blockName), {coeff(:,i), memory_type, bit_width(stageNum-1),FFTSize-2*stageNum+1, register_coeffs});
        blockTemp.bindPort({sCoeffCounter}, {sCoeffStage{i}});
    end
    sCoeff(stageNum-1)={xCram(sCoeffStage(:)',['cram_coeffs' num2str(stageNum)])};
end

sCramOut = xCram(sCoeff, 'cram');

if(~strcmp(class(sCramOut),'xSignal'))
    sCramOut=sCramOut{1}; %for compatibility with nFFT=4
end
oCoeff.bind(sCramOut);


%make the counter that will ultimately be used for all the mux selectors.
%by doing it this way, we only need to make one counter.
sCountArr{1} = xSignal;
bCountUp = xBlock('Counter', struct('cnt_type', 'Free Running', 'operation', 'Up', 'start_count',...
    1, 'cnt_by_val', 1, 'arith_type', 'Unsigned', 'n_bits', FFTSize, 'bin_pt', 0, 'load_pin', 'off',...
    'rst', 'on', 'en', 'off', 'period', 1, 'explicit_period', 'on', 'implementation', 'Fabric'), ...
    {iSync}, {sCountArr{1}});

%now delay all the bits the appropriate ammount, and spin them off as needed.
%note that several delay elements could be saved by grouping delay
%elements.  The typical stage will only have a latency of 7 or 8, but a
%SRL16 can hold a latency of up to 16.
for(stageNum = 1:fftStages)
    sSelOut{stageNum}=xSignal;
    sCountArr{stageNum+1}= xSignal;
    
    blockName = strcat('sel_delay', num2str(stageNum));
    sCountArr{stageNum}  = xDelay(sCountArr{stageNum}, sel_delay_arr(stageNum), blockName);
    
    
    %individual bit-slice to be presented to the sel output
    blockName =  strcat('slice_sel_top_',num2str(stageNum));
    %     sSelOut{stageNum} = xSliceBool(sCountArr{stageNum}, 'upper', 0, blockName);
    sSelOut{stageNum} = xSlice(sCountArr{stageNum}, 2,'upper',0,blockName);
    
    if(stageNum ~= fftStages)
        %rest of the bits to be passed on...
        blockName = strcat('slice_sel_bottom_',num2str(stageNum));
        sCountArr{stageNum+1} = xSlice(sCountArr{stageNum}, FFTSize-stageNum*2, ...
            'lower', 0, blockName);
    end
end

sConcatOut = xConcat(sSelOut, 'concat');
oSel.bind(sConcatOut);

[sum(stage_delay_arr) 2^(FFTSize-2)-1 sum(mux_latency_arr) sum(stage_mid_delay)]
delay_total = sum(stage_delay_arr) + 2^(FFTSize-2)-1 + sum(mux_latency_arr) + sum(stage_mid_delay);

sync_delay_fast_out = xSignal;

sSyncTemp = xDelay(sCoeffSync{1},1,'sync_out_delay1');
sSyncTemp = xDelay(sSyncTemp ,1,'sync_out_delay2');
sSyncTemp = xDelay(sSyncTemp ,1,'sync_out_delay3');
bSyncDelay = xBlock(struct('source', 'monroe_library/sync_delay_fast', 'name', 'sync_delay_fast_output'), struct('delay_len', delay_total - 5), {sSyncTemp}, {sync_delay_fast_out});
sSyncTemp = xDelay(sync_delay_fast_out ,1,'sync_out_delay4');
sSyncTemp = xDelay(sSyncTemp ,1,'sync_out_delay5');

oSync.bind(sSyncTemp);




