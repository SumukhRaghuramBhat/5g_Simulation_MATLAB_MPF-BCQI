function macBSR = hNRMACBSR(lcid, lcgIdList, bufferSizeList, varargin) %#codegen
%hNRMACBSR Generates NR BSR MAC control element
%
%   Note: This is a helper function for an example.
%
%   MACBSR = hNRMACBSR(LCID, LCGIDLIST, BUFFERSIZELIST) generates buffer
%   status report (BSR) medium access control (MAC) control (except long
%   truncated BSR) element, as per 3GPP TS 38.321 Section 6.1.3.1, with
%   given input arguments.
%
%   MACBSR = hNRMACBSR(LCID, LCGIDLIST, BUFFERSIZELIST, PADDINGLENGTH)
%   generates BSR MAC control element (long truncated BSR), as per 3GPP TS
%   38.321 Section 6.1.3.1, with given input arguments.
%
%   LCID is the logical channel id (LCID) value of the BSR MAC control element.
%       - LCID = 59 represents short truncated BSR.
%       - LCID = 60 represents long truncated BSR.
%       - LCID = 61 represents short BSR.
%       - LCID = 62 represents long BSR.
%
%    LCGIDLIST is a column vector and contains logical channel groups
%    (LCGs) ids (only the LCGs having buffered data) for which BSR has to
%    be generated.
%
%   BUFFERSIZELIST is a column vector and contains the buffer size of the
%   LCGs present in the LCGIDLIST. The length of BUFFERSIZELIST must be same
%   as length of LCGIDLIST.
%
%   PADDINGLENGTH is the size of the long truncated BSR. Based on the
%   PADDINGLENGTH, number of buffer size fields to be included is determined.
%
%   MACBSR is the generated MAC BSR represented as column vector of octets
%   in decimal format.

%   Copyright 2019 The MathWorks, Inc.

    % Validate the inputs
    validateInputs(lcid, lcgIdList, bufferSizeList, varargin);

    if lcid == 59 || lcid == 61 % Short truncated BSR or short BSR
        % 1-byte payload with following fields:
        % LCGID - LCG id (3 bits).
        % BufferSizeIndex - Buffer size level index as per 3GPP TS 38.321
        %                   Table 6.1.3.1-1(5 bits).

        % Buffer size field length (in bits)
        bufferSizeFieldLength = 5; % Number of bits required to represent buffersize index value between 0 and 31
        % Construct the BSR control element
        bufferSizeIndex = getBufferSizeIndex(bufferSizeList(1), bufferSizeFieldLength);
        macBSR = bitor(bitshift(lcgIdList(1), 5), bufferSizeIndex);
    elseif lcid == 60 || lcid == 62 % long truncated BSR or long BSR
        % n+1 byte payload with following fields
        % LCG bitmap - Size is 1-byte. If a bit is set to 1 at index 'i', it indicates
        %               data is available in 'i-1' LCG. If bit is set to 0
        %               at index 'i', it indicates there is no data to report
        %               in 'i-1' LCG.
        % BufferSizeIndex - Size is n-bytes. Each byte represents
        %                   buffersize index of an LCG as per 3GPP TS
        %                   38.321 Table 6.1.3.1-1(8 bits). Here 'n'
        %                   represents the number of LCGs whose buffersize
        %                   is reported. Maximum number of LCGs buffersize
        %                   that can be reported at a time are 8. In long
        %                   BSR, buffer status of all the LCGs are reported
        %                   while in long truncated BSR it depends on the
        %                   padding length.

        lcgBitmap  = 0;
        % Buffer size field length (in bits)
        bufferSizeFieldLength = 8;  % Number of bits required to represent buffersize index value between 0 and 255
        % To store the buffersize index of the LCGs
        bufferSizeIndexList = zeros(numel(lcgIdList), 1);
        if lcid == 62
            % Number of LCGs buffer status to be reported
            numLCGs = numel(lcgIdList);
        else
            % Determine the number of buffer size fields to be included in
            % the long truncated BSR
            numLCGs = varargin{1} - 1;
        end

        for i = 1 : numel(lcgIdList)
            lcgBitmap = bitset(lcgBitmap, lcgIdList(i) + 1);
            bufferSizeIndexList(i) = getBufferSizeIndex(bufferSizeList(i), bufferSizeFieldLength);
        end

        % Construct the BSR control element
        macBSR = [lcgBitmap ; bufferSizeIndexList(1:numLCGs)];
    end
end

function validateInputs(lcid, lcgIdList, bufferSizeList, varargin)
% Validates the given input arguments

    % LCID is with in the valid range
    validateattributes(lcid,{'numeric'},{'nonempty','scalar','>=',59,'<=',62,'integer'},'lcid');

    % lcgIdList must be nonempty, vector in decimal format
    validateattributes(lcgIdList, {'numeric'},{'nonempty','vector','>=',0,'<=',7,'integer'},'lcgIdList');

    % bufferSizeList must be nonempty, vector in decimal format
    validateattributes(bufferSizeList, {'numeric'},{'nonempty','vector','>=',0,'finite','integer'},'bufferSizeList');

    % Validate the third argument
    if lcid == 60
        validateattributes(varargin{1},{'cell'},{'nonempty','scalar'},'paddingLength');
        validateattributes(varargin{1}{1},{'numeric'},{'scalar','>',0,'finite','integer'},'paddingLength');
    end
end

function bufferSizeIndex = getBufferSizeIndex(bufferSize, bufferSizeFieldLength)
% Performs buffer size row-index calculation 

    % bufferSize - represents the buffer size in bytes
    % bufferSizeFieldLength - represents the bits (5 or 8) required to represent the
    % buffersize index.
    % If bufferSizeFieldLength = 5, it represents buffersize index value
    % (in bits) ranges from 0 - 31.
    % If bufferSizeFieldLength = 8, it represents buffersize index value ranges
    % from 0 - 255.
    if bufferSizeFieldLength == 5 % bufferSizeIndex is represented in 5 bits(0 - 31).

        bsTable = bufferSizeIndexTable();
        % Get the first row index of the table where value in column 1 >
        % bufferSize.
        rowIndex = find((bsTable(:) >= bufferSize), 1);

        % If buffersize does not match with any row in the table, then
        % row index is considered as index of the last row.
        if isempty(rowIndex)
            % If bufferSize > 150000 bytes
            rowIndex = 32;
        end
    else
        % bufferSizeIndex is represented in 8 bits(0 - 255).
        bsTable = longBufferSizeIndexTable();

        % Get the first row index of the table where value in column 1 >
        % bufferSize.
        rowIndex = find((bsTable(1:254) >= bufferSize), 1);

        % If buffersize does not match with any row in the table, then row
        % index is considered as index of the last but one row, as last row
        % is reserved.
        if isempty(rowIndex)
            % If bufferSize > 81338368
            rowIndex = 255;
        end
    end

    % Return zero based index
    bufferSizeIndex = rowIndex - 1;
end

% 3GPP TS 38.321 Table 6.1.3.1-1
function bsTable = bufferSizeIndexTable()
% Construct the static table

    persistent bufferSizeTable;
    if isempty(bufferSizeTable)
        bufferSizeTable = [0;10;14;20;28;38;53;74
            102;142;198;276;384;535;745;1038
            1446;2014;2806;3909;5446;7587;10570;
            14726;20516;28581;39818;55474;77284;
            107669;150000;150000];
    end
    bsTable = bufferSizeTable;
end

% 3GPP TS 38.321 Table 6.1.3.1-2
function bsTable = longBufferSizeIndexTable()
% Construct the static table

    persistent longBufferSizeTable;
    if isempty(longBufferSizeTable)
        longBufferSizeTable = [0;10;11;12;13;14;15;16;17;18;19;20;22;23;25;26;28;30;32;34;36;38;
    40;43;46;49;52;55;59;62;66;71;75;80;85;91;97;103;110;117;124;
    132;141;150;160;170;181;193;205;218;233;248;264;281;299;318;339;
    361;384;409;436;464;494;526;560;597;635;677;720;767;817;870;926;987;
    1051;1119;1191;1269;1351;1439;1532;1631;1737;1850;1970;2098;2234;2379;
    2533;2698;2873;3059;3258;3469;3694;3934;4189;4461;4751;5059;5387;5737;
    6109;6506;6928;7378;7857;8367;8910;9488;10104;10760;11458;12202;12994;
    13838;14736;15692;16711;17795;18951;20181;21491;22885;24371;25953;
    27638;29431;31342;33376;35543;37850;40307;42923;45709;48676;51836;
    55200;58784;62599;66663;70990;75598;80505;85730;91295;97221;103532;
    110252;117409;125030;133146;141789;150992;160793;171231;182345;194182;
    206786;220209;234503;249725;265935;283197;301579;321155;342002;364202;
    387842;413018;439827;468377;498780;531156;565634;602350;641449;683087;
    727427;774645;824928;878475;935498;996222;1060888;1129752;1203085;
    1281179;1364342;1452903;1547213;1647644;1754595;1868488;1989774;
    2118933;2256475;2402946;2558924;2725027;2901912;3090279;3290873;
    3504487;3731968;3974215;4232186;4506902;4799451;5110989;5442750;
    5796046;6172275;6572925;6999582;7453933;7937777;8453028;9001725;
    9586039;10208280;10870913;11576557;12328006;13128233;13980403;
    14887889;15854280;16883401;17979324;19146385;20389201;21712690;
    23122088;24622972;26221280;27923336;29735875;31666069;33721553;
    35910462;38241455;40723756;43367187;46182206;49179951;52372284;
    55771835;59392055;63247269;67352729;71724679;76380419;81338368;81338368;inf];
    end
    bsTable = longBufferSizeTable;
end
