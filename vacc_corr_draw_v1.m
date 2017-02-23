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


function vacc_corr_draw_v1(nPorts,acc_len,iter_len,nBits,in_bp,out_bits)
% 
% nPorts=4;
% acc_len=32;
% iter_len=10;
% nBits=24;
% in_bp=23;
% out_bits=24;
% 
% xBlock;


iSync=xInport('sync');
iAccLen=xInport('acc_len');
iAccRst=xInport('acc_rst');
iAAV=xInport('acc_always_valid');
    iMask=xInport('mask');


sValidOut=xSignal;
sAccFrameEnd=xSignal;
sVaccClear =xSignal;

oValidOut=xOutport('valid');
oAccFrameEnd=xOutport('accFrameEnd');

for i=1:nPorts
    iDin{i}=xInport(['din' num2str(i-1)]);
end
nCorrs=nPorts*(nPorts-1)/2;
% for i=1:nCorrs
%     oDout{i}=xOutport(['dout' num2str(i-1)]);    
% end

name = ['vacc_ctrl'];
xBlockThis = xBlock(struct('source', 'monroe_library/vacc_ctrl_freqacc', 'name', name), ...
    struct('iter_len', iter_len, ...
    'acc_len', acc_len));
xBlockThis.bindPort({iSync, iAccLen, iAccRst,iAAV,iMask}, ...
    {sValidOut, sAccFrameEnd, sVaccClear});
n=1;
for i=1:nPorts
    for j=1:nPorts
        if i>=j
            continue
        end
    sVC1=xDelay(sVaccClear,5,['vc' num2str(i) '_' num2str(j) '_' 'd1']);
    sVC2=xDelay(sVC1,1,['vc' num2str(i) '_' num2str(j) '_' 'd2']);
    
    oDout{i}=xOutport(['dout' num2str(i) '_' num2str(j)]);
    
    name = ['vacc_data_' num2str(i) '_' num2str(j)];
        blockType= 'monroe_library/vacc_data_forCorr';

        
       
    xBlockThis = xBlock(struct('source', blockType, 'name', name), ...
        struct('iter_len', iter_len, ...
        'out_bits', out_bits, ...
        'nBits', nBits, ...
        'bonus_delay', 2, ...
        'bin_pt', in_bp));
    xBlockThis.bindPort({iDin{i},iDin{j}, sVC2}, ...
        {oDout{n}});
    n=n+1;
    end
end

sAFE_d1=xDelay(sAccFrameEnd,1,'sAFE_d1');
sAFE_d2=xDelay(sAFE_d1,1,'sAFE_d2');

sVO_d1=xDelay(sValidOut,1,'sVO_d1');
sVO_d2=xDelay(sVO_d1,1,'sVO_d2');

oValidOut.bind(sVO_d2);
oAccFrameEnd.bind(sAFE_d2);


