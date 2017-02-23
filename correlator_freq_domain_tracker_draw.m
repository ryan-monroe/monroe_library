function correlator_freq_domain_tracker_draw(vector_count, bit_width_data, bit_width_coeff, phase_resolution)

% xBlock;
% vector_count=2;
% vector_len=10;
% bit_width_data=18;
% bit_width_coeff=18;
% phase_resolution=18;
%this block tracks the geometric delays of an interferometer element, using
%linear interpolation.  In addition, it translates those to phases on a
%per-channel basis, computes the complex value equivalent to a unit-vector
%of that phase, and multiplies it by the input signal.



iSync= xInport('sync_in');
i1pps= xInport('one_pps');
iDelayInit= xInport('delay_init');
iDelayInc=  xInport('delay_inc');
iPhaseInit= xInport('phase_init');
iPhaseInc=  xInport('phase_inc');
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

blockTemp = xBlock(struct('source', ('monroe_library/delay_tracker'), 'name','delay_tracker'), ...
    {});
blockTemp.bindPort({iSync,i1pps,iDelayInit,iDelayInc}, {sDelayNow,sCycleFinished});

blockTemp = xBlock(struct('source', ('monroe_library/delay_tracker'), 'name','phase_tracker'), ...
    {});
blockTemp.bindPort({iSync,i1pps,iPhaseInit,iPhaseInc}, {sPhaseNow});

    sBool0=xConstBool(0,'dummy_bool');

for i=1:vector_count
    strI=num2str(i);
    sliceName=['slice_UD_',strI];
   sUdSlice = xSlice(iChanUD,1,'lower',i-1,sliceName);

   
   sPhaseShift=xSignal;
   cptName=['cpt_' strI];
   blockTemp = xBlock(struct('source', ('monroe_library/channel_phase_tracker'), 'name',cptName), ...
    {},{}, {});
 blockTemp.bindPort({sDelayNow,sUdSlice,sCycleFinished,sChanStart{i},sPhaseNow}, {sPhaseShift});
    
    delayName=['dataDelay' strI];
    sDataDelayed=xDelay(sData{i},19,delayName);
    
    
    sCoeff=xSignal;
    cgName=['coeff_gen_' strI];
   blockTemp = xBlock(struct('source', str2func('coeff_gen_power_series_external_counter'), 'name',cgName), ...
    {phase_resolution+1, bit_width_coeff,0,1, 0,1});
    blockTemp.bindPort({sPhaseShift}, {sCoeff});
    
    
    
    cMultName=['cMult' strI];
   blockTemp = xBlock(struct('source', ('monroe_library/cmult_v6'), 'name',cMultName), ...
    struct('a_n_bits',bit_width_data, 'a_bin_pt',bit_width_data-1,'b_n_bits',bit_width_data, 'b_bin_pt', bit_width_data-1, 'w_n_bits', bit_width_coeff, 'w_bin_pt', ...
    bit_width_coeff-2,'a_delay',1,'apbw_delay',1,'out_n_bits', bit_width_data,'out_bin_pt',bit_width_data-1, 'downshift_at_end', 0, 'stage', 100,'scale', 0));
    blockTemp.bindPort({sDataDelayed,sCoeff,sBool0,}, oData(i));
    

% blockTemp = xBlock(struct('source', ('monroe_library/cmult_v6'), 'name','fda'), );
%     blockTemp.bindPort({sDataDelayed,sCoeff,sBool0,}, oData(i));
   
    
end

sSyncOut=xDelay(iSync,25,'sync_delay_out');
oSync.bind(sSyncOut);