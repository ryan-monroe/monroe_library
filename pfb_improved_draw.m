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


function pfb_improved_draw(pfbSize, nSimInputs,  nTaps , data_nBits, coeff_nBits, output_bitWidth, window_fn, bram_latency_coeff, bram_latency_delay, bin_width, end_scale_val, endDelay, cheap_sync, register_delay_counter, multi_delay_bram_share,  autoplace_mode, autoplace_optimize, pol_count, arch, double_delays)
%pfbSize: log2(nFFT)
%nSimInputs: log2(number of simultaneous inputs)
%nTaps: number of filter taps
%data_nBits: number of input data bits
%coeff_nBits: number of coeff bits
%output_bitWidth: #output bits
%window_fn: function used to window
%bram_latency_coeff: lag out of coeffs brams
%bram_latency_delay: lag out of delay brams
%bin_width: changes the width of the resultant PFB bins
%end_scale_val: does this even do anything anymore? IDK
%cheap_sync: modulus'es the sync pulse with the nFFT and then does the sync
%delay on that value
%endDelay: add a delay at the end
%register_delay_counter: add a register on the output of the delay counter,
%for high-fanout problems.
%multi_delay_bram_share: shares partial bits across brams for awesome HW
%savings
%autoplace_xxx: ignore
%dual_pol: duplicates all the logic (except maybe the coeffs?) for a
%dual-pol design
%double_delays: double the inter-tap delays for if this design is running
%at DDR

%pfb_fir_real drawer

%1. draw sync in/out
%2. draw inputs, outputs.  Store in an array so I can handle dynamic sizing
%3. draw tap pairs. As per pfb design plan

% 
% % %
% xBlock;
% %
% 
% data_nBits=8;
% coeff_nBits=18;
% pfbSize=13;
% nTaps=4;
% window_fn = 'blackman';
% bram_latency_coeff = 2;
% bram_latency_delay = 2;
% nSimInputs =0;
% bin_width = 1;
% output_bitWidth= 18;
% end_scale_val = 1;
% cheap_sync=0;
% endDelay=1;
% register_delay_counter = 1;
% multi_delay_bram_share = 1;
% pol_count=2;
% arch='vi';
% double_delays=0;
% % end comment block
disp('enter: pfb_improved_draw')

if(~exist('double_delays','var'))
    double_delays=0;
end

pathToBlock = 'path:pfb';


%check that everything is an ingeger:
if((~isInt([pfbSize, nSimInputs, nTaps, data_nBits,coeff_nBits, output_bitWidth,bram_latency_coeff,bram_latency_delay,end_scale_val,endDelay,cheap_sync,register_delay_counter])))
    strError = 'The following parameters must be integers: pfb_size, n_sim_inputs, n_taps, data_n_bits, data_bin_pt, coeff_n_bits, coeff_bin_pt, output_bit_width, bram_latency_coeff, bram_latency_delay, end_scale_val, endDelay, cheap_sync, register_delay_counter';
    throwError(strError);
    %check that everything is inside the allowed bounds
elseif(pfbSize < 0 || pfbSize > 20)
    strError = strcat('pfb_size must be an integer between 0 and 20 (inclusive); pfb_size= ', num2str(pfbSize));
    throwError(strError);
elseif(nSimInputs < 0 || nSimInputs > 6)
    strError = strcat('n_sim_inputs must be an integer between 0 and 6 (inclusive); n_sim_inputs= ', num2str(nSimInputs));
    throwError(strError);
elseif(data_nBits < 1 || data_nBits > 25)
    strError = strcat('data_n_bits must be an integer between 1 and 25 (inclusive); data_n_bits= ', num2str(data_nBits));
    throwError(strError);
elseif(coeff_nBits < 1 || coeff_nBits  > 18)
    strError = strcat('coeff_n_bits  must be an integer between 1 and 18 (inclusive); coeff_n_bits = ', num2str(coeff_nBits ));
    throwError(strError);
elseif(nTaps < 1 || nTaps  > 32)
    strError = strcat('n_taps  must be an integer between 1 and 16 (inclusive); n_taps = ', num2str(nTaps )); %this limit is somewhat arbitrary.  After 16 taps, the channel shape improvement is nil and the performance will be abysmal.  It's really just to help avoid long draw times.
    throwError(strError);
elseif(bram_latency_coeff ~=2 && bram_latency_coeff  ~= 3)
    strError = strcat('bram_latency_coeff  must be either 2 or 3; bram_latency_coeff = ', num2str(bram_latency_coeff ));
    throwError(strError);
elseif(bram_latency_delay ~=2 && bram_latency_delay  ~= 3)
    strError = strcat('bram_latency_delay  must be either 2 or 3; bram_latency_delay = ', num2str(bram_latency_delay ));
    throwError(strError);
elseif(endDelay ~=0 && endDelay  ~= 1)
    strError = strcat('endDelay  must be either 0 or 1; endDelay = ', num2str(endDelay ));
    throwError(strError);
elseif(cheap_sync ~=0 && cheap_sync  ~= 1)
    strError = strcat('cheap_sync  must be either 0 or 1; cheap_sync = ', num2str(cheap_sync ));
    throwError(strError);
elseif(register_delay_counter ~=0 && register_delay_counter  ~= 1)
    strError = strcat('register_delay_counter  must be either 0 or 1; register_delay_counter = ', num2str(register_delay_counter ));
    throwError(strError);
elseif(bin_width < 0)
    strError = strcat('bin_width must be non-negative; bin_width= ', num2str(bin_width));
    throwError(strError);
elseif(output_bitWidth < 1)
    strError = strcat('output_bit_width must be positive; output_bit_width= ', num2str(output_bitWidth));
    throwError(strError);
end



if(~exist('pol_count'))
    pol_count=1;
elseif pol_count==0
    pol_count==1;
end

arch_v6 = strcmp(arch,'virtex_6');

data_bin_pt = data_nBits-1;

coeff_bin_pt= coeff_nBits -1;

a_bind_index = 0;
b_bind_index = 0;


if (end_scale_val == -1)
    end_scale_val = nTaps/3;
end

vector_len = pfbSize - nSimInputs;

if(nTaps < 2)
    error('must have at least two taps.')
end

%generate inputs.  Someday, I'll have to make a sync tree for this

iSync= xInport('sync');
oSyncOut= xOutport('sync_out');


for pol=0:(pol_count-1)
    for(i= 1:2^nSimInputs)
        blockTemp=xInport(['pol' num2str(pol) '_in', num2str(i-1)]);
        iDataIn{i+2^nSimInputs*pol} = blockTemp;
        blockTemp= xOutport(['pol' num2str(pol) '_out', num2str(i-1)]);
        oTapOut{i+2^nSimInputs*pol} = blockTemp;
    end
end

bSyncTree = xBlock(struct('source', 'monroe_library/delay_tree_z^-6_0'),{}, {iSync}, ...
    {xSignal,xSignal,xSignal,xSignal,xSignal,xSignal,xSignal,xSignal, ...
    xSignal,xSignal,xSignal,xSignal,xSignal,xSignal,xSignal,xSignal, ...
    xSignal,xSignal,xSignal,xSignal,xSignal,xSignal,xSignal,xSignal, ...
    xSignal,xSignal,xSignal,xSignal,xSignal,xSignal,xSignal,xSignal});
sSyncTree = bSyncTree.getOutSignals();


iDataIn=xBulkDelay(iDataIn,length(iDataIn),1,'data_bulk_delay_1');
iDataIn=xBulkDelay(iDataIn,length(iDataIn),1,'data_bulk_delay_2');

sSyncTree=xBulkDelay(sSyncTree,length(sSyncTree),1,'sync_bulk_delay_1');
sSyncTree=xBulkDelay(sSyncTree,length(sSyncTree),1,'sync_bulk_delay_2');


%procedure for making filter pairs:
%1. make coefficient generator
%2. add first tap
%2.1. add dual bram delay for first tap
%3. add 2nd to n-1th tap (for loop)
%3.1 add each dual bram delay with that tap
%4. add nth tap
%5. add scale/converts
%6. add sync delay


%j = filter pair we are on
%k = tap inside filter we are on.
sDelayIn = {xSignal};
sDelayOut = {xSignal};

sCoeff0SyncOut = xSignal;




if(nSimInputs==0)
        %<<<<<<<<<<<<<BEGIN FILTER PAIR LOOP>>>>>>>>>>>>%
        sGenSync{1}=xSignal;
        sGenCoeff{1}=xSignal;
        
        blockName = strcat('coeff_gen_',num2str(1-1), '_', num2str(2^nSimInputs-1));
        blockTemp = xBlock(struct('source', str2func('pfb_coeff_gen_dual_draw'), 'name', blockName), ...
            {pfbSize,nSimInputs,nTaps,1-1,coeff_nBits,window_fn, 'Block RAM',bram_latency_coeff,bin_width});
        blockTemp.bindPort({sSyncTree{1}},{sGenSync{1},sGenCoeff{1}});
        
        
        if(1 == 1)
            sCoeff0SyncOut = sGenSync{1};
        end
        bGen(1) = blockTemp;
    
    
    
    for pol=0:(pol_count-1)
            %first tap
            stageNum=1;
            
            sTapACoeffOutPrevious = xSignal;
            sTapADataOutPrevious = xSignal;
            
            blockSource = 'monroe_library/first_tap_improved';
            if(arch_v6)
                blockSource = [blockSource '_v6'];
            end
            
            blockTemp = xBlock(struct('source',blockSource,'name',['filter_in',num2str(1-1), '_stage', num2str(stageNum) '_pol' num2str(pol)]),struct('data_bin_pt',data_bin_pt, 'coeff_bit_width',coeff_nBits));
            blockTemp.bindPort({iDataIn{1+2^nSimInputs*pol}, sGenCoeff{1}}, {sTapACoeffOutPrevious, sTapADataOutPrevious});
            
            
            if(1 == 1)
                for(kk= 1:((2*(nTaps-1))* (2^(nSimInputs-1))))
                    sDelayIn{kk}=xSignal;
                    sDelayOut{kk}=xSignal;
                end
                
                for(kk = 1:(2^(nSimInputs-1)))
                    
                    offset = (nTaps-1) * (kk-1)*2;
                    sDelayIn{1+offset} = iDataIn{kk+nTaps*pol};
                end
                
                delayLen=2^vector_len;
                if(double_delays)
                    delayLen=delayLen*2;
                end
                 
                blockName = ['multi_delay_bram_fast_', num2str(1-1) '_pol' num2str(pol)];
                
%                 if(length(sDelayIn)==1)
%                 bMultiDelay =  xBlock(struct('source', @multi_delay_bram_fast_draw, 'name', blockName), ...
%                     {nTaps-1,delayLen,data_nBits,data_bin_pt, ...
%                     'Signed',bram_latency_delay,register_delay_counter}, sDelayIn{1}, sDelayOut{1});
%                     
%                 else
                bMultiDelay =  xBlock(struct('source', @multi_delay_bram_fast_draw, 'name', blockName), ...
                    {nTaps-1,delayLen,data_nBits,data_bin_pt, ...
                    'Signed',bram_latency_delay,register_delay_counter}, sDelayIn, sDelayOut);
                    
%                 end
                sDelayIn{1}.bind(iDataIn{pol+1});
                
            end
            %make the other taps
            for(stageNum=2:(nTaps-1))
                %nth tap
                sTapACoeffOut= xSignal;
                sTapADataOut= xSignal;
                
                sDelayOut{stageNum-1}.bind(sDelayIn{stageNum});
                
                blockSource = 'monroe_library/middle_tap_improved';
                if(arch_v6)
                    blockSource = [blockSource '_v6'];
                end
                
                blockTemp =  xBlock(struct('source',blockSource,'name',['filter_in',num2str(1-1), '_stage', num2str(stageNum) '_pol' num2str(pol)]) ...
                    ,struct('data_bin_pt',data_bin_pt, 'coeff_bit_width',coeff_nBits, 'stage_num', stageNum), ...
                    {sDelayOut{stageNum-1}, sTapACoeffOutPrevious, sTapADataOutPrevious}, {sTapACoeffOut, sTapADataOut});
                
                sTapACoeffOutPrevious=sTapACoeffOut;
                sTapADataOutPrevious=sTapADataOut;
                
                
            end
            
            %all the taps but the last are now finished.  All the data delays are too.
            %Let's make that last tap.
            
            stageNum= nTaps;
            
            sTapACoeffOut(stageNum) = xSignal;
            
            blockSource = 'monroe_library/last_tap_improved';
            if(arch_v6)
                blockSource = [blockSource '_v6'];
            end
            
            bLastTapA = xBlock(struct('source',blockSource,'name',['filter_in',num2str(1-1), '_stage', num2str(stageNum) '_pol' num2str(pol)]) ...
                ,struct('data_bin_pt',data_bin_pt,'coeff_bin_pt', coeff_bin_pt, 'stage_num', stageNum));
            bLastTapA.bindPort({sDelayOut{stageNum-1}, sTapACoeffOutPrevious, sTapADataOutPrevious}, {xSignal});
            sTapADataOut_ca=bLastTapA.getOutSignals();
            sTapADataOut=sTapADataOut_ca{1};
            
            
            
            
            sScaleA= xSignal;
            blockTemp =  xBlock('Scale', struct('scale_factor', -1* ceil(end_scale_val) ), {sTapADataOut} , {sScaleA});
            
            
            blockName = ['reinterpret_', num2str(1-1) '_pol' num2str(pol)];
            sReinterpretA =sScaleA;
            
            xlsub2_Convert1 = xBlock(struct('source', 'Convert'), ...
                struct('n_bits', output_bitWidth, ...
                'bin_pt', output_bitWidth-1, ...
                'latency', endDelay), ...
                {sReinterpretA}, ...
                {oTapOut{1+2^nSimInputs*pol}});
            
            
            
            
            
    end %end pol loop
else
    
    for filterPairNum=1:(2^(nSimInputs-1))
        %<<<<<<<<<<<<<BEGIN FILTER PAIR LOOP>>>>>>>>>>>>%
        sGenSync{filterPairNum}=xSignal;
        sGenCoeff{filterPairNum}=xSignal;
        sGenCoeffRev{filterPairNum}=xSignal;
        num_sim_inputs = nSimInputs;
        
        blockName = strcat('coeff_gen_',num2str(filterPairNum-1), '_', num2str(2^nSimInputs-filterPairNum));
        blockTemp = xBlock(struct('source', str2func('pfb_coeff_gen_dual_draw'), 'name', blockName), ...
            {pfbSize,nSimInputs,nTaps,filterPairNum-1,coeff_nBits,window_fn, 'Block RAM',bram_latency_coeff,bin_width});
        blockTemp.bindPort({sSyncTree{filterPairNum}},{sGenSync{filterPairNum},sGenCoeff{filterPairNum},sGenCoeffRev{filterPairNum}});
        
        
        if(filterPairNum == 1)
            sCoeff0SyncOut = sGenSync{filterPairNum};
        end
        bGen(filterPairNum) = blockTemp;
    end %end coeff gen loop
    
    for pol=0:(pol_count-1)
        for filterPairNum=1:(2^(nSimInputs-1))
            
            %first tap
            stageNum=1;
            
            sTapACoeffOutPrevious = xSignal;
            sTapADataOutPrevious = xSignal;
            
            sTapBCoeffOutPrevious = xSignal;
            sTapBDataOutPrevious = xSignal;
            
            blockSource = 'monroe_library/first_tap_improved';
            if(arch_v6)
                blockSource = [blockSource '_v6'];
            end
            
            blockTemp = xBlock(struct('source',blockSource,'name',['filter_in',num2str(filterPairNum-1), '_stage', num2str(stageNum) '_pol' num2str(pol)]),struct('data_bin_pt',data_bin_pt, 'coeff_bit_width',coeff_nBits));
            blockTemp.bindPort({iDataIn{filterPairNum+2^nSimInputs*pol}, sGenCoeff{filterPairNum}}, {sTapACoeffOutPrevious, sTapADataOutPrevious});
            
            blockTemp = xBlock(struct('source',blockSource,'name',['filter_in',num2str(2^nSimInputs-filterPairNum), '_stage', num2str(stageNum) '_pol' num2str(pol)]),struct('data_bin_pt',data_bin_pt, 'coeff_bit_width',coeff_nBits), ...
                {iDataIn{(2^nSimInputs)-filterPairNum+1+2^nSimInputs*pol}, sGenCoeffRev{filterPairNum}},{sTapBCoeffOutPrevious, sTapBDataOutPrevious});
            
            
            
            
            if(filterPairNum == 1)
                for(kk= 1:((2*(nTaps-1))* (2^(nSimInputs-1))))
                    sDelayIn{kk}=xSignal;
                    sDelayOut{kk}=xSignal;
                end
                
                for(kk = 1:(2^(nSimInputs-1)))
                    
                    offset = (nTaps-1) * (kk-1)*2;
                    sDelayIn{1+offset} = iDataIn{kk+2^nSimInputs*pol};
                    sDelayIn{2+offset} = iDataIn{2^nSimInputs-kk+1+2^nSimInputs*pol};
                end
                
                delayLen=2^vector_len;
                if(double_delays)
                    delayLen=delayLen*2;
                end
                
                blockName = ['multi_delay_bram_fast_', num2str(filterPairNum-1) '_pol' num2str(pol)];
                bMultiDelay =  xBlock(struct('source', @multi_delay_bram_fast_draw, 'name', blockName), ...
                    {(2*(nTaps-1))*(2^(nSimInputs-1)),delayLen,data_nBits,data_bin_pt, ...
                    'Signed',bram_latency_delay,register_delay_counter}, sDelayIn, sDelayOut);
%                 
%                 iDataIn{pol*2^nSimInputs+filterPairNum}.bind(sDelayIn{1});
%                 iDataIn{(pol+1)*2^nSimInputs-filterPairNum+1}.bind(sDelayIn{2});
%         
%                 sDelayIn{1}.bind(iDataIn{pol*2^nSimInputs+filterPairNum});
%                 sDelayIn{2}.bind(iDataIn{(pol+1)*2^nSimInputs-filterPairNum+1});
            end
            %make the other taps
            for(stageNum=2:(nTaps-1))
                %nth tap
                sTapACoeffOut= xSignal;
                sTapADataOut= xSignal;
                
                sTapBCoeffOut = xSignal;
                sTapBDataOut = xSignal;
                
                if(multi_delay_bram_share == 0)
                    a_bind_index = 2*(stageNum-1) - 1;
                    b_bind_index = 2*(stageNum-1);
                else
                    offset = (nTaps-1) * (filterPairNum-1)*2;
                    a_bind_index = 2*(stageNum-1) - 1 + offset;
                    b_bind_index = 2*(stageNum-1) + offset;
                end
                sDelayOut{a_bind_index}.bind(sDelayIn{a_bind_index+2});
                sDelayOut{b_bind_index}.bind(sDelayIn{b_bind_index+2});
                
                
                
                
                blockSource = 'monroe_library/middle_tap_improved';
                if(arch_v6)
                    blockSource = [blockSource '_v6'];
                end
                
                blockTemp =  xBlock(struct('source',blockSource,'name',['filter_in',num2str(filterPairNum-1), '_stage', num2str(stageNum) '_pol' num2str(pol)]) ...
                    ,struct('data_bin_pt',data_bin_pt, 'coeff_bit_width',coeff_nBits, 'stage_num', stageNum), ...
                    {sDelayOut{a_bind_index}, sTapACoeffOutPrevious, sTapADataOutPrevious}, {sTapACoeffOut, sTapADataOut});
                
                
                blockTemp =  xBlock(struct('source',blockSource,'name',['filter_in',num2str(2^nSimInputs-filterPairNum), '_stage', num2str(stageNum) '_pol' num2str(pol)]) ...
                    ,struct('data_bin_pt',data_bin_pt, 'coeff_bit_width',coeff_nBits, 'stage_num', stageNum), ...
                    {sDelayOut{b_bind_index}, sTapBCoeffOutPrevious, sTapBDataOutPrevious}, {sTapBCoeffOut, sTapBDataOut});
                
                sTapACoeffOutPrevious=sTapACoeffOut;
                sTapBCoeffOutPrevious=sTapBCoeffOut;
                sTapADataOutPrevious=sTapADataOut;
                sTapBDataOutPrevious=sTapBDataOut;
                
                
            end %other tap loop
            
            %all the taps but the last are now finished.  All the data delays are too.
            %Let's make that last tap.
            
            stageNum= nTaps;
            
            sTapACoeffOut(stageNum) = xSignal;
            sTapADataOut(stageNum) = xSignal;
            
            sTapBCoeffOut(stageNum) = xSignal;
            sTapBDataOut(stageNum) = xSignal;
            
            
            if(multi_delay_bram_share == 0)
                a_bind_index = 2*(stageNum-1) - 1;
                b_bind_index = 2*(stageNum-1);
            else
                offset = (nTaps-1) * (filterPairNum-1)*2;
                a_bind_index = 2*(stageNum-1) - 1 + offset;
                b_bind_index = 2*(stageNum-1) + offset;
                
                
            end
            
            blockSource = 'monroe_library/last_tap_improved';
            if(arch_v6)
                blockSource = [blockSource '_v6'];
            end
            
            bLastTapA = xBlock(struct('source',blockSource,'name',['filter_in',num2str(filterPairNum-1), '_stage', num2str(stageNum) '_pol' num2str(pol)]) ...
                ,struct('data_bin_pt',data_bin_pt,'coeff_bin_pt', coeff_bin_pt, 'stage_num', stageNum));
            
            bLastTapA.bindPort({sDelayOut{a_bind_index}, sTapACoeffOutPrevious, sTapADataOutPrevious}, {xSignal});
            sTapADataOut_ca=bLastTapA.getOutSignals();
            sTapADataOut=sTapADataOut_ca{1};
            
            
            bLastTapB= xBlock(struct('source',blockSource,'name',['filter_in',num2str(2^nSimInputs-filterPairNum), '_stage', num2str(stageNum) '_pol' num2str(pol)]) ...
                ,struct('data_bin_pt',data_bin_pt,'coeff_bin_pt', coeff_bin_pt, 'stage_num', stageNum));
            bLastTapB.bindPort({sDelayOut{b_bind_index}, sTapBCoeffOutPrevious, sTapBDataOutPrevious}, {xSignal});
            sTapBDataOut_ca=bLastTapB.getOutSignals();
            sTapBDataOut=sTapBDataOut_ca{1};
            
            
            
            
            
            sScaleA= xSignal;
            sScaleB = xSignal;
            
            blockTemp =  xBlock('Scale', struct('scale_factor', -1* ceil(end_scale_val) ), {sTapADataOut} , {sScaleA});
            
            blockTemp =  xBlock('Scale', struct('scale_factor', -1* ceil(end_scale_val)) , {sTapBDataOut} , {sScaleB});
            
            
            
            
            blockName = ['reinterpret_', num2str(filterPairNum-1) '_pol' num2str(pol)];
            sReinterpretA =sScaleA;
            
            blockName = ['reinterpret_', num2str(2^nSimInputs - (filterPairNum-1)) '_pol' num2str(pol)];
            sReinterpretB =sScaleB;
            
            xlsub2_Convert1 = xBlock(struct('source', 'Convert'), ...
                struct('n_bits', output_bitWidth, ...
                'bin_pt', output_bitWidth-1, ...
                'latency', endDelay), ...
                {sReinterpretA}, ...
                {oTapOut{filterPairNum+2^nSimInputs*pol}});
            
            
            xlsub2_Convert1 = xBlock(struct('source', 'Convert'), ...
                struct('n_bits', output_bitWidth, ...
                'bin_pt', output_bitWidth-1, ...
                'latency', endDelay), ...
                {sReinterpretB}, ...
                {oTapOut{(2^num_sim_inputs)-filterPairNum+1+2^nSimInputs*pol}});
            
            
            
            
        end %<<<<<<<<<<<<<END FILTER PAIR LOOP>>>>>>>>>>>>%
    end %end pol loop
end %end if(n_sim_inputs==0)


oSyncOut1 = xOutport('sync_out1');

if( cheap_sync == 1)
    %this line for a cheaper sync delay.  OK if all your hardware elements run
    %with periods at subdivisions of your vector length (they probably do)
    sSyncOut0 = xDelay(iSync, endDelay + nTaps + 2, 'sync_delay_end0');
    sSyncOut1 = xDelay(iSync, endDelay + nTaps + 2, 'sync_delay_end1');
    oSyncOut.bind(sSyncOut0);
    oSyncOut1.bind(sSyncOut1);
else
    %this line for an "honest" sync delay.  More hardware expensive'
    delayLen = endDelay + (nTaps +2) + ((2^vector_len)*(nTaps-1))  -8;
    sSyncDl_0 = sCoeff0SyncOut;
    sSyncDl_1 = sGenSync{end};
    
    sSyncDlFast_0 = xSignal;
    sSyncDlFast_1 = xSignal;
    
    
    sSyncDl_0 = xDelay(sSyncDl_0,1,'syncDL_0_1');
    sSyncDl_0 = xDelay(sSyncDl_0,1,'syncDL_0_2');
    sSyncDl_0 = xDelay(sSyncDl_0,1,'syncDL_0_3');
    sSyncDl_1 = xDelay(sSyncDl_1,1,'syncDL_1_1');
    sSyncDl_1 = xDelay(sSyncDl_1,1,'syncDL_1_2');
    sSyncDl_1 = xDelay(sSyncDl_1,1,'syncDL_1_3');
    
     
%     bSyncDelay = xBlock('monroe_library/sync_delay_fast', struct('delay_len', delayLen, {sSyncDl_0},   {oSyncOut} );
%     bSyncDelay = xBlock('monroe_library/sync_delay_fast', struct('delay_len', delayLen, {sSyncDl_1} ,  {oSyncOut1});
    
    bSyncDelay = xBlock('monroe_library/sync_delay_fast', struct('delay_len', delayLen-6), {sSyncDl_0},   {sSyncDlFast_0});
    bSyncDelay = xBlock('monroe_library/sync_delay_fast', struct('delay_len', delayLen-6), {sSyncDl_1} ,  {sSyncDlFast_1});
    
    sSyncDl_0 = xDelay(sSyncDlFast_0,1,'syncDL_0_4');
    sSyncDl_0 = xDelay(sSyncDl_0,1,'syncDL_0_5');
    sSyncDl_0 = xDelay(sSyncDl_0,1,'syncDL_0_6');
    
    sSyncDl_1 = xDelay(sSyncDlFast_1,1,'syncDL_1_4');
    sSyncDl_1 = xDelay(sSyncDl_1,1,'syncDL_1_5');
    sSyncDl_1 = xDelay(sSyncDl_1,1,'syncDL_1_6');
    
    oSyncOut.bind (sSyncDl_0);
    oSyncOut1.bind(sSyncDl_1);
    
    
end

disp('exit: pfb_improved_draw')
