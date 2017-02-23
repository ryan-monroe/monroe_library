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


function bitwise_mux_draw(bits)


%% inports
iIn0 = xInport('in0');
iIn1 = xInport('in1');
iSel = xInport('sel');

%% outports
oNor = xOutport('out');
%% diagram

ind=1;
for i=1:bits
    signals_mux_in0{i}=xSlice(iIn0,1,'lower',i-1,['slice_in0_' num2str(i)]);
    signals_mux_in1{i}=xSlice(iIn1,1,'lower',i-1,['slice_in1_' num2str(i)]);
    signals_mux_sel{i}=xSlice(iSel,1,'lower',i-1,['slice_sel_' num2str(i)]);
    
    oNorConcat{i}=xSignal;
    blockTemp=xBlock('Mux',{},{signals_mux_sel{i},signals_mux_in0{i},signals_mux_in1{i}},{oNorConcat{i}});
%     ind=ind+1;
end

oNorBind = xConcat(oNorConcat(end:-1:1),'out_concat');
oNor.bind(oNorBind);
