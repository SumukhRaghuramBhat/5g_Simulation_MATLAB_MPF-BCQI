classdef hNRPacketInfo
    % hNRPacketInfo Represents the meta data that is required for writing
    % the NR MAC packets into a file with the .pcap or .pcapng extension.

    %   Copyright 2020 The MathWorks, Inc.

    properties
        % RADIOTYPE is the mode of duplex. Default value is 1
        % (RadioFDD). It takes the following values:
        %    1 for RadioFDD
        %    2 for RadioTDD
        RadioType = 1
        % LINKDIR is the direction of the link. Default value is 0 (Uplink).
        % It takes the following values:
        %    0 for Uplink
        %    1 for Downlink
        LinkDir = 0
        % RNTITYPE is the type of Radio Network Temporary Identifier. Default value
        % is 3 (Cell RNTI). It takes the following values:
        %    0 for No RNTI
        %    1 for Paging RNTI
        %    2 for Random Access RNTI
        %    3 for Cell RNTI
        %    4 for System Information RNTI
        %    5 for Configured Scheduling RNTI
        RNTIType = 3
        % RNTI Radio Network Temporary Identifier. A
        % 2-byte value (in decimal) ranging from 0 to 65535.
        RNTI = []
        % UEId User Equipment Identifier. A 2-byte
        % value (in decimal) ranging from 0 to 65535.
        UEId = []
        % PHRType2OtherCell Binary value which decides the presence of Type
        % 2 Power Headroom field for special cell in case
        PHRType2OtherCell = []
        % HARQId Hybrid automatic repeat request process identifier. A 1-byte value
        % (in decimal) ranging from 0 to 15.
        HARQId = []
        % SystemFrameNumber System Frame Number which ranges from
        % 0 to 1023.
        SystemFrameNumber = []
        % SlotNumber Slot Number which identifies the slot
        % in the 10ms frame. It ranges from 0 to 159.
        SlotNumber = []
    end
end