function hNRSetUpPacketDistribution(simParameters, gNB, UEs, dlPktObj, ulPktObj)
% Setup the UL and DL packet distribution mechanism

%   Copyright 2020 The MathWorks, Inc.

nodeInfo = struct('CarrierFreq',[],'NCellID',[], 'RNTI',[]);
% Configure Tx-Rx interface to exchange packets between UEs and gNB
% Register UEs for transmissions and receptions
    nodeInfo.CarrierFreq = simParameters.DLCarrierFreq;
    nodeInfo.NCellID = simParameters.NCellID;
    for ueIdx=1:length(UEs)
        nodeInfo.RNTI = ueIdx;
        uePhyObj = UEs{ueIdx}.PhyEntity;
        ueMACObj = UEs{ueIdx}.MACEntity;
        registerRxFcn(dlPktObj, nodeInfo, @uePhyObj.storeReception, @ueMACObj.controlRx);
        registerInBandTxFcn(uePhyObj, @ulPktObj.sendInBandPackets);
        registerOutofBandTxFcn(ueMACObj, @ulPktObj.sendOutofBandPackets);
    end
    nodeInfo.CarrierFreq = simParameters.ULCarrierFreq;
    nodeInfo.RNTI = [];
    % Register gNB for transmissions and receptions
    gNBPhyObj = gNB.PhyEntity;
    gNBMACObj = gNB.MACEntity;
    registerRxFcn(ulPktObj, nodeInfo, @gNBPhyObj.storeReception, @gNBMACObj.controlRx);
    registerInBandTxFcn(gNBPhyObj, @dlPktObj.sendInBandPackets);
    registerOutofBandTxFcn(gNBMACObj, @dlPktObj.sendOutofBandPackets);
end