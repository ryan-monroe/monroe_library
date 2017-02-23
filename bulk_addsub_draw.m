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


function bulk_addsub_draw(numInputs, width_in, subtract)
% xBlock;
% 
% numInputs = 2;
% width_in=18;
% subtract=0;

iSync=  xInport('sync');
sSync=xDelay(iSync,4,'delay_sync');
oSync=xOutport('sync_out');
oSync.bind(sSync);

iDat0=xInport('din0');
iDat1=xInport('din1');

oDat=xOutport('dout');


for(i = 1:(numInputs*2))
    sIn0{i} = xSignal;
    sIn1{i} = xSignal;
    sConv0{i} = xSignal;
    sConv1{i} = xSignal;
    
    sUncramPostAdd{i} = xSignal;
    sConvPostAdd{i} = xSignal;
    
end

for(i=1:numInputs)
    sAddOut{i}=xSignal;
    sFauxPcin{i}=xSignal;
end

sZero=xConstBool(0,'const_zero');

blockName = strcat('uncram_in0');
blockTemp = xBlock(struct('source', str2func('uncram_draw'), 'name', blockName), ...
    {numInputs*2, width_in, width_in-1, 'signed'});
blockTemp.bindPort({iDat0},sIn0);



blockName = strcat('uncram_in1');
blockTemp = xBlock(struct('source', str2func('uncram_draw'), 'name', blockName), ...
    {numInputs*2, width_in, width_in-1, 'signed'});
blockTemp.bindPort({iDat1},sIn1);

for(i=(numInputs-1):-1:0)
    %wiring this so that the addsubs at the top are 0 and at the bottom are numInputs-1.
    %This makes it easier to read once the blocks are placed and everything
    
    name_conv_0r=['convIn0_' num2str(i) 'r'];
    name_conv_0i=['convIn0_' num2str(i) 'i'];
    name_conv_1r=['convIn1_' num2str(i) 'r'];
    name_conv_1i=['convIn1_' num2str(i) 'i'];
    
    blockTemp = xBlock(struct('source', 'Convert', 'name', name_conv_0r), ...
        struct('n_bits', 24,'bin_pt',23,'arith_type','Signed'), ...
        sIn0(2*i+1), sConv0(2*i+1));
    
    blockTemp = xBlock(struct('source', 'Convert', 'name', name_conv_0i), ...
        struct('n_bits', 24,'bin_pt',23,'arith_type','Signed'), ...
        sIn0(2*i+2), sConv0(2*i+2));
    
    blockTemp = xBlock(struct('source', 'Convert', 'name', name_conv_1r), ...
        struct('n_bits', 24,'bin_pt',23,'arith_type','Signed'), ...
        sIn1(2*i+1), sConv1(2*i+1));
    
    blockTemp = xBlock(struct('source', 'Convert', 'name', name_conv_1i), ...
        struct('n_bits', 24,'bin_pt',23,'arith_type','Signed'), ...
        sIn1(2*i+2), sConv1(2*i+2));
    %
    
    name_cram0=['cram_conv0_' num2str(i)];
    sCram0{i+1}=xCram([sConv0(2*i+1), sConv0(2*i+2)], name_cram0);
    name_cram1=['cram_conv1_' num2str(i)];
    sCram1{i+1}=xCram([sConv1(2*i+1), sConv1(2*i+2)], name_cram1);
    
    name_addSub=['addSub0_' num2str(i)];
    
    if(i==(numInputs-1))
        blockTemp = xBlock(struct('source', 'monroe_library/dsp_add_dual_z^-2', 'name', name_addSub), ...
            struct('subtract', subtract), ...
            [sCram0(i+1), sCram1(i+1), {sZero} ], ...
            [sAddOut(i+1), sFauxPcin(i+1),{xSignal}]);
    else
        blockTemp = xBlock(struct('source', 'monroe_library/dsp_add_dual_z^-2_faux_pcin', 'name', name_addSub), ...
            struct('subtract', subtract), ...
            [sCram0(i+1), sCram1(i+1), {sZero}, sFauxPcin(i+2) ], ...
            [sAddOut(i+1), sFauxPcin(i+1),{xSignal}]);
    end
    
    blockName = ['uncram_out_' num2str(i)];
    blockTemp = xBlock(struct('source', str2func('uncram_draw'), 'name', blockName), ...
        {2, 24,23, 'signed'});
    blockTemp.bindPort(sAddOut(i+1),sUncramPostAdd((2*i+1):(2*i+2)));
    
    
    
    
    name_conv_postAdd_r=['convOut_' num2str(i) 'r'];
    blockTemp = xBlock(struct('source', 'Convert', 'name', name_conv_postAdd_r), ...
        struct('n_bits', width_in,'bin_pt',width_in-1,'arith_type','Signed','quantization','Round  (unbiased: Even Values)','latency',2,'pipeline','on'), ...
        sUncramPostAdd(2*i+1), sConvPostAdd(2*i+1));
    
    name_conv_postAdd_i=['convOut_' num2str(i) 'i'];
    blockTemp = xBlock(struct('source', 'Convert', 'name', name_conv_postAdd_i), ...
        struct('n_bits', width_in,'bin_pt',width_in-1,'arith_type','Signed','quantization','Round  (unbiased: Even Values)','latency',2,'pipeline','on'), ...
        sUncramPostAdd(2*i+2), sConvPostAdd(2*i+2));
    
    
end
name_cramOut='cram_out';
sCram0ut=xCram(sConvPostAdd, name_cramOut);
oDat.bind(sCram0ut);
