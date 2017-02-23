function dct_unscrambler_dual_draw(dctSize,  bit_width, register_output)

% xBlock;
% 
% dctSize = 19;
% register_output = 0;
%  bit_width = 18;
 
 iSync=xInport('sync_in');
iDin=xInport('din');
oSync=xOutport('sync_out');
oDout0=xOutport('dout');
oDout1=xOutport('dout_rev');
 

 blockTemp = xBlock(struct('source', str2func('dct_unscrambler_draw'), 'name','dctUncrambler0'), ...
        {dctSize,bit_width,register_output,0});
    blockTemp.bindPort({iSync, iDin}, {oSync, oDout0});
    
    sTemp=xSignal;
    blockTemp = xBlock(struct('source', str2func('dct_unscrambler_draw'), 'name','dctUncrambler1'), ...
        {dctSize,bit_width,register_output,1});
    blockTemp.bindPort({iSync, iDin}, {sTemp, oDout1});
    
    