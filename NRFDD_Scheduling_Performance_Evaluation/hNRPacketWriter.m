classdef hNRPacketWriter < comm_sysmod.internal.ConfigBaseHandle & comm_sysmod.internal.pcapCommon
    %hNRPacketWriter Create a 5G NR PCAP/PCAPNG file writer object
    %
    %   OBJ = hNRPacketWriter creates a 5G NR packet capture (PCAP)/packet
    %   capture next generation (PCAPNG) file writer object, OBJ, that
    %   writes the NR MAC packets into a file with the .pcap or
    %   .pcapng extension.
    %
    %   OBJ = hNRPacketWriter(Name1, Value1, ..., NameN, ValueN) creates a
    %   5G NR PCAP or PCAPNG file writer object, OBJ, with properties
    %   specified by one or more name-value pairs. You can specify additional
    %   name-value pair arguments described below. When a
    %   name-value pair is not specified, its default value is used.
    %
    %   OBJ = hNRPacketWriter('PCAPWriter', PCAPOBJ) creates a 5G NR PCAP or PCAPNG
    %   file writer object, OBJ, using the configuration specified in PCAPOBJ.
    %   PCAPOBJ is an object of type <a href="matlab:help('pcapngWriter')">pcapngWriter</a> or <a href="matlab:help('pcapWriter')">pcapWriter</a>.
    %
    %   hNRPacketWriter methods:
    %
    %   write                 - Write MAC frame into PCAP/PCAPNG format
    %
    %   hNRPacketWriter Name-Value pairs:
    %   FileName              - File name specified as a character row
    %                           vector or string. The default file name is
    %                           'capture'.
    %   ByteOrder             - Byte order, specified as 'little-endian' or
    %                           'big-endian'. The default value is
    %                           'little-endian'
    %   FileExtension         - File extension as 'pcap' or 'pcapng'. The default
    %                           value is 'pcap'.
    %   FileComment           - Additional info given by the user as a comment for
    %                           the file, specified as a character vector or
    %                           string. The default value is an empty character array.
    %   Interface             - Type of device interface that captures packets. The
    %                           default value is '5GNR'.
    %   PCAPWriter            - Object of type <a
    %                           href="matlab:help('pcapngWriter')">pcapngWriter</a> or <a href="matlab:help('pcapWriter')">pcapWriter</a>.
    %                           When you set this property, OBJ derives the
    %                           FileName, FileExtension, FileComment, and
    %                           ByteOrder properties in accordance from the
    %                           PCAPOBJ input.
    %
    %
    %   % Example 1:
    %   % Write NR MAC SubPDU into PCAP file format.
    %
    %   % Create a hNRPacketWriter object with file name as sample.pcapng
    %       pcapObj = hNRPacketWriter('FileName', 'sample', ...
    %                               'FileExtension', 'pcap');
    %   % Create an NR MAC SubPDU
    %       payload = [39, 1, 132]';
    %       link = 1;
    %       lcid = 59;
    %       macSubPDU = hNRMACSubPDU(lcid, payload, link);
    %
    %   % Set the timestamp for the packet
    %       timestamp = 12480;
    %
    %   % Create packet information object and add metadata
    %       packetInfo = hNRPacketInfo;
    %       packetInfo.RadioType = pcapObj.RadioFDD;
    %       packetInfo.LinkDir = pcapObj.Uplink;
    %       packetInfo.RNTIType = pcapObj.NoRNTI;
    %
    %   % Write the NR MAC SubPDU
    %       write(pcapObj, macSubPDU, timestamp, 'PacketInfo', packetInfo);
    %
    %   % Example 2:
    %   % Write NR MAC Padding SubPDU into PCAPNG file format with
    %   comments.
    %
    %   % Create a hNRPacketWriter object with file name as sample.pcapng
    %       pcapObj = hNRPacketWriter('FileName', 'sample', 'FileExtension', ...
    %                     'pcapng', 'FileComment', 'This is a sample file');
    %
    %   % Create an NR MAC Padding SubPDU
    %       macPaddingSubPDU = hNRMACPaddingSubPDU(200);
    %
    %   % Set the timestamp for the packet
    %   timestamp = 300;
    %
    %   % Create packet information object and add metadata
    %       packetInfo = hNRPacketInfo;
    %       packetInfo.RadioType = pcapObj.RadioFDD;
    %       packetInfo.LinkDir = pcapObj.Downlink;
    %       packetInfo.RNTIType = pcapObj.CellRNTI;
    %
    %   % Write the SubPDU
    %       write(pcapObj, macPaddingSubPDU, timestamp, 'PacketInfo', packetInfo);
    %
    %   Example 3:
    %   % Write 2 packets into PCAPNG format with file comments, packet
    %   comments, UEID, timestamp and system frame number.
    %
    %   % Create a hNRPacketWriter object with file name as sample.pcapng
    %       pcapObj = hNRPacketWriter('FileName', 'sample', 'FileExtension', ...
    %                     'pcapng', 'FileComment', 'This is a sample file');
    %
    %   % Create an NR MAC BSR PDU
    %       lcid = 59;
    %       lcgIdList = 6;
    %       bufferSizeList = 500;
    %       link = 1;
    %
    %   % Create an NR MAC BSR control element
    %       macBSR = hNRMACBSR(lcid, lcgIdList, bufferSizeList);
    %
    %   % Create an NR MAC SubPDU
    %       macSubPDU = hNRMACSubPDU(lcid, macBSR, link);
    %
    %   % Set the timestamp for the packet
    %       timestamp = 0;
    %
    %   % Create packet information object and add metadata
    %       packetInfo = hNRPacketInfo;
    %       packetInfo.RadioType = pcapObj.RadioFDD;
    %       packetInfo.LinkDir = pcapObj.Uplink;
    %       packetInfo.RNTIType = pcapObj.CellRNTI;
    %       packetInfo.PHRType2OtherCell = 1;
    %
    %   % Write the SubPDU
    %       write(pcapObj, macSubPDU, timestamp, 'PacketInfo', packetInfo, ...
    %           'PacketComment', 'This is an NR MAC BSR');
    %
    %   % Create packet information object and add metadata
    %       packetInfo = hNRPacketInfo;
    %       packetInfo.RadioType = pcapObj.RadioFDD;
    %       packetInfo.LinkDir = pcapObj.Uplink;
    %       packetInfo.RNTIType = pcapObj.CellRNTI;
    %       packetInfo.UEId = 1022;
    %
    %   % Write the SubPDU
    %       write(pcapObj, macSubPDU, timestamp, 'PacketInfo', packetInfo);
    %
    %   See also pcapWriter, pcapngWriter
    %
    %   References:
    %       http://xml2rfc.tools.ietf.org/cgi-bin/xml2rfc.cgi?url=https://raw.githubusercontent.com
    %       /pcapng/pcapng/master/draft-gharris-opsawg-pcap.xml&modeAsFormat=html/ascii&type=ascii
    %       (pcap capture file format)
    %       http://xml2rfc.tools.ietf.org/cgi-bin/xml2rfc.cgi?url=https://raw.githubusercontent.com
    %       /pcapng/pcapng/master/draft-tuexen-opsawg-pcapng.xml&modeAsFormat=html/ascii&type=ascii
    %       (pcapng capture file format)
    %       https://www.tcpdump.org/linktypes.html (linktypes information)
    %       https://www.tcpdump.org/linktypes/LINKTYPE_LINUX_SLL.html (sll information)

    %   Copyright 2020 The MathWorks, Inc.

    %#codegen
    properties(Dependent, SetAccess = private)
        % FileName PCAP or PCAPNG file name
        %   Specify file name as a character row vector or
        %   string. The default file name is 'capture'.
        FileName

        % ByteOrder Byte order type
        %   Specify the byte order as 'little-endian' or 'big-endian'.
        %   The default value is 'little-endian'.
        ByteOrder

        % FileComment Comment for the file
        %   Specify any additional comment for the file as a character
        %   vector or string, supported only by pcapng format. The default
        %   value is an empty character array.
        FileComment
    end

    properties(GetAccess = public, SetAccess = private)
        % FileExtension Extension of the file
        %   Specify the extension as 'pcap' or 'pcapng'. The default value
        %   is 'pcap'.
        FileExtension = 'pcap'

        % Interface Name of the device used to capture data
        %   Specify interface as a character vector or string in UTF-8
        %   format. The default value is '5GNR'.
        Interface = '5GNR'

        % PCAPWriter Packet writer object
        %   Set this property as of type <a href="matlab:help('pcapngWriter')">pcapngWriter</a> or <a href="matlab:help('pcapWriter')">pcapWriter</a>.
        %   When PCAPWriter is set, the properties FileName, FileExtension,
        %   FileComment, and ByteOrder are taken from the object specified
        %   in the PCAPWriter.
        PCAPWriter
    end

    properties(Access = private)
        % InterfaceID Interface identifier
        %   Unique identifier assigned by PCAP/PCAPNG writer object for the
        %   interface
        InterfaceID = 0

        % IsPCAPNG PCAPNG file format flag
        %   Set this property to true to indicate that the file format is
        %   PCAPNG. The default value is false.
        IsPCAPNG(1, 1) logical = false;

        % PCAPPacketWriter PCAP packet writer
        %   pcapWriter handle class object
        PCAPPacketWriter

        % PCAPNGPacketWriter PCAPNG packet writer object
        %   pcapngWriter handle class object
        PCAPNGPacketWriter
    end

    properties(Hidden)
        % DisableValidation Disable the validation for input arguments of
        % write method
        % Specify this property as a scalar logical. When true, validation
        % is not performed on the input arguments and the packet is
        % expected to be octets in decimal format.
        DisableValidation(1, 1) logical = false
    end

    properties(Constant)
        % Choices for the mandatary field values required for the NR MAC signature

        % RadioFDD Frequency Division Duplex Radio type
        RadioFDD = 1;

        % RadioTDD Time Division Duplex Radio type
        RadioTDD = 2;

        % Uplink Direction Uplink
        Uplink = 0;

        % Downlink Direction Downlink
        Downlink = 1;

        % NoRNTI No RNTI
        NoRNTI = 0;

        % PagingRNTI Paging RNTI
        PagingRNTI = 1;

        % RandomAccessRNTI Random Access RNTI
        RandomAccessRNTI = 2;

        % CellRNTI Cell RNTI
        CellRNTI = 3;

        % SystemInfoRNTI System Information RNTI
        SystemInfoRNTI = 4;

        % ConfiguredSchedulingRNTI Configured Scheduling RNTI
        ConfiguredSchedulingRNTI = 5;
    end

    properties(Constant, Hidden)
        % LinkType Unique identifier for SLL packet used for encapsulation
        % of NR MAC packets
        LinkType = 113;

        % The following tags are used in the NR MAC signature. The
        % signature follows a tag-value pattern

        % StartString Tag which indicates the beginning of NR MAC signature
        StartString = [109;97;99;45;110;114];

        % PayloadTag Tag which indicates that the rest of the bytes form the
        % NR MAC payload
        PayloadTag = 1;

        % RNTITag Tag which indicates that the next 2 bytes form the
        % RNTI value
        RNTITag = 2;

        % UEIdTag
        % Tag which indicates that the next 2 bytes form the UEID value
        UEIdTag = 3;

        % PHRType2OtherCellTag Tag which indicates that the next byte
        % contains the value of macNRPhrType2OtherCell flag
        PHRType2OtherCellTag = 5;

        % HARQIdTag Tag which indicates that the next byte contains
        % HARQ ID value
        HARQIdTag = 6;

        % FrameSlotTag Tag which indicates that the first 2 bytes after the
        % tag form the System Frame Number and the next 2 bytes frame the
        % Slot Number
        FrameSlotTag = 7;

        % FileExtensionValues Values which the 'FileExtension' property can take
        FileExtension_Values = {'pcap', 'pcapng'};
    end

    methods(Access = private)
        function setFileExtension(obj, value)
            propName = 'FileExtension';
            value = validateEnumProperties(obj, propName, value);
            obj.(propName) = value;
        end

        function setInterface(obj, value)
            validateattributes(value, {'char', 'string'}, {'row'}, ...
                mfilename, 'Interface')
            obj.Interface = value;
        end

        function setPCAPWriter(obj, value)
            validateattributes(value, {'pcapngWriter', 'pcapWriter'}, ...
                {'row'}, mfilename, 'PCAPWriter object')
            obj.PCAPWriter = value;
        end
    end

    methods
        function obj = hNRPacketWriter(varargin)
            % hNRPacketWriter Create a packet writer configuration
            % object

            % Name-value pair check
            coder.internal.errorIf(mod(nargin, 2) == true, ...
                'MATLAB:system:invalidPVPairs');

            % Initialize packetWriterFlag to false to indicate
            % 'PacketWriter' name-value pair is not given as input.
            packetWriterFlag = false;

            % File name for dummy pcapWriter or pcapngWriter for codegen,
            % which will be used to create the object. No file will be
            % created using this dummy file name.
            dummyFileName = 'sample5GNRCapture';

            % Initialize to default values
            fileName = 'capture';
            byteOrder = 'little-endian';
            fileComment = blanks(0);

            if isempty(coder.target) % Simulation path
                % Apply name-value pairs
                for idx = 1:2:nargin

                    name = validatestring(varargin{idx}, {'FileName', ...
                        'ByteOrder', 'FileComment', 'FileExtension', ...
                        'Interface', 'PCAPWriter'}, ...
                        mfilename);

                    switch(name)
                        case 'FileName'
                            fileName = varargin{idx+1};
                        case 'FileComment'
                            fileComment = varargin{idx+1};
                        case 'ByteOrder'
                            byteOrder = varargin{idx+1};
                        case 'FileExtension'
                            setFileExtension(obj, varargin{idx+1});
                        case 'Interface'
                            setInterface(obj, varargin{idx+1});
                        otherwise % PCAPWriter
                            packetWriterFlag = true;
                            setPCAPWriter(obj, varargin{idx+1});
                    end

                    if(packetWriterFlag && any(strcmp(name, ...
                            {'FileName', 'FileExtension', ...
                            'ByteOrder', 'FileComment'})))
                        error('nr5g:hNRPacketWriter:InvalidParameters', 'Invalid Parameters paired with PacketWriter object');
                    end
                end
            else %Codegen path
                nvPairs = struct('FileName', uint32(0), ...
                    'FileComment', uint32(0), ...
                    'ByteOrder', uint32(0), ...
                    'FileExtension', uint32(0), ...
                    'Interface', uint32(0), ...
                    'PCAPWriter', uint32(0));

                % Select parsing options
                popts = struct('PartialMatching', true, 'CaseSensitivity', ...
                    false);

                % Parse inputs
                pStruct = coder.internal.parseParameterInputs(nvPairs, ...
                    popts, varargin{:});

                if pStruct.PCAPWriter
                    packetWriterFlag = true;
                end

                if(packetWriterFlag && ...
                        (pStruct.FileName || ...
                        pStruct.FileExtension || ...
                        pStruct.ByteOrder || ...
                        pStruct.FileComment))
                    error('nr5g:hNRPacketWriter:InvalidParameters', 'Invalid Parameters paired with PacketWriter object');
                end

                % Get values for the N-V pair or set defaults for the
                % optional arguments
                byteOrder = coder.internal.getParameterValue(pStruct.ByteOrder, ...
                    coder.const('little-endian'), varargin{:});

                fileName = coder.internal.getParameterValue(pStruct.FileName, ...
                    'capture', varargin{:});

                fileComment = coder.internal.getParameterValue(pStruct.FileComment, ...
                    blanks(0), varargin{:});

                setFileExtension(obj, coder.internal.getParameterValue(pStruct.FileExtension, ....
                    coder.const('pcap'),varargin{:}));

                setInterface(obj, coder.internal.getParameterValue(pStruct.Interface, ...
                    coder.const('pcap'), varargin{:}));

                defaultVal = pcapWriter('FileName', dummyFileName);
                setPCAPWriter(obj, coder.internal.getParameterValue(pStruct.PCAPWriter, ...
                    defaultVal, varargin{:}));
            end

            % File name for pcap and pcapng files
            if (~packetWriterFlag && strcmp(obj.FileExtension, 'pcap')) || ...
                    (packetWriterFlag && isa(obj.PCAPWriter, 'pcapWriter'))
                pcapFileName = fileName;
                pcapngFileName = dummyFileName;
            else
                pcapFileName = dummyFileName;
                pcapngFileName = fileName;
                obj.IsPCAPNG = true;
            end

            % Check if 'PCAPWriter' object is passed as a name-value pair
            if packetWriterFlag
                if isa(obj.PCAPWriter, 'pcapWriter')
                    obj.FileExtension = 'pcap';
                    obj.PCAPPacketWriter = obj.PCAPWriter;

                    % Initialize for codegen support
                    obj.PCAPNGPacketWriter = pcapngWriter('FileName', pcapngFileName,...
                        'ByteOrder', byteOrder, 'FileComment', fileComment);

                    if(obj.PCAPPacketWriter.GlobalHeaderPresent)
                        error('nr5g:hNRPacketWriter:MultipleInterfacesNotAccepted', 'Multiple Headers cannot be written into the same file')
                    end

                else
                    obj.FileExtension = 'pcapng';
                    obj.PCAPNGPacketWriter = obj.PCAPWriter;

                    % Initialize for codegen support
                    obj.PCAPPacketWriter = pcapWriter('FileName', pcapFileName,...
                        'ByteOrder', byteOrder);
                end
            else
                % Initialize for codegen support
                obj.PCAPPacketWriter = pcapWriter('FileName', pcapFileName, ...
                    'ByteOrder', byteOrder);
                obj.PCAPNGPacketWriter = pcapngWriter('FileName', pcapngFileName, ...
                    'ByteOrder', byteOrder, 'FileComment', fileComment);
                if strcmp(obj.FileExtension, 'pcap')
                    if ~isempty(fileComment)
                        warning('nr5g:hNRPacketWriter:IgnoreFileComment','File Comment cannot be used with PCAP file type');
                    end
                end
            end

            if obj.IsPCAPNG
                % Write the Interface description block
                obj.InterfaceID = obj.PCAPNGPacketWriter.writeInterfaceDescriptionBlock(obj.LinkType, ...
                    obj.Interface);
            else
                % Write the Global header block
                obj.PCAPPacketWriter.writeGlobalHeader(obj.LinkType);
            end
        end

        function value = get.FileName(obj)
            if obj.IsPCAPNG
                value = obj.PCAPNGPacketWriter.FileName;
            else
                value = obj.PCAPPacketWriter.FileName;
            end
        end

        function value = get.FileComment(obj)
            if obj.IsPCAPNG
                value = obj.PCAPNGPacketWriter.FileComment;
            else
                value = blanks(0);
            end
        end

        function value = get.ByteOrder(obj)
            if obj.IsPCAPNG
                value = obj.PCAPNGPacketWriter.ByteOrder;
            else
                value = obj.PCAPPacketWriter.ByteOrder;
            end
        end

        function write(obj, packet, timestamp, varargin)
            %   write Write a packet into a file with the .pcap or .pcapng
            %   extension
            %
            %   write(OBJ, PACKET, TIMESTAMP)
            %   writes a packet into a file with .pcap or .pcapng extension
            %
            %   PACKET is the 5G-NR MAC packet specified one of these
            %   types:
            %    - A binary vector representing bits
            %    - A character vector representing octets in hexadecimal
            %      format
            %    - A string scalar representing octets in hexadecimal
            %      format
            %    - A numeric vector, where each element is in the range
            %      [0, 255], representing octets in decimal format
            %    - An n-by-2 character array, where each row represents
            %      an octet in hexadecimal format
            %
            %   TIMESTAMP is specified as a scalar integer greater than or
            %   equal to 0. Timestamp is the packet arrival time in
            %   microseconds since 1/1/1970.
            %
            %   'write' method has the following name-value pairs:
            %
            %   PacketInfo is an object of type hNRPacketInfo. It contains
            %   the metadata of the packet. If PACKETINFO is not present
            %   then default metadata is added to the packet.
            %   PacketInfo is a object which contains following fields:
            %
            %       RadioType           - Mode of duplex. Default value
            %                             is 1 (RadioFDD). It takes the
            %                             following values:
            %                                1 for RadioFDD
            %                                2 for RadioTDD
            %
            %       LinkDir             - Direction of the link. Default value
            %                             is 0 (Uplink). It takes the following
            %                             following values:
            %                                0 for Uplink
            %                                1 for Downlink
            %
            %       RNTIType            - Type of Radio Network Temporary Identifier.
            %                             Default value is 3 (Cell RNTI). It takes
            %                             the following values:
            %                                0 for No RNTI
            %                                1 for Paging RNTI
            %                                2 for Random Access RNTI
            %                                3 for Cell RNTI
            %                                4 for System Information RNTI
            %                                5 for Configured Scheduling RNTI
            %
            %       RNTI                - Radio Network Temporary Identifier. A
            %                             2-byte value (in decimal) ranging from 0 to 65535.
            %
            %       UEId                - User Equipment Identifier. A 2-byte
            %                             value (in decimal) ranging from 0 to
            %                             65535.
            %
            %       PHRType2OtherCell   - Binary value which decides the
            %                             presence of Type 2 Power Headroom
            %                             field for special cell in case of
            %                             Multiple Entry Power Headroom Report
            %                             MAC Control Element.
            %
            %       HARQId              - Hybrid automatic repeat request process
            %                             identifier. A 1-byte value (in decimal)
            %                             ranging from 0 to 15.
            %
            %       SystemFrameNumber   - System Frame Number which ranges from
            %                             0 to 1023.
            %
            %       SlotNumber          - Slot Number which identifies the slot
            %                             in the 10ms frame. It ranges from 0 to 159.
            %
            %   PacketComment is a comment to a packet specified as a character
            %   vector or string. The default value is an empty character array.
            %
            %   PacketFormat specifies the format of the input data
            %   packet as 'bits' or 'octets'. The default value is 'octets'.
            %   If it is specified as 'octets', the packet can be a numeric
            %   vector representing octets in decimal format or alternatively,
            %   it can be a character array or string scalar representing octets
            %   in hexadecimal format. Otherwise, packet is a binary vector.

            narginchk(3, 9);

            % Check whether the validation is enabled
            if ~obj.DisableValidation
                % Name-value pair check
                coder.internal.errorIf(mod(numel(varargin), 2) == true, ...
                    'MATLAB:system:invalidPVPairs');
            end

            % Initialize with default values
            radioType = obj.RadioFDD;
            direction = obj.Uplink;
            rntiType = obj.CellRNTI;
            rnti = zeros(1, 0);
            ueId = zeros(1, 0);
            phrType2OtherCell = zeros(1, 0);
            harqId = zeros(1, 0);
            systemFrameNumber = zeros(1, 0);
            slotNumber = zeros(1, 0);

            if isempty(coder.target) % Simulation path
                % Initialise with default values
                packetInfo = [];
                packetFormat = 'octets';
                packetComment = blanks(0);

                % Apply name-value pairs
                for idx = 1:2:numel(varargin)
                    name = validatestring(varargin{idx}, {'PacketInfo', ...
                        'PacketFormat', 'PacketComment'}, ...
                        mfilename);

                    switch(name)
                        case 'PacketInfo'
                            packetInfo = varargin{idx+1};
                        case 'PacketFormat'
                            packetFormat = varargin{idx+1};
                        otherwise % PacketComment
                            packetComment = varargin{idx+1};
                    end
                end

            else %Codegen path
                nvPairs = {'PacketInfo', 'PacketFormat', 'PacketComment'};

                % Select parsing options
                popts = struct('PartialMatching', true, ...
                    'CaseSensitivity', false);

                % Parse inputs
                pStruct = coder.internal.parseParameterInputs(nvPairs, ...
                    popts, varargin{:});

                % Get values for the N-V pair or set defaults for the optional arguments
                packetInfo = coder.internal.getParameterValue(pStruct.PacketInfo, ...
                    [], varargin{:});

                packetFormat = coder.internal.getParameterValue(pStruct.PacketFormat, ...
                    coder.const('octets'), varargin{:});

                packetComment = coder.internal.getParameterValue(pStruct.PacketComment, ...
                    blanks(0), varargin{:});
            end

            % Extract the metadata from the object
            if ~isempty(packetInfo)
                radioType = packetInfo.RadioType;
                direction = packetInfo.LinkDir;
                rntiType = packetInfo.RNTIType;
                rnti = packetInfo.RNTI;
                ueId = packetInfo.UEId;
                phrType2OtherCell = packetInfo.PHRType2OtherCell;
                harqId = packetInfo.HARQId;
                systemFrameNumber = packetInfo.SystemFrameNumber;
                slotNumber = packetInfo.SlotNumber;
            end

            % Check whether the validation is enabled
            if ~obj.DisableValidation
                % Validate radioType
                validateattributes(radioType, {'numeric'}, {'integer', 'scalar', '>=', 1, '<=', 2});

                % Validate direction
                validateattributes(direction, {'numeric'}, {'binary'});

                % Validate rntiType
                validateattributes(rntiType, {'numeric'}, {'integer', 'scalar', '>=', 0, '<=', 5});

                % Validate packet format
                packetFormat = validatestring(packetFormat, {'bits', 'octets'}, ...
                    mfilename, 'PacketFormat');

                % Validate packet and return octets in decimal format
                packetData = obj.validatePayloadFormat(packet, packetFormat);

                % Validate timestamp
                validateattributes(timestamp, {'numeric'}, ...
                    {'scalar', 'nonnegative'}, mfilename, 'timestamp');

                % Validate RNTI
                if ~isempty(rnti)
                    validateattributes(rnti, {'numeric'}, {'integer', 'scalar', '>=', 0, '<=', 65535});
                end

                % Validate UEId
                if ~isempty(ueId)
                    validateattributes(ueId, {'numeric'}, {'integer', 'scalar', '>=', 0, '<=', 65535});
                end

                % Validate PhrType2OtherCell
                if ~isempty(phrType2OtherCell)
                    validateattributes(phrType2OtherCell, {'numeric'}, {'binary'});
                end

                % Validate HARQId
                if ~isempty(harqId)
                    validateattributes(harqId, {'numeric'}, {'integer', 'scalar', '>=', 0, '<=', 15});
                end

                % Validate SystemFrameNumber
                if ~isempty(systemFrameNumber)
                    validateattributes(systemFrameNumber, {'numeric'}, {'integer', 'scalar', '>=', 0, '<=', 1023});
                end

                % Validate SlotNumber
                if ~isempty(slotNumber)
                    validateattributes(slotNumber, {'numeric'}, {'integer', 'scalar', '>=', 0, '<=', 159});
                end

                % Validate PacketComment
                if ~isempty(packetComment)
                    validateattributes(packetComment, {'char', 'string'}, {'row'}, ...
                        mfilename, 'PacketComment');
                end
            else
                obj.PCAPNGPacketWriter.DisableValidation = true;
                obj.PCAPPacketWriter.DisableValidation = true;

                % Convert packet data into decimal
                packetData = double(packet);
            end

            % Add MAC NR Info to the input MPDU
            payload = obj.addMACNRInfoToPacket(radioType, direction, ...
                rntiType, rnti, ueId, phrType2OtherCell, ...
                harqId, systemFrameNumber, slotNumber, packetData);

            % Add UDP, IP and SLL headers to the packet
            packet = obj.encapsulate(payload);

            if obj.IsPCAPNG
                % Write packet into PCAPNG format file
                if isempty(packetComment)
                    obj.PCAPNGPacketWriter.write(packet, timestamp, obj.InterfaceID);
                else
                    obj.PCAPNGPacketWriter.write(packet, timestamp, obj.InterfaceID, 'PacketComment', packetComment);
                end
            else
                % Write packet into PCAP format file
                obj.PCAPPacketWriter.write(packet, timestamp);
            end
        end
    end

    methods(Hidden)
        function packet = encapsulate(~, packetData)
            % encapsulate Add UDP, IP and SLL headers to the packet

            % Construct the UDP header
            udpHeader = [163;76; ...% Source port number
                39;15; ...% Destination port number
                fix((8+length(packetData))/256); mod(8+length(packetData), 256); ...% Length of header and packet. Length of header is 8 bytes
                0;0]; % Checksum

            % Attach the UDP header to the packetData
            udpPacket = [udpHeader; packetData];

            % Construct the IP header
            ipHeader = [69; ...% Version of IP protocol and Priority/Traffic Class
                0; ... % Type of Service
                fix((20+length(udpPacket))/256); mod(20+length(udpPacket), 256); ...% Total Length of the IPv4 packet
                0;1; ...% Identification
                0;0; ...% Flags and Fragmentation Offset
                64; ...% Time to Live in seconds
                17; ...% Protocol number
                0;0; ...% Header Checksum
                127;0;0;1; ...% Source IP address
                127;0;0;1]; % Destination IP address

            % Construct the SLL Header
            sllHeader = [0;0; % Packet Type
                3;4; % ARPHRD Type
                0;0; % Link Layer address length
                0;0;0;0;0;0;0;0; % Link Layer address
                8;0]; % Protocol Type

            % Attach the headers to the udpPacket
            packet = [sllHeader; ipHeader; udpPacket];

        end

        function macNRInfoPacket = addMACNRInfoToPacket(obj, radioType, direction, ...
                rntiType, rnti, ueId, phrType2OtherCell, ...
                harqId, systemFrameNumber, slotNumber, payload)
            % addMACNRInfoToPacket Add MAC NR information to the packet

            % Construct the signature with mandatory fields
            signature = [obj.StartString; radioType; direction; rntiType];

            % Check if 'RNTI' is set and concatenate it to the signature
            if ~isempty(rnti)
                signature = [signature; obj.RNTITag; fix(rnti / 256); mod(rnti, 256)];
            end

            % Check if 'UEId' is set and concatenate it to the signature
            if ~isempty(ueId)
                signature = [signature; obj.UEIdTag; fix(ueId / 256); mod(ueId, 256)];
            end

            % Check if 'PhrType2OtherCell' is set and concatenate it to the signature
            if ~isempty(phrType2OtherCell)
                signature = [signature; obj.PHRType2OtherCellTag; phrType2OtherCell];
            end

            % Check if 'HARQId' is set and concatenate it to the signature
            if ~isempty(harqId)
                signature = [signature; obj.HARQIdTag; harqId];
            end

            % Check if 'SystemFrameNumber' or 'SlotNumber' or both are set
            % and concatenate it to the signature
            if ~isempty(systemFrameNumber)||~isempty(slotNumber)
                if (systemFrameNumber)
                    systemFrameNumber = [fix(systemFrameNumber / 256); mod(systemFrameNumber, 256)];
                else
                    systemFrameNumber = [0;0];
                end
                if (slotNumber)
                    slotNumber = [fix(slotNumber / 256); mod(slotNumber, 256)];
                else
                    slotNumber = [0;0];
                end
                signature = [signature; obj.FrameSlotTag; systemFrameNumber; slotNumber];
            end
            % Concatenate the payload tag and the signature to the payload
            macNRInfoPacket = [signature; obj.PayloadTag; payload];

        end
    end
end