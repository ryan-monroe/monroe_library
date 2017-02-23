function dct_unscrambler_draw(dctSize,  bit_width, register_output,second_half_spectrum)
% 
% xBlock;
% 
% dctSize = 19;
% register_output = 0;
%  bit_width = 18;
%  second_half_spectrum=1;
% %  
%the goal of this block is to reduce the size of very large coefficient
%buffers.  We do that by splitting memories up into a 'coarse' phase memory
%and a 'fine' phase memory.  The lower bits address one memory, the upper
%bits address the other.  If we're talking about a FFT, we'll toss in a
%bitwise address reversal to represent the change in order.

iSync=xInport('sync_in');
iDin=xInport('din');
oSync=xOutport('sync_out');
oDout=xOutport('dout');

coeff_bit_width=min(bit_width,18);

sCountIn=xSignal;
sCoeffOut=xSignal;
%systemLag=8;
systemLag=0;

if(second_half_spectrum)
    countStart=mod(2^dctSize/2-systemLag-3,2^dctSize/2);
    op='Down';
else
    countStart=systemLag+1;
    op='Up';
end

sCountOut=xSignal;
bCountUp = xBlock('Counter', struct('cnt_type', 'Free Running', 'operation', op, 'start_count',...
    countStart, 'cnt_by_val', 1, 'arith_type', 'Unsigned', 'n_bits', dctSize-1, 'bin_pt', 0, 'load_pin', 'off',...
    'rst', 'on', 'en', 'off', 'period', 1, 'explicit_period', 'on', 'implementation', 'Fabric'), ...
        {iSync}, {sCountOut});


sConst0=xConstBool(0,'constZero');
sConstDir=xConstBool(second_half_spectrum,'constDir');
sCountIn=xCram({sConst0,sConstDir, sCountOut},'cramCount');
 blockTemp = xBlock(struct('source', str2func('coeff_gen_power_series_external_counter'), 'name','coeffGen'), ...
        {dctSize+2,coeff_bit_width,0,register_output,0});
    blockTemp.bindPort({sCountIn}, {sCoeffOut});

sSyncDelay=xDelay(iSync,8,'sync_delay');
sSyncOut=xSignal;

if(~second_half_spectrum)
    sDinDl=xDelay(iDin,8,'din_delay');
else
    sDinConj=xSignal;
    bSyncDelay = xBlock('monroe_library/complex_conj_dual_z^-2_v6', ...
        struct('input_bit_width', bit_width,'input_bin_pt', bit_width-2), ...
        {iDin, iDin}, {sDinConj});
    sDinDl=xDelay(sDinConj,5,'din_delay');
end
blockName='dataMultiply';
blockTemp = xBlock('monroe_library/cmult_v6', ...
    struct('a_n_bits',bit_width,'a_bin_pt',bit_width-2,'b_n_bits',bit_width,'b_bin_pt',bit_width-2,'w_n_bits',coeff_bit_width,'w_bin_pt',coeff_bit_width-2,'a_delay',1,'apbw_delay',1,'out_n_bits',bit_width,'out_bin_pt',bit_width-2,'downshift_at_end',0,'stage',1,'scale',0));
blockTemp.bindPort({sDinDl,sCoeffOut,sSyncDelay}, {oDout,sSyncOut});
oSync.bind(sSyncOut);
