function coeff_gen_power_series_external_counter(FFTSize,  bit_width, step_rate, register_output, bitReverseCoeffs, fullCircle,doGCM)
% 
% xBlock;
% 
% FFTSize = 21;
% FFTStage=21;
% register_output = 0;
%  bit_width = 18;
%  step_rate = FFTSize-FFTStage;
%  bitReverseCoeffs=0;
%  fullCircle=1;
%  doGCM=1;

%
%the goal of this block is to reduce the size of very large coefficient
%buffers.  We do that by splitting memories up into a 'coarse' phase memory
%and a 'fine' phase memory.  The lower bits address one memory, the upper
%bits address the other.  If we're talking about a FFT, we'll toss in a
%bitwise address reversal to represent the change in order.

if(~exist('fullCircle','var'))
    fullCircle=0;
end


if(~exist('doGCM','var'))
    doGCM=0;
end

FFTStageNum = FFTSize-step_rate;
addrBits = FFTStageNum-1;

iAddr = xInport('count_in');
oCoeff = xOutport('coeff');

%first, slice out the relevant bits:
sAddrSlice = xSlice(iAddr,addrBits,'upper',0,'slice_addr');

%optionally reverse bits
if bitReverseCoeffs
    sAddrBRO=xSignal;
    blockTemp = xBlock(struct('source', str2func('bit_reverse_draw_v2'), 'name','addr_bitRev'), ...
        {addrBits,0});
    blockTemp.bindPort({sAddrSlice}, {sAddrBRO});
else
    sAddrBRO = sAddrSlice;
end

bitsUpper = floor(addrBits/2);
bitsLower = addrBits-bitsUpper;

if(~fullCircle)
    coeffAll = bitrevorder(biplex_coeff_gen_calc(FFTSize,FFTStageNum));
else
    coeffAll=exp(1j*(0:(2^(FFTSize-1)-1))*2*pi/((2^(FFTSize-1))));
end
coeffUpper = coeffAll(1:(2^bitsLower):end);
coeffLower = coeffAll(1:(2^bitsLower));

coeffPackUpper = [imag(coeffUpper) real(coeffUpper)];
coeffPackLower = [imag(coeffLower) real(coeffLower)];

sCoeffUpper = xSignal;
sCoeffLower = xSignal;

sCoeffUpperAddr = xSlice(sAddrBRO,bitsUpper,'upper',0,'sliceAddrUpper');
sCoeffLowerAddr = xSlice(sAddrBRO,bitsLower,'lower',0,'sliceAddrLower');
blockName='coeffUpper';
blockTemp = xBlock(struct('source', str2func('coeff_gen_dual_external_counter_draw_v2'), 'name',blockName), ...
    {coeffPackUpper, 'Block RAM', bit_width,step_rate, register_output});
blockTemp.bindPort({sCoeffUpperAddr}, {sCoeffUpper});

blockName='coeffLower';
blockTemp = xBlock(struct('source', str2func('coeff_gen_dual_external_counter_draw_v2'), 'name',blockName), ...
    {coeffPackLower, 'Block RAM', bit_width,step_rate, register_output});
blockTemp.bindPort({sCoeffLowerAddr}, {sCoeffLower});


sMultOut = xSignal;
sCoeffR = xSignal;
sCoeffI = xSignal;

% sBool0=xConstBool(0,'dummy_bool');
% sDummyOut = xSignal;
% blockName='coeffMultiply';
% blockTemp = xBlock('monroe_library/GCM_fast_z_-6', struct('b_n_bits',bit_width,'b_bin_pt',bit_width-2,'w_n_bits',bit_width,'w_bin_pt',bit_width-1));
% blockTemp.bindPort({sCoeffUpper, sCoeffLower, sBool0}, {sDummyOut,sMultOut});


sBool0=xConstBool(0,'dummy_bool');
% sVal0=xConstVal(0,'signed',36,0,'dummy_val');
% sDummyOut = xSignal;

blockName='coeffMultiply';
if(doGCM)
sGCM_out=xSignal;
sGCM_r=xSignal;
sGCM_i=xSignal;
sGCM_rc=xSignal;
sGCM_ic=xSignal;

    blockTemp = xBlock('monroe_library/GCM_fast_z_-6', ...
    struct('b_n_bits',18,'b_bin_pt',16,'w_n_bits',bit_width,'w_bin_pt',bit_width-2));
blockTemp.bindPort({sCoeffUpper,sCoeffLower,sBool0}, {xSignal,sGCM_out});


blockName='coeff_c2ri';
blockTemp = xBlock('monroe_library/c_to_ri', struct('n_bits',48,'bin_pt',39));
blockTemp.bindPort({sGCM_out}, {sGCM_r,sGCM_i});

blockTemp = xBlock('Convert', struct('arith_type','Signed','n_bits',bit_width,'bin_pt',bit_width-1));
blockTemp.bindPort({sGCM_r}, {sGCM_rc});
blockTemp = xBlock('Convert', struct('arith_type','Signed','n_bits',bit_width,'bin_pt',bit_width-1));
blockTemp.bindPort({sGCM_i}, {sGCM_ic});

sCoeffOut=xCram({sGCM_rc,sGCM_ic},'cram_coeff');
oCoeff.bind(sCoeffOut);
else
    
blockTemp = xBlock('monroe_library/cmult_v6', ...
    struct('a_n_bits',18,'a_bin_pt',16,'b_n_bits',bit_width,'b_bin_pt',bit_width-2,'w_n_bits',bit_width,'w_bin_pt',bit_width-2,'a_delay',1,'apbw_delay',1,'out_n_bits',bit_width,'out_bin_pt',bit_width-2,'downshift_at_end',0,'stage',1,'scale',0));
blockTemp.bindPort({sCoeffUpper,sCoeffLower,sBool0}, {oCoeff});
end

%
%
% blockName='coeff_c2ri';
% blockTemp = xBlock('monroe_library/c_to_ri', struct('n_bits',bit_width,'bin_pt',bit_width-2));
% blockTemp.bindPort({sMultOut}, {sCoeffR,sCoeffI});
%
% sCoeffR_conv = xSignal;
% sCoeffI_conv = xSignal;

%change the values here to flexible ones eventually.  For now, this will
%do.
% blockTemp = xBlock('Convert', struct('arith_type','Signed','n_bits',48,'bin_pt',39,'quantization','Round  (unbiased: Even Values)'));
% blockTemp.bindPort({sCoeffR}, {sCoeffR_conv});
%
% blockTemp = xBlock('Convert', struct('arith_type','Signed','n_bits',bit_width,'bin_pt',bit_width-2,'quantization','Round  (unbiased: Even Values)'));
% blockTemp.bindPort({sCoeffI}, {sCoeffI_conv});
%
% blockTemp = xBlock('monroe_library/ri_to_c');
% blockTemp.bindPort({sCoeffR_conv,sCoeffI_conv}, {oCoeff});
