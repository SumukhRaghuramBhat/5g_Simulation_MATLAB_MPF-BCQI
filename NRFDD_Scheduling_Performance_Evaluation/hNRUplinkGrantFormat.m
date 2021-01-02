classdef hNRUplinkGrantFormat
%hNRUplinkGrantFormat Represents the uplink grant information
% The uplink assignment information does not include all the fields of
% downlink control information (DCI) format 0_1 as per 3GPP standard. Grant
% packets containing only the information fields which feature as member of
% this class are assumed to be exchanged with UEs.

%   Copyright 2019 The MathWorks, Inc.

%#codegen

   properties

      % Offset of the allocated slot from the current slot (k2)
      SlotOffset

      % Resource block group(RBG) allocation represented as bit vector
      RBGAllocationBitmap

      % Location of first symbol
      StartSymbol

      % Number of symbols
      NumSymbols

      % Modulation and coding scheme
      MCS

      % New data indicator flag
      NDI

      % Redundancy version sequence number
      RV

      % HARQ process identifier
      HARQId
   end

   methods
      function obj = hNRUplinkGrantFormat()
          obj.RBGAllocationBitmap = [];
          obj.StartSymbol = [];
          obj.NumSymbols = [];
          obj.MCS = [];
          obj.NDI = [];
          obj.RV = [];
          obj.HARQId = [];
      end
   end
end