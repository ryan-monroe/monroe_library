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


function vacc_draw_v3(nPorts,acc_len,iter_len,in_bp,out_bits,arch, bitSelectOn)
% 
% nPorts=2;
% acc_len=32;
% iter_len=10;
% in_bp=20;
% out_bits=48;
% arch=123;
% bitSelectOn=1;

if(~exist('bitSelectOn','var'))
    bitSelectOn=0;
end
% xBlock;
iSync=xInport('sync');
iAccLen=xInport('acc_len');
iAccRst=xInport('acc_rst');
iAAV=xInport('acc_always_valid');
if(bitSelectOn)
    iMask=xInport('mask');
end

sValidOut=xSignal;
sAccFrameEnd=xSignal;
sVaccClear =xSignal;

oValidOut=xOutport('valid');
oAccFrameEnd=xOutport('accFrameEnd');

for i=1:nPorts
    iDin{i}=xInport(['din' num2str(i-1)]);
    oDout{i}=xOutport(['dout' num2str(i-1)]);
end

name = ['vacc_ctrl'];
if(bitSelectOn)
xBlockThis = xBlock(struct('source', 'monroe_library/vacc_ctrl_freqacc', 'name', name), ...
    struct('iter_len', iter_len, ...
    'acc_len', acc_len));
xBlockThis.bindPort({iSync, iAccLen, iAccRst,iAAV,iMask}, ...
    {sValidOut, sAccFrameEnd, sVaccClear});
else
xBlockThis = xBlock(struct('source', 'monroe_library/vacc_ctrl', 'name', name), ...
    struct('iter_len', iter_len, ...
    'acc_len', acc_len));
xBlockThis.bindPort({iSync, iAccLen, iAccRst,iAAV}, ...
    {sValidOut, sAccFrameEnd, sVaccClear});
    
end
for i=1:nPorts
    sVC1=xDelay(sVaccClear,1,['vc' num2str(i) 'd1']);
    sVC2=xDelay(sVC1,1,['vc' num2str(i) 'd2']);
    
    
    
    name = ['vacc_data' num2str(i-1)];
    if(bitSelectOn)
         blockType= 'monroe_library/vacc_data_opmodes';
    elseif(out_bits<=48)
       blockType= 'monroe_library/vacc_data';
    else
        blockType= 'monroe_library/vacc_data_96b';
    end
    xBlockThis = xBlock(struct('source', blockType, 'name', name), ...
        struct('iter_len', iter_len, ...
        'out_bits', out_bits, ...
        'bonus_delay', 2, ...
        'bin_pt', in_bp));
    xBlockThis.bindPort({iDin{i}, sVC2}, ...
        {oDout{i}});
end

sAFE_d1=xDelay(sAccFrameEnd,1,'sAFE_d1');
sAFE_d2=xDelay(sAFE_d1,1,'sAFE_d2');

sVO_d1=xDelay(sValidOut,1,'sVO_d1');
sVO_d2=xDelay(sVO_d1,1,'sVO_d2');

oValidOut.bind(sVO_d2);
oAccFrameEnd.bind(sAFE_d2);


