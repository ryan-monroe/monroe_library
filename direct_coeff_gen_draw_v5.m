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


function direct_coeff_gen_draw_v5(FFTSize, larger_FFTSize, bit_width, register_coeffs, delay_input, sync_tree_input, optional_delay_arr, coeff_group_arr_in, coeff_stage_step_arr, radix4)
%optional_delay_arr: user assigned delays in-between or during each fft stage
%stage_delay_arr: mandatory algorithmic delays for each stage.  as of writing, it is 6 for every stage but the first, which is 3.
%register_coeffs: register the coeffs after pulling them out of the bram. This is managed in the coefficient generators, and is just a passed value
%sel_delay_arr: the incremental ammount of delay we must add to the sel, in addition to all the previous delays.
%coeff_delay_arr: the incremental ammount of delay we must add to the coeff sync pulse, in addition to all the previous delays.
%
% %
% xBlock;
% FFTSize= 4;
% larger_FFTSize = 13;
%
% delay_input = 1;
% optional_delay_arr = ones(1,FFTSize);
% sync_tree_input = 0;
% register_coeffs = 1;
% bit_width = 18*ones(1,FFTSize);
% coeff_group_arr = [];
% coeff_group_arr_in = coeff_group_arr;
% coeff_stage_step_arr = zeros(1,FFTSize);
% % coeff_stage_step_arr = [0,0,0]; %if these are set to '1', then the coefficient generator will make a design with every *other* coefficient.
% pathToBlock = 'path:direct_coeff_gen';
% % % %if it is '2', every fourth.  etc.
stages_radix4 = ceil(FFTSize/2);
nFFT=2^FFTSize;

if(length(optional_delay_arr) == 1)
    optional_delay_arr = optional_delay_arr *ones(1,FFTSize);
end

if(length(bit_width) == 1)
    bit_width = bit_width *ones(1,FFTSize);
end

if(length(coeff_stage_step_arr) == 1)
    coeff_stage_step_arr = coeff_stage_step_arr *ones(1,FFTSize);
end

if((~isInt([FFTSize, larger_FFTSize, register_coeffs,delay_input,sync_tree_input])))
    strError = 'The following parameters must be integers: FFTSize, larger_FFTSize, register_coeffs,delay_input';
    throwError(strError);
elseif(~isInt(optional_delay_arr)) || (~isInt(bit_width)) || (~isInt(isInt(coeff_group_arr_in))) || (~isInt(coeff_stage_step_arr))
    strError = 'The following parameter arrays must be composed entirely of integers: optional_delay_arr, coeff_bit_width, coeff_group_arr_in, coeff_stage_step_arr';
    throwError(strError);
    
    % elseif(length(optional_delay_arr) ~= FFTSize)
    %     strError = strcat('the array ''optional_delay_array'' must be FFTSize elements long;  length(optional_delay_array) = ', num2str(length(optional_delay_arr)));
    %     throwError(strError);
    % elseif(length(bit_width) ~= FFTSize)
    %     strError = strcat('the array ''coeff_bit_width'' must be FFTSize elements long;  length(coeff_bit_width) = ', num2str(length(bit_width)));
    %     throwError(strError);
    % elseif(length(coeff_stage_step_arr) ~= FFTSize)
    %     strError = strcat('the array ''coeff_stage_step_arr'' must be FFTSize elements long;  length(coeff_stage_step_arr) = ', num2str(length(coeff_stage_step_arr)));
    %     throwError(strError);
end

if(~min(size(coeff_group_arr_in) == [FFTSize, 2^(FFTSize-1)]))
    if(~(min(size(coeff_group_arr_in) == [0,0])))
        strError = strcat('the matrix ''coeff_group_arr_in'' must be FFTSize_by_2^(FFTSize-1) in size. (that is, ', num2str(FFTSize), '_by_', num2str(2^(FFTSize-1)), '); this is an expert feature... consider replacing this parameter with ''[]''  size(coeff_group_arr_in) = ', num2str(size(coeff_group_arr_in(1))), '_by_', num2str(size(coeff_group_arr_in(2))));
        throwError(strError);
    else
        defaultGroupArray = 0;
        
    end
end


if((min(optional_delay_arr) < 0))
    strError = strcat('optional_delay_arr must composed of non-negative integers; optional_delay_arr = ', num2str(optional_delay_arr));
    throwError(strError);
elseif(((min(bit_width) < 0))|| max(bit_width) > 18)
    strError = strcat('bit_width must composed of non-negative integers no greater than 18; bit_width = ', num2str(bit_width));
    throwError(strError);
    
elseif((min(coeff_stage_step_arr) < 0))
    strError = strcat('coeff_stage_step_arr must composed of non-negative integers; coeff_stage_step_arr = ', num2str(coeff_stage_step_arr));
    throwError(strError);
end
if((min(min(coeff_group_arr_in) < 0)))
    strError = strcat('coeff_group_arr_in must composed of non-negative integers; coeff_group_arr_in = ', num2str(coeff_group_arr_in));
    throwError(strError);
end

if(FFTSize > larger_FFTSize)
    throwError('FFTSize must be <= larger_FFTSize');
elseif(register_coeffs ~= 0 && register_coeffs ~= 1)
    strError = strcat('register_coeffs must be 0 or 1; register_coeffs= ', num2str(register_coeffs));
    throwError(strError);
elseif(sync_tree_input ~= 0 && sync_tree_input ~= 1)
    strError = strcat('sync_tree_input must be 0 or 1; sync_tree_input= ', num2str(sync_tree_input));
    throwError(strError);
end



defaultGroupArray  = (min(size(coeff_group_arr_in) == [0,0]));




if(defaultGroupArray == 1) %default to the same as the stock CASPER design
    coeff_group_subarray = 1:2^(FFTSize-1);
    for(i=1:FFTSize)
        coeff_group_arr(i,:) = coeff_group_subarray;
    end
else
    for(i=1:FFTSize)
        coeff_group_arr(i,:) = coeff_group_arr_in(i,:);
    end
end


%I/O
iSync = xInport('sync');
%
% oCoeff = xOutport('coeff');


fft_start_stage = larger_FFTSize - FFTSize +1;
stage_delay_arr = 6* ones(1,FFTSize);
if(radix4)
    for i=1:FFTSize
        if(FFTSize-(2*i-1)+1)>1
            stage_delay_arr(i)=stage_delay_arr(i)+4;
        end
    end
    stage_delay_arr((stages_radix4+1):end)=[];
    optional_delay_arr((stages_radix4+1):end)=[];
end
%coeff_delay_arr = [(6*sync_tree_input + delay_input), (optional_delay_arr+stage_delay_arr)];
coeff_delay_arr = [(delay_input), (optional_delay_arr+stage_delay_arr)];
coeff_delay_arr_out = [(delay_input), (optional_delay_arr+stage_delay_arr)];
coeffMadeTracker = zeros(FFTSize, 2^FFTSize); %this variable will track if we have made a coefficient generator for a given coefficient group.
%the value will be zero until that group has been made

if(sync_tree_input == 1)
    bSyncTree = xBlock(struct('source', 'monroe_library/delay_tree_z^-6_0'),{}, {iSync}, ...
        {xSignal,xSignal,xSignal,xSignal,xSignal,xSignal,xSignal,xSignal, ...
        xSignal,xSignal,xSignal,xSignal,xSignal,xSignal,xSignal,xSignal, ...
        xSignal,xSignal,xSignal,xSignal,xSignal,xSignal,xSignal,xSignal, ...
        xSignal,xSignal,xSignal,xSignal,xSignal,xSignal,xSignal,xSignal});
    sSyncTree = bSyncTree.getOutSignals();
else
    sSyncTree = {iSync,iSync,iSync,iSync,iSync,iSync,iSync,iSync, ...
        iSync,iSync,iSync,iSync,iSync,iSync,iSync,iSync, ...
        iSync,iSync,iSync,iSync,iSync,iSync,iSync,iSync, ...
        iSync,iSync,iSync,iSync,iSync,iSync,iSync,iSync};
    
end


sync_last = sSyncTree{1};
%now, for the coefficients
% for(stageNum = 1:FFTSize)
fft_stageNum=1;
stageNum=1;
while(fft_stageNum<=FFTSize)
    stagesRemaining=FFTSize-fft_stageNum+1;
    doingR4 = stagesRemaining>1 && radix4;
    
    if(doingR4)
        nButterflies = nFFT/4;
    else
        nButterflies = nFFT/2;
    end
    
    sSyncDelayInput = [];
    if(fft_stageNum==1)
        for i=1:nButterflies
            sSyncDelayInput{i}=sSyncTree{i};
            sSyncStageIn{i} = xSignal;
        end
    else
        for i=1:nButterflies
            sSyncDelayInput{i}=sync_last;
            sSyncStageIn{i} = xSignal;
        end
        
    end
    blockName = strcat('bulk_delay_', num2str(stageNum), '_2');
    bBulkDelay = xBlock(struct('source',str2func('bulk_delay_draw'), ...
        'name', blockName), ...
        {nButterflies,coeff_delay_arr(stageNum)}, {sSyncDelayInput{1:end}}, sSyncStageIn);
    %%%%%%%%%%%%%%%%%working here on sync fix nonsense
    twiddleInds_r4=0;
    %     for i=1:(2^FFTSize/4-1)
    %         twiddleInds_r4(i+1)=twiddleInds_r4(i)+fft_stageNum-1;
    %     end
    if(doingR4)
        twiddleInds_r4 = repmat(0:(2^fft_stageNum/2-1),1,nButterflies/(2^fft_stageNum/2));
    else
        twiddleInds_r4 = mod((0:(nButterflies-1))*2^(FFTSize- fft_stageNum),2^(FFTSize-1));
    end
    
    if(mod(FFTSize,2)==0 )
        twiddleInds_r4 = digitrevorder(twiddleInds_r4,4);
        twiddleInds_r4=bit_reverse(twiddleInds_r4,fft_stageNum+1);
    elseif(doingR4 && fft_stageNum<FFTSize)  %if(~isInt(log2(sqrt(length(twiddleInds_r4)))))
        twiddleInds_r4t=digitrevorder(twiddleInds_r4(1:end/2),4);
        twiddleInds_r4 =[twiddleInds_r4t twiddleInds_r4t];
        twiddleInds_r4=bit_reverse(twiddleInds_r4,fft_stageNum+1);
    else
        %         twiddleInds_r4=bitrevorder(twiddleInds_r4);
        twiddleInds_r4=bit_reverse(twiddleInds_r4, FFTSize);
    end
    
    for(butterflyNum = 1:2^(FFTSize-1-doingR4))
        %         if(doingR4)
        %             butterflyNumEffective = butterflyNum*2;
        %         else
        %             butterflyNumEffective = butterflyNum;
        %         end
        groupNum = coeff_group_arr(fft_stageNum, butterflyNum);
        if( coeffMadeTracker(stageNum, groupNum)==0) %if this coeff generation group does not yet exist...
            %....make a new coefficient generator to serve those butterflies.
            %sCoeffArr(stageNum, groupNum) = xSignal;
            if(doingR4)
                if(FFTSize==5 && fft_stageNum==3)
                    twiddleInds_r4(:)=[0,0,8,8,12,12,4,4];
                    %                     twiddleInds_r4(:)=0;
                end
                butterfliesProblem=[5,6,7,8];
                if(any(butterfliesProblem==butterflyNum) && fft_stageNum>1)
                    nCoeffs=2^(larger_FFTSize-FFTSize);
                    daTot=-0.024540219621814*16;
                    if(butterflyNum==5 || butterflyNum==6)
                        angle0=-0.392701862009286;
                    elseif(butterflyNum==7 || butterflyNum==8)
                        angle0=-1.178094464785611;
                    else
                        error('bleh')
                    end
                    coeff_angles=linspace(angle0,angle0+daTot,nCoeffs+1);
                    coeff_angles2=coeff_angles(1:(end-1));
                    coeff=exp(1j*coeff_angles2);
                else
                    coeff = direct_coeff_gen_calc(FFTSize, fft_stageNum+1, larger_FFTSize, fft_start_stage, twiddleInds_r4(butterflyNum)/2);  %WHY IS THERE A /2 here? MAKES NO SENSE :-/
                    
                end
                
                %                 else
                %                 end
                coeff_in = [coeff; coeff.^2; coeff.^3];
                stageEffective=fft_stageNum+1;
            elseif(~radix4)%then we are in full radix2 mode and shouldn't really worry about this bitreverse
                coeff_in= direct_coeff_gen_calc(FFTSize, fft_stageNum, larger_FFTSize, fft_start_stage, butterflyNum-1);
                stageEffective=fft_stageNum;
            else %we are in radix 4-2 hybrid mode, and should bit-reverse the order of the butterflies
                coeff_in= direct_coeff_gen_calc(FFTSize, fft_stageNum, larger_FFTSize, fft_start_stage, butterflyNum-1);
                stageEffective=fft_stageNum;
                
            end
            
            coeff = [imag(coeff_in), real(coeff_in)];
            coeff = coeff(:,1:(2^coeff_stage_step_arr(stageEffective)):length(coeff)); %this shortens our coeff array so that it corresponds to what the coefficient generator expects.
            
            if(doingR4)
                coeffOut1 = xSignal;
                coeffOut2 = xSignal;
                coeffOut3 = xSignal;
                
                bCoeffGenDual1 = xBlock(struct('source', str2func('coeff_gen_dual_draw'), ...
                    'name',strcat('coeff_gen_stage_',num2str(stageNum), '_group_', num2str(groupNum), '_coeff_1')), ...
                    {coeff(1,:), 'Block RAM', bit_width(stageNum), coeff_stage_step_arr(stageNum), register_coeffs});
                bCoeffGenDual2 = xBlock(struct('source', str2func('coeff_gen_dual_draw'), ...
                    'name',strcat('coeff_gen_stage_',num2str(stageNum), '_group_', num2str(groupNum), '_coeff_2')), ...
                    {coeff(2,:), 'Block RAM', bit_width(stageNum), coeff_stage_step_arr(stageNum), register_coeffs});
                bCoeffGenDual3 = xBlock(struct('source', str2func('coeff_gen_dual_draw'), ...
                    'name',strcat('coeff_gen_stage_',num2str(stageNum), '_group_', num2str(groupNum), '_coeff_3')), ...
                    {coeff(3,:), 'Block RAM', bit_width(stageNum), coeff_stage_step_arr(stageNum), register_coeffs});
                bCoeffGenDual1.bindPort(sSyncStageIn(butterflyNum), {coeffOut1});
                bCoeffGenDual2.bindPort(sSyncStageIn(butterflyNum), {coeffOut2});
                bCoeffGenDual3.bindPort(sSyncStageIn(butterflyNum), {coeffOut3});
                
                sCoeffArrStage{groupNum} = xCram({coeffOut1, coeffOut2, coeffOut3},['coeff_cram_stage_' num2str(stageNum) '_group_' num2str(groupNum)]);
                
                
            else
                sCoeffArrStage{groupNum}=xSignal;
                bCoeffGenDual = xBlock(struct('source', str2func('coeff_gen_dual_draw'), ...
                    'name',strcat('coeff_gen_stage_',num2str(stageNum), '_group_', num2str(groupNum))), ...
                    {coeff, 'Block RAM', bit_width(stageNum), coeff_stage_step_arr(stageNum), register_coeffs});
                
                
                bCoeffGenDual.bindPort({sSyncStageIn{butterflyNum}}, {sCoeffArrStage{groupNum}});
                
                tempArr = bCoeffGenDual.getOutSignals();
                sCoeffArrStage{groupNum} = tempArr{1}; %#ok<AGROW>
            end
            
            
            coeffMadeTracker(stageNum, groupNum)=1;
        end
        
        %now we are sure that the coefficient generator has been made.
        %time to compile the signals.
        sCoeffByButterflyArrStage{butterflyNum} = sCoeffArrStage{groupNum};
    end
    
    
    sCoeffStageConcated{stageNum} = xConcat(sCoeffByButterflyArrStage,strcat('concat_stage_', num2str(stageNum)));
    oCoeff{stageNum} = xOutport(strcat('coeff_stg',num2str(stageNum)));
    
    oCoeffVal=sCoeffStageConcated{stageNum};
    if(numel(oCoeffVal)>1)
        oCoeff{stageNum}.bind(oCoeffVal);
    else
        oCoeff{stageNum}.bind(oCoeffVal);
    end
    %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
    sync_last=sSyncStageIn{i};
    stageNum=stageNum+1;
    fft_stageNum = fft_stageNum+1+doingR4;
    
    
    sCoeffArrStage=[];
end



oSync = xOutport('sync_out');
total_fft_latency = sum(coeff_delay_arr_out);

%here's our sync output.
blockName = 'delay_sync_1';
sSyncDelay = xDelay(sSyncTree{end}, 1, blockName);
blockName = 'delay_sync_2';
sSyncDelay = xDelay(sSyncDelay, 1, blockName);
blockName = 'delay_sync_3';
sSyncDelay = xDelay(sSyncDelay, total_fft_latency-4, blockName);%put it in the middle because it'll have a bit more hardware cost, want to make that location flexible.
blockName = 'delay_sync_4';
sSyncDelay = xDelay(sSyncDelay, 1, blockName);
blockName = 'delay_sync_5';
sSyncDelay = xDelay(sSyncDelay, 1, blockName);
oSync.bind(sSyncDelay);


