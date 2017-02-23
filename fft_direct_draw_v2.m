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


function fft_direct_draw(FFTSize, larger_fft_size, input_bit_width, coeff_bit_width, inter_stage_bit_width, output_bit_width, register_coeffs, delay_input, delay_output, sync_tree_input, optional_delay_arr, coeff_group_arr_in, coeff_stage_step_arr, shift_arr,arch, radix4, max_lowres_bit_width)
% xBlock;
% FFTSize = 4;
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
fftSize5_permuteOrder=[1,9,17,25,3,11,19,27 ...
    5,13,21,29,7,15,23,31 ...
    2,10,18,26,4,12,20,28 ...
    6,14,22,30,8,16,24,32];
nFFT=2^FFTSize;
defaultGroup=0;


%% check if any of the input arrays are just a single value, make an
%appropriately-sized array out of it: promotes user-friendlieness
if(length(inter_stage_bit_width) == 1)
    if(FFTSize~=1)
        inter_stage_bit_width = inter_stage_bit_width *ones(1,FFTSize-1);
    end
end

if(length(coeff_bit_width) == 1)
    coeff_bit_width = coeff_bit_width *ones(1,FFTSize);
end

if(length(optional_delay_arr) == 1)
    optional_delay_arr = optional_delay_arr *ones(1,FFTSize-1);
elseif isempty(optional_delay_arr)
    optional_delay_arr =0;
end

if(FFTSize==1)
    optional_delay_arr=1;
    
end


if(length(coeff_stage_step_arr) == 1)
    coeff_stage_step_arr = coeff_stage_step_arr *ones(1,FFTSize);
end

if(length(shift_arr) == 1)
    shift_arr = shift_arr *ones(1,FFTSize);
end

if(radix4)
    n_actual_fft_stages = ceil(FFTSize/2);
else
    n_actual_fft_stages =FFTSize;
end


if ~exist('max_lowres_bit_width','var')
    max_lowres_bit_width=99;
end
inter_stage_bit_width = [inter_stage_bit_width output_bit_width];
stage_hires = inter_stage_bit_width > max_lowres_bit_width;
iSync = xInport('sync');
oSync = xOutport('sync_out');

optional_delay_arr_direct = [delay_input, optional_delay_arr, delay_output];

for(i = 1: 2^FFTSize)
    iData{i} = xInport(strcat('in',num2str(i-1)));
    oData{i} = xOutport(strcat('out',num2str(i-1)));
end

if(~isempty(find(shift_arr==2,1)))
    sScaleIn = xInport('scale');
end


%% arrange the input ports appropriately
k=1;
if(radix4 && FFTSize>1)
    for(i=1:nFFT/4)
        ind1=4*(i-1)+1;
        ind2=ind1+3;
        sData(ind1:ind2) = iData(i:nFFT/4:nFFT);
    end
else
    
    for(i = 1:2:2^FFTSize)
        sData{i} = iData{k};
        k=k+1;
    end
    %k=2^(FFTSize-1)+1;
    for(i = 2:2:2^FFTSize)
        sData{i} = iData{k};
        k=k+1;
    end
end

%add the bulk delay to the input (special 'cause it does not worry about
%the 2-cycle delay from a+bw)

%each of these delays has two 'parts'.  The first is mandatory, taking care
%of all the delays that are needed to make the data line up in the right
%ways.  The second is optional, based on demand by the user.  It is assumed
%that the if the user wants the data path to use a uniform ammount of
%hardware between stages, so the mandatory delays are rolled into the same
%slices as the first set of optional delays (if they exist).
delay_arr = zeros(1,2^FFTSize);
if(~radix4)
    delay_arr(1:2:(2^FFTSize)) = 1;
end
if(sync_tree_input > 0)
    delay_arr = delay_arr + 6;
end
if(optional_delay_arr_direct(1) > 0)
    delay_arr = delay_arr + 1;
    optional_delay_arr_direct(1) = optional_delay_arr_direct(1) -1;
end


sData = xBulkDelayr(sData, 2^FFTSize, delay_arr, 'bulk_delay_0_1');



for(i = (1:optional_delay_arr_direct(1)))
    delay_arr = ones(1,2^FFTSize);
    blockName = strcat('bulk_delay_0_', num2str(i+1));
    sData = xBulkDelayr(sIn, 2^FFTSize, delay_arr, blockName);
end


%% coeff generator drawing:
for(i = 1:n_actual_fft_stages)
    sStageCoeffs{i} = xSignal;
end

coeff_delay_arr= [optional_delay_arr, delay_output];
blockTemp = xBlock(struct('source', @direct_coeff_gen_draw_v3, 'name', 'direct_coeff_gen'), ...
    {FFTSize, larger_fft_size, coeff_bit_width, register_coeffs, delay_input, ...
    sync_tree_input, coeff_delay_arr , coeff_group_arr_in, coeff_stage_step_arr,radix4});
blockTemp.bindPort({iSync}, {sStageCoeffs{1:n_actual_fft_stages},oSync});

actual_FFTStage=1;
FFTStage=1;

while(actual_FFTStage <=FFTSize)
    % for(FFTStage = 1:FFTSize)
    %% make the signals for the next stage'es outputs.
    stage_radix4=(FFTSize-actual_FFTStage+1>1);
    leaving_radix4=(FFTSize-actual_FFTStage==2)&& (floor(FFTSize/2)~=FFTSize/2);
    radix4_last_stage = (FFTSize-actual_FFTStage==1)&& (floor(FFTSize/2)==FFTSize/2);
    for(i=1:2^FFTSize)
        sStageDataOut{i} = xSignal;
    end
    
    if(FFTStage == 1)
        stage_in_bit_width = input_bit_width;
    else
        stage_in_bit_width = inter_stage_bit_width(FFTStage-1);
    end
    
    if(shift_arr(FFTStage)==2) 
        sStageShiftIn=sScaleIn;
    else
        name_const = ['shift_const_', num2str(FFTStage)];
        sStageShiftIn=xConstVal(-1*shift_arr(FFTStage),'Signed', 32,0,name_const);
    end
    
    if(stage_radix4)
        blockName =  strcat('stage_', num2str(FFTStage));
        blockTemp = xBlock(struct('source', @fft_direct_stage_draw_r4, 'name',blockName), ...
            {FFTSize, FFTStage, stage_in_bit_width, coeff_bit_width(FFTStage), ...
            inter_stage_bit_width(FFTStage), larger_fft_size-FFTSize+FFTStage, shift_arr(FFTStage)});
        blockTemp.bindPort({sStageShiftIn, sData{:}, sStageCoeffs{FFTStage}}, sStageDataOut);
        if(radix4_last_stage)
            map = digitrevorder(0:nFFT-1, 4)+1;
        elseif(~leaving_radix4)
            blockSize = nFFT/2^(actual_FFTStage-1);
            stepSize = blockSize/4;
            for block=1:nFFT/blockSize
                for i=1:stepSize
                    ind1=4*(i-1)+1+(block-1)*blockSize;
                    ind2=ind1+3;
                    map(ind1:ind2)=(i:stepSize:blockSize)+(block-1)*blockSize;
                end
            end
        else %leaving radix 4
            %             map_scr=[];
            %             for i=1:nFFT/8
            %                 for kk=1:4
            %                     inputNum=kk+8*(i-1);
            %                     map_scr(:,end+1)=[inputNum;inputNum+4];
            %                 end
            %             end
            %             map_scr_bitrev=digitrevorder(map_scr.',4).';
            % %             map_scr_bitrev=map_scr;
            % %             bro = digitrevorder(0:nFFT/2-1,4)+1;
            % %             map_scr = [(1:2:nFFT)' (2:2:nFFT)'];
            % %             map_bro = digitrevorder(map_scr,4).';
            %             map=map_scr_bitrev(:);
            frame_ind=digitrevorder(0:(2^FFTSize/2-1),4).';
            final_reo(1:2^FFTSize/2)=frame_ind*2;
            final_reo((2^FFTSize/2+1):2^FFTSize)=frame_ind*2+1;
            map=final_reo+1;
            map_temp(map)=1:length(map);
            map=map_temp;
%             map=fftSize5_permuteOrder;
        end
    else 
        
        blockName =  strcat('stage_', num2str(FFTStage));
        blockTemp = xBlock(struct('source', @fft_direct_stage_draw, 'name',blockName), ...
            {FFTSize, FFTStage, stage_in_bit_width, coeff_bit_width(FFTStage), ...
            inter_stage_bit_width(FFTStage), larger_fft_size-FFTSize+FFTStage, shift_arr(FFTStage), arch});
        blockTemp.bindPort({sStageShiftIn, sData{:}, sStageCoeffs{FFTStage}}, sStageDataOut);
        
        
        %establish the mapping between the exit ports of one stage and the
        %input ports of the next.
        map = -1 * ones(1,2^FFTSize);
        if(FFTStage ~= FFTSize)
            frameSize = 2^(FFTSize-FFTStage + 1);
            bitRevParam = FFTSize-FFTStage + 1;
        else
            frameSize = 2^(FFTSize);
            bitRevParam = FFTSize;
        end
        %% radix 2 map generator
        for(i=0:((2^FFTSize)-1))
            
            if(actual_FFTStage ~= FFTSize)
                frameSize = 2^(FFTSize-FFTStage + 1);
                bitRevParam = FFTSize-FFTStage + 1;
                
                isApBW = mod(i+1,2);config.source=str2func('fft_direct_draw_v2');
config.toplevel=gcb;
config.debug=0;
config.depend={'fft_direct_draw_v2.m'};
xBlock(config,{FFTSize,larger_fft_size,input_bit_width,coeff_bit_width,inter_stage_bit_width,output_bit_width,register_coeffs,delay_input,delay_output,sync_tree_input,optional_delay_arr,coeff_group_arr_in,coeff_stage_step_arr,shift_arr,arch,1,max_lowres_bit_width});
                frameNum = floor(i/frameSize);
                indexInFrame = i - (frameNum*frameSize);
                
                bottomOfFrame = floor(indexInFrame / (frameSize/2));
                k = i-1;
                %         map(i+1) = frameNum * frameSize + bit_reverse(indexInFrame, bitRevParam ) +1;
                %  map(i+1) = frameNum * frameSize + bit_reverse(indexInFrame, FFTSize-FFTStage + 1) +1;
                if((~bottomOfFrame) && isApBW)
                    map(i+1) = i;
                elseif ((~bottomOfFrame) && (~isApBW))
                    map(i+1) = i + frameSize/2 -1 ;
                elseif ((bottomOfFrame) && (isApBW))
                    map(i+1) = i - frameSize/2 +1;
                elseif ((bottomOfFrame) && (~isApBW))
                    map(i+1) = i;
                end
                
            else
                %                 if(radix4)
      config.source=str2func('fft_direct_draw_v2');
config.toplevel=gcb;
config.debug=0;
config.depend={'fft_direct_draw_v2.m'};
xBlock(config,{FFTSize,larger_fft_size,input_bit_width,coeff_bit_width,inter_stage_bit_width,output_bit_width,register_coeffs,delay_input,delay_output,sync_tree_input,optional_delay_arr,coeff_group_arr_in,coeff_stage_step_arr,shift_arr,arch,1,max_lowres_bit_width});          %                     map(i+1)=i;
                %                 else
                map(i+1) = bit_reverse(i, FFTSize);
                %                 end
            end
            
        end %end map generator... what a mess.

        map= map+1;
                if(radix4) %if radix4, then supplant the normal radix2 ordering for the "radix 4 exit final order"........
            map(1:2:2^FFTSize)=0:(2^FFTSize/2-1);
            map(2:2:2^FFTSize)=(2^FFTSize/2):(2^FFTSize-1);
            map_temp(map+1)=1:length(map);
            map=map_temp;
        end
        map_scr=[];
    end
    %% inter-stage delays
    delay_arr_beginning = zeros(1,2^FFTSize);
    
    delay_arr_end = zeros(1,2^FFTSize);
    if(~stage_radix4)
        if(stage_hires(FFTStage))
            delay_arr_end(1:2:(2^FFTSize)) = 1;
        else
        delay_arr_end(1:2:(2^FFTSize)) = 2;
        end
    end
    
    doingBeginningDelay = (~(stage_radix4 && (actual_FFTStage ~= FFTSize))  || leaving_radix4) && ~(~stage_radix4 && (actual_FFTStage == FFTSize));
    if(doingBeginningDelay)
        delay_arr_beginning(1:2:(2^FFTSize)) = 1;
    end
    
    delay_arr = delay_arr_beginning(:)' + delay_arr_end(map);
    if(optional_delay_arr_direct(FFTStage+1) > 0)
        delay_arr = delay_arr + 1;
        optional_delay_arr_direct(FFTStage+1) = optional_delay_arr_direct(FFTStage+1) -1;
    end
    
    
    %sStageDataOut = sStageDataOut{map};
    %if(FFTStage ~= FFTSize)
    if(1)
        for(i=1:(2^FFTSize))%we are trying to accomplish what the above line SHOULD do (it instead returns a single xSignal object)
            sStageDataOutNew{i} =  sStageDataOut{map(i)};
        end
    else
        sStageDataOutNew = sStageDataOut;
    end
    
    blockName = strcat('bulk_delay_', num2str(FFTStage) , '_1');
    sData = xBulkDelay(sStageDataOutNew, 2^FFTSize, delay_arr, blockName);
    
    %optional inter-stage delays
    for(i = (1:optional_delay_arr_direct(FFTStage+1)))
        delay_arr = ones(1,2^FFTSize);
        blockName = strcat('bulk_delay_', num2str(FFTStage) , '_', num2str(i+1));
        sData = xBulkDelay(sData, 2^FFTSize, delay_arr,blockName);
    end
    actual_FFTStage=actual_FFTStage+1+stage_radix4;
    FFTStage=FFTStage+1;
end

for(i=1:2^FFTSize)
    %    oData{i}.bind(sData{bit_reverse(i-1,FFTSize)+1});
    oData{i}.bind(sData{i});
end