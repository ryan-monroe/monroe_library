function correlator_freq_domain_tracker_draw(vector_count, bit_width_data, bit_width_coeff, phase_resolution)

% xBlock;
% vector_count=2;
% vector_len=10;
% bit_width_data=18;
% bit_width_coeff=18;
% phase_resolution=18;
% %this block tracks the geometric delays of an interferometer element, using
%linear interpolation.  In addition, it translates those to phases on a
%per-channel basis, computes the complex value equivalent to a unit-vector
%of that phase, and multiplies it by the input signal.



iSync= xInport('sync_in');
i1pps= xInport('one_pps');
iCoeff0= xInport('coeff0');
iCoeff1=  xInport('coeff1');
iCoeff2= xInport('coeff2');
iCoeffPhase= xInport('coeff_phase');
iCountStart= xInport('count_start');

iUpdateCoeffs=  xInport('update_coeff');
i1ppsPending=  xInport('one_pps_pending');
iUpdateSel=  xInport('update_sel');
iChanUD=    xInport('channel_updown');
 
oSync=xOutport('sync_out');

for i=1:vector_count
    dinName=['din' num2str(i)];
    doutName=['dout' num2str(i)];
%     iData(i)=xInport(dinName);
    iData=xInport(dinName);
    sDataTemp=xSignal;
    sDataTemp.bind(iData);
    sData{i}=sDataTemp;
    oData{i}=xOutport(doutName);
    
    
    
%     iData(i).bind(sData(i));
end

for i=1:vector_count
    chanName=['chan_start' num2str(i)];
    iChanStart=xInport(chanName);
    sChanStartTemp=xSignal;
    sChanStartTemp.bind(iChanStart);
    sChanStart{i}=sChanStartTemp;
%     sChanStart(i).bind(iChanStart);
end

sDelayNow=xSignal;
sCycleFinished=xSignal;
sPhaseNow=xSignal;
% iChanUD=    xInport('channel_updown');

% oSync=xOutport('sync_out');



blockTemp = xBlock(struct('source', ('monroe_library/delay_tracker_v2'), 'name','delay_tracker'), ...
    {});
blockTemp.bindPort({iSync,i1pps,iCoeff0,iCoeff1, iCoeff2, iCoeffPhase, iCountStart,iUpdateCoeffs,i1ppsPending,iUpdateSel}, {sDelayNow,sCycleFinished, sPhaseNow});

    sBool0=xConstBool(0,'dummy_bool');

for i=1:vector_count
    strI=num2str(i); 
    sliceName=['slice_UD_',strI];
   sUdSlice = xSlice(iChanUD,1,'lower',i-1,sliceName);

   
   sPhaseShift=xSignal;
   cptName=['cpt_' strI];
   blockTemp = xBlock(struct('source', ('monroe_library/channel_phase_tracker_v2'), 'name',cptName), ...
    {},{}, {});
 blockTemp.bindPort({sDelayNow,sUdSlice,sCycleFinished,sChanStart{i},sPhaseNow}, {sPhaseShift});
    
    delayName=['dataDelay' strI];
    sDataDelayed=xDelayr(sData{i},28+2+1,delayName);%+2 for convert lag
    
    
    sCoeff=xSignal;
    cgName=['coeff_gen_' strI];
   blockTemp = xBlock(struct('source', str2func('coeff_gen_power_series_external_counter_temp_sb'), 'name',cgName), ...
    {phase_resolution+1, bit_width_coeff,0,1, 0,1,1});
    blockTemp.bindPort({sPhaseShift}, {sCoeff});
    
    sGCM_out=xSignal;
sGCM_r=xSignal;
sGCM_i=xSignal;
sGCM_rc=xSignal;
sGCM_ic=xSignal;

stri=num2str(i);
    blockTemp = xBlock('monroe_library/GCM_fast_z_-6', ...
    struct('b_n_bits',bit_width_data, 'b_bin_pt', bit_width_data-1, 'w_n_bits', bit_width_coeff, 'w_bin_pt',bit_width_coeff-2));
    blockTemp.bindPort({sDataDelayed,sCoeff,sBool0,}, {xSignal, sGCM_out});
sGCM_out_d=xDelay(sGCM_out,1,['gcm_delay' num2str(i)]);
blockName=['coeff_c2ri' stri];
blockTemp = xBlock('monroe_library/c_to_ri', struct('n_bits',48,'bin_pt',39));
blockTemp.bindPort({sGCM_out_d}, {sGCM_r,sGCM_i});

blockTemp = xBlock('Convert', struct('arith_type','Signed','n_bits',bit_width_data,'bin_pt',bit_width_data-1,'quantization','Round  (unbiased: Even Values)','latency',2,'pipeline','on'));
blockTemp.bindPort({sGCM_r}, {sGCM_rc});
blockTemp = xBlock('Convert', struct('arith_type','Signed','n_bits',bit_width_data,'bin_pt',bit_width_data-1,'quantization','Round  (unbiased: Even Values)','latency',2,'pipeline','on'));
blockTemp.bindPort({sGCM_i}, {sGCM_ic});

sCoeffOut=xCram({sGCM_rc,sGCM_ic},['cram_coeff' stri]);
sTemp=oData{i};
sTemp.bind(sCoeffOut);

% blockTemp = xBlock(struct('source', ('monroe_library/cmult_v6'), 'name','fda'), );
%     blockTemp.bindPort({sDataDelayed,sCoeff,sBool0,}, oData(i));
   
    
end

sSyncOut=xDelay(iSync,25+2+2+1+1,'sync_delay_out'); %+2 for rounding. twice.
oSync.bind(sSyncOut);