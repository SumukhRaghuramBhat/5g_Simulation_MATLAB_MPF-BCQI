classdef hNRPDSCHInfo
    %hNRPDSCHInfo MAC-to-PHY information for PDSCH transmission and reception
    %   This information contains the parameters required by PHY from MAC,
    %   to do the PDSCH transmission and reception. gNB MAC sends it to PHY
    %   for PUSCH transmission and UE MAC sends it to PHY for PDSCH
    %   reception. The information includes parameters required for
    %   downlink shared channel (DL-SCH) processing and PDSCH processing.
    
    %   Copyright 2020 The MathWorks, Inc.
    
    %#codegen
    
    properties
        
        %NSlot Slot number of PDSCH transmission/reception in the 10ms frame
        NSlot
        
        %HARQId HARQ process identifier
        HARQId
        
        %RV Redundancy version
        RV
        
        %TargetCodeRate Target code rate for PDSCH transmission/reception
        TargetCodeRate
        
        %TBS Transport block size in bytes
        TBS
        
        %PDSCH configuration object as described in <a href="matlab:help('nrPDSCHConfig')">nrPDSCHConfig</a>
        PDSCHConfig = nrPDSCHConfig;
    end
    
end